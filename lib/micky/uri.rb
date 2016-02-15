require 'uri'

module Micky
  HTTP_URI_REGEX = %r{\Ahttps?://?}
  SINGLE_SLASH_HTTP_URI_REGEX = %r{\Ahttps?:/[^/]}

  def self.URI(uri)
    uri = uri.to_s.strip
    if uri =~ HTTP_URI_REGEX
      if uri =~ SINGLE_SLASH_HTTP_URI_REGEX
        uri.sub! '/', '//'
      end
    else
      uri = "http://#{uri}"
    end
    begin
      ::URI.parse(uri)
    rescue ::URI::InvalidURIError
      begin
        ::URI.parse(::URI.encode(uri))
      rescue ::URI::InvalidURIError
      end
    end
  end

  module URI
    def self.extract(text)
      ::URI.extract(text).select { |uri|
        begin
          ::URI.parse(uri).is_a? ::URI::HTTP
        rescue ::URI::InvalidURIError
          false
        end
      }
    end
  end
end
