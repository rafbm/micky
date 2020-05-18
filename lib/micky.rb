require_relative 'micky/version'

require_relative 'micky/uri'
require_relative 'micky/request'
require_relative 'micky/response'
require_relative 'micky/errors'

module Micky
  DEFAULTS = {
    raise_errors: false,
    max_redirects: 20,
    timeout: 10,
    skip_resolve: false,
    resolve_timeout: 5,
    oauth: {},
    query: {},
    headers: {},
    parsers: {
      'application/json' => -> (body) {
        require 'json' unless defined? JSON
        JSON.parse(body) rescue nil
      }
    },
  }

  class << self
    DEFAULTS.each_key do |key|
      attr_accessor key
    end
  end

  DEFAULTS.each do |key, value|
    instance_variable_set :"@#{key}", value
  end

  def self.get(uri, opts = {})
    Request.new(opts).get(uri)
  end

  def self.head(uri, opts = {})
    Request.new(opts).head(uri)
  end
end
