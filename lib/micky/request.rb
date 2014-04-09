require 'net/https'
require 'timeout'

module Micky
  class Request
    def initialize(opts = {})
      # Options can be set per request and fallback to module-level defaults
      [:raise_errors, :max_redirects, :timeout, :skip_resolve, :resolve_timeout, :oauth, :query, :headers, :parsers].each do |name|
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
      return log "Max redirects reached (#{@max_redirects})" if redirect_count >= @max_redirects

      case response = request(uri)
      when Net::HTTPSuccess
        Response.new(response)
      when Net::HTTPRedirection
        uri = response['Location']
        log "Redirect to #{uri}"
        request_with_redirect_handling(uri, redirect_count + 1)
      else
        log response
        log response.body

        if @raise_errors
          case response
          when Net::HTTPClientError
            raise Micky::ClientError.new(response)
          when Net::HTTPServerError
            raise Micky::ServerError.new(response)
          end
        else
          nil
        end
      end
    end

    def request(uri)
      @uri = Micky::URI(uri) or return nil

      unless @skip_resolve == true
        # Resolv is the only domain validity check that can be wrapped with Timeout.
        # Net::HTTP and OpenURI use TCPSocket.open which isn’t timeoutable.
        require 'resolv' unless defined? Resolv
        begin
          Timeout.timeout(@resolve_timeout) do
            begin
              Resolv::DNS.new.getaddress(@uri.host)
            rescue Resolv::ResolvError
              log 'Domain resolution error'
              return nil
            end
          end
        rescue Timeout::Error
          log 'Domain resolution timeout'
          return nil
        end
      end

      # Connection
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == 'https'

      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.ssl_timeout  = @timeout

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

      http.request(request)
    rescue Timeout::Error, OpenSSL::SSL::SSLError, SystemCallError, SocketError => e
      log e
      nil
    end

    def log(message)
      message = "#{message.class}: #{message.message}" if message.is_a? Exception
      warn "Micky.#{@request_class_name.downcase}('#{@uri}'): #{message}"
    end
  end
end
