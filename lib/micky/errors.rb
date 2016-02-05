module Micky
  class Error < StandardError
    def initialize(message = nil, original_exception: nil, response: nil)
      if response
        super "#{response.code} #{response.message} at #{response.uri}"
      elsif original_exception
        super original_exception.inspect
      elsif message
        super message
      else
        super
      end
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
  class NoRedirectLocation < ServerError
  end
end
