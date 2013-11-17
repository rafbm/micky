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
end
