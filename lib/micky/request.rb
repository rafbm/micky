require 'net/https'
require 'timeout'

module Micky
  class Request
    def initialize(opts = {})
      # Options can be set per request and fallback to module-level defaults
      [:max_redirects, :timeout, :skip_resolve, :resolve_timeout, :headers, :parsers].each do |name|
        value = opts.has_key?(name) ? opts[name] : Micky.public_send(name)
        instance_variable_set "@#{name}", value
      end
    end

    def get(uri)
      @request_class_name = 'Get'
      request(uri)
    end

    def head(uri)
      @request_class_name = 'Head'
      request(uri)
    end

  private

    def request(uri)
      @uri = uri
      request_with_redirect_handling(0)
    end

    def request_with_redirect_handling(redirect_count)
      return log "Max redirects reached (#{@max_redirects})" if redirect_count >= @max_redirects

      @uri = Micky::URI(@uri)

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

      # Request
      request = Net::HTTP.const_get(@request_class_name).new(@uri)
      @headers.each { |k,v| request[k] = v }

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        Response.new(response)
      when Net::HTTPRedirection
        log "Redirect to #{response['Location']}"
        @uri = response['Location']
        request_with_redirect_handling(redirect_count + 1)
      else
        log response
        nil
      end
    rescue Timeout::Error, ::URI::InvalidURIError, OpenSSL::SSL::SSLError, SystemCallError, SocketError => e
      log e
      nil
    end

    def log(message)
      message = "#{message.class}: #{message.message}" if message.is_a? Exception
      warn "Micky.#{@request_class_name.downcase}('#{@uri}'): #{message}"
    end
  end
end
