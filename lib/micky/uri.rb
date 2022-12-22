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
        ::URI.parse(::URI::Parser.new.escape(uri))
      rescue ::URI::InvalidURIError
      end
    end
    uri if uri&.host
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
