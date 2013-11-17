require 'uri'

module Micky
  HTTP_URI_REGEX = %r{\Ahttps?://}

  def self.URI(uri)
    uri = uri.to_s.strip
    uri = "http://#{uri}" if uri !~ HTTP_URI_REGEX
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
