require 'uri'

module Micky
  HTTP_URI_REGEX = %r{\Ahttps?:/+}

  def self.URI(uri)
    uri = uri.to_s.strip
    if uri =~ HTTP_URI_REGEX
      # Replace any number of slashes (1, 3 or 4579) by two slashes
      uri.sub! %r{/+}, '//'.freeze
    else
      uri.sub! %r{/+}, ''.freeze
      uri = "http://#{uri}"
    end
    uri = begin
      ::URI.parse(uri)
    rescue ::URI::InvalidURIError
      begin
        # ::URI::Parser is the RFC3986 parser, whose #escape is a deprecated shim
        # that delegates to the RFC2396 one and warns under $VERBOSE
        ::URI.parse(::URI::RFC2396_PARSER.escape(uri))
      rescue ::URI::InvalidURIError
      end
    end
    uri if uri&.host
  end

  module URI
    def self.extract(text)
      # Same as above: ::URI.extract is a deprecated shim over this
      ::URI::RFC2396_PARSER.extract(text).select { |uri|
        begin
          ::URI.parse(uri).is_a? ::URI::HTTP
        rescue ::URI::InvalidURIError
          false
        end
      }
    end
  end
end
