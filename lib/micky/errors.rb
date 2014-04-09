module Micky
  class Error < StandardError
    attr_reader :response

    def initialize(response = nil)
      @response = response
    end

    def to_s
      "#{response_code} #{response_message} at #{request_uri}"
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

  class ClientError < Error
  end

  class ServerError < Error
  end
end
