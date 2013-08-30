require 'delegate'

module Micky
  # Delegates to a Net::HTTPResponse instance
  class Response < SimpleDelegator
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
      "#<Micky::Reponse #{super}>"
    end

    # Support for `awesome_print`
    def ai(*args)
      "#<Micky::Reponse #{super}>"
    end
  end
end
