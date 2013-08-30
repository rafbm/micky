require 'delegate'
require 'uri'

module Micky
  HTTP_URI_REGEX = /\Ahttps?:\/\//

  def self.URI(uri)
    uri = uri.to_s.strip
    uri = "http://#{uri}" if uri !~ HTTP_URI_REGEX
    ::URI.parse(uri) rescue ::URI.parse(::URI.encode(uri))
  end
end
