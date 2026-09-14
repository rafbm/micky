require 'net/https'
require 'timeout'

module Micky
  class Request
    def initialize(opts = {})
      # Options can be set per request and fallback to module-level defaults
      DEFAULTS.each_key do |name|
        value = opts.has_key?(name) ? opts[name] : Micky.public_send(name)
        instance_variable_set "@#{name}", value
      end

      @truncated = false
    end

    def get(uri)
      @request_class_name = 'Get'
      with_total_timeout { request_with_redirect_handling(uri) }
    end

    def head(uri)
      @request_class_name = 'Head'
      with_total_timeout { request_with_redirect_handling(uri) }
    end

  private

    # `timeout` bounds each socket operation, not the whole call. A slow drip or a
    # long redirect chain never trips it. `total_timeout` is a wall clock for the
    # whole call, redirects included.
    # We pass our own exception class: Timeout only converts the instance it raised
    # itself, so an enclosing block’s expiry passes through untouched and ours is
    # never caught by a `rescue Timeout::Error` in between.
    def with_total_timeout
      return yield unless @total_timeout

      begin
        Timeout.timeout(@total_timeout, Micky::TotalTimeout) { yield }
      rescue Micky::TotalTimeout => e
        raise e if @raise_errors
        log "Total timeout reached (#{@total_timeout}s)"
        nil
      end
    end

    def request_with_redirect_handling(uri, redirect_count = 0)
      if redirect_count >= @max_redirects
        raise Micky::TooManyRedirects, "Max redirects reached (#{@max_redirects})" if @raise_errors
        log "Max redirects reached (#{@max_redirects})"
        return nil
      end

      case response = request(uri)
      when Net::HTTPSuccess
        debug "#{response.code} success"
        log "Response truncated at #{@max_response_size} bytes" if @truncated
        Response.new(response, @uri, truncated: @truncated)
      when Net::HTTPRedirection
        previous_uri = uri
        uri = response['Location']

        if uri.nil?
          raise Micky::NoRedirectLocation, response: response if @raise_errors
          log "No “Location” for #{response.code} response", previous_uri
          return nil
        end

        if uri !~ Micky::HTTP_URI_REGEX
          if uri.start_with? '//'
            # Protocol-relative
            uri = Micky::URI(uri).to_s
          elsif uri.start_with? '/'
            # Host-relative
            previous_uri = Micky::URI(previous_uri)
            uri = File.join("#{previous_uri.scheme}://#{previous_uri.host}", uri)
          else
            # Path-relative
            previous_uri = Micky::URI(previous_uri)
            previous_directory = previous_uri.path.sub(/[^\/]+\z/, '')
            uri = File.join("#{previous_uri.scheme}://#{previous_uri.host}#{previous_directory}", uri)
          end
        end

        parsed_uri = Micky::URI(uri)
        if parsed_uri.nil?
          raise Micky::InvalidLocation, response: response if @raise_errors
          log "Invalid “Location” for #{response.code} response: #{uri}", previous_uri
          return nil
        elsif parsed_uri.hostname.empty?
          raise Micky::NoRedirectLocation, response: response if @raise_errors
          log "Empty hostname for #{response.code} response", previous_uri
          return nil
        end

        debug "#{response.code} redirect to #{uri}"
        request_with_redirect_handling(uri, redirect_count + 1)
      else
        if @raise_errors
          case response
          when Net::HTTPClientError
            raise Micky::HTTPClientError, response: response
          when Net::HTTPServerError
            raise Micky::HTTPServerError, response: response
          end
        else
          log "#{response.code} error" if response
          nil
        end
      end
    end

    def request(uri)
      @uri = Micky::URI(uri) or begin
        raise Micky::InvalidURIError, uri if @raise_errors
        log 'Invalid URI', uri
        return nil
      end

      unless @skip_resolve == true
        # Resolv is the only host validity check that can be wrapped with Timeout.
        # Net::HTTP and OpenURI use TCPSocket.open which isn’t timeoutable.
        require 'resolv' unless defined? Resolv
        begin
          Timeout.timeout(@resolve_timeout) do
            begin
              Resolv::DNS.new.getaddress(@uri.host)
            rescue Resolv::ResolvError => e
              raise Micky::HostError, original_exception: e if @raise_errors
              log 'Host resolution error'
              return nil
            end
          end
        rescue Timeout::Error => e
          raise Micky::HostError, "Host resolution timeout: #{@uri}" if @raise_errors
          log 'Host resolution timeout'
          return nil
        end
      end

      # Connection
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == 'https'

      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.ssl_timeout  = @timeout
      http.write_timeout = @timeout if http.respond_to?(:write_timeout=)

      # Query string
      query = Hash[::URI.decode_www_form(@uri.query || '')]

      if @query && @query.any?
        query.merge! Hash[@query.map { |k,v| [k.to_s, v] }]
        @uri.query = ::URI.encode_www_form(query)
      end

      # OAuth
      if @oauth && @oauth.any?
        unless defined? SimpleOAuth
          begin
            require 'simple_oauth'
          rescue LoadError
            raise 'You must install the simple_oauth gem to use the :oauth argument.'
          end
        end

        uri_without_query = @uri.dup
        uri_without_query.query = ''
        header = SimpleOAuth::Header.new(@request_class_name, uri_without_query, query, @oauth).to_s
        @headers['Authorization'] = header
      end

      # Request
      request = Net::HTTP.const_get(@request_class_name).new(@uri)

      # Headers
      @headers.each { |k,v| request[k] = v }

      begin
        if @max_response_size
          http.request(request) { |response| read_capped_body(response) }
        else
          http.request(request)
        end
      rescue Zlib::Error
        request['Accept-Encoding'] = 'identity'
        retry
      rescue Errno::ECONNREFUSED, OpenSSL::SSL::SSLError, SocketError => e
        raise Micky::ClientError, original_exception: e if @raise_errors
        log e
        nil
      rescue Net::HTTPBadResponse, SystemCallError, IOError, Timeout::Error => e
        raise Micky::ServerError, original_exception: e if @raise_errors
        log e
        nil
      end
    end

    # Without a block, Net::HTTP reads the whole body into memory before we see any
    # of it. Reading it ourselves lets us stop at `max_response_size` and drop the
    # connection. Runs on redirect hops too, since a redirect can carry a body.
    def read_capped_body(response)
      # Net::HTTP yields nothing for a body-less response (204, HEAD) and for an
      # empty one alike, so decide up front whether the body is nil or empty
      body = +''.b if response.class.body_permitted? && @request_class_name == 'Get'
      @truncated = false

      response.read_body do |chunk|
        room = @max_response_size - body.bytesize

        if chunk.bytesize > room
          body << chunk.byteslice(0, room)
          @truncated = true
          break
        end

        body << chunk
      end

      # `read_body` only sets `@read` at the end of the body, and `break` skips that.
      # Without it, `response.body` would resume reading where we stopped.
      response.instance_variable_set(:@read, true)
      response.body = body

      # The server’s Content-Length no longer matches the body
      response['content-length'] = body.bytesize.to_s if @truncated
    end

    def log(message, uri = @uri, severity = Logger::WARN)
      message = "#{message.class}: #{message.message}" if message.is_a? Exception
      @logger.add(severity, "[Micky] #{@request_class_name.upcase} #{uri} - #{message}")
    end

    def debug(message, uri = @uri)
      log(message, uri, Logger::DEBUG)
    end
  end
end
