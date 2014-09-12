module Micky
  class Error < StandardError
    attr_reader :exception, :response

    def initialize(message = nil, exception: nil, response: nil)
      @exception = exception
      @response = response
      @message = message
    end

    def message
      if response
        "#{response_code} #{response_message} at #{request_uri}"
      elsif exception
        exception.inspect
      elsif @message
        @message
      else
        super
      end
    end

    def request_uri
      response.uri if response
    end

    def response_code
      response.code.to_i if response
    end

    def response_message
      response.message if response
    end
  end

  # Client errors
  class ClientError < Error
  end
  class HTTPClientError < ClientError
  end
  class InvalidURIError < ClientError
  end
  class HostError < ClientError
  end

  # Server errors
  class ServerError < Error
  end
  class HTTPServerError < ServerError
  end
  class TooManyRedirects < ServerError
  end
end
