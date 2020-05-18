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
    end

    def get(uri)
      @request_class_name = 'Get'
      request_with_redirect_handling(uri)
    end

    def head(uri)
      @request_class_name = 'Head'
      request_with_redirect_handling(uri)
    end

  private

    def request_with_redirect_handling(uri, redirect_count = 0)
      if redirect_count >= @max_redirects
        raise Micky::TooManyRedirects, "Max redirects reached (#{@max_redirects})" if @raise_errors
        log "Max redirects reached (#{@max_redirects})"
        return nil
      end

      case response = request(uri)
      when Net::HTTPSuccess
        Response.new(response, @uri)
      when Net::HTTPRedirection
        previous_uri = uri
        uri = response['Location']

        if uri.nil?
          raise Micky::NoRedirectLocation, response: response if @raise_errors
          warn "Micky.#{@request_class_name.downcase}('#{previous_uri}'): No “Location” for #{response.code} response"
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

        log "Redirect to #{uri}"
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
          log response
          nil
        end
      end
    end

    def request(uri)
      @uri = Micky::URI(uri) or begin
        raise Micky::InvalidURIError, uri if @raise_errors
        warn "Micky.#{@request_class_name.downcase}('#{uri}'): Invalid URI"
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
        http.request(request)
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

    def log(message)
      message = "#{message.class}: #{message.message}" if message.is_a? Exception
      warn "Micky.#{@request_class_name.downcase}('#{@uri}'): #{message}"
    end
  end
end
