require 'delegate'

module Micky
  # Delegates to a Net::HTTPResponse instance
  class Response < SimpleDelegator
    attr_reader :uri

    def initialize(response, uri)
      super(response)
      @uri = uri
    end

    def data
      @data ||= begin
        if body and parser = Micky.parsers[content_type]
          parser.call(body)
        else
          body
        end
      end
    end

    def data_uri
      @data_uri ||= begin
        if body
          require 'base64' unless defined? Base64
          "data:#{content_type};base64,#{Base64.encode64(body)}"
        end
      end
    end

    def to_s
      body
    end

    def inspect
      "#<Micky::Response #{super}>"
    end

    # Support for `awesome_print`
    def ai(*args)
      "#<Micky::Response #{super}>"
    end
  end
end
