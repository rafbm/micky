require_relative 'micky/version'

require_relative 'micky/uri'
require_relative 'micky/request'
require_relative 'micky/response'
require_relative 'micky/errors'

module Micky
  class << self
    attr_accessor :raise_errors
    attr_accessor :max_redirects
    attr_accessor :timeout
    attr_accessor :skip_resolve
    attr_accessor :resolve_timeout
    attr_accessor :oauth
    attr_accessor :query
    attr_accessor :headers
    attr_accessor :parsers
  end

  # Reasonable defaults
  @raise_errors = false
  @max_redirects = 20
  @timeout = 10
  @skip_resolve = false
  @resolve_timeout = 5
  @oauth = {}
  @query = {}
  @headers = {}
  @parsers = {
    'application/json' => -> (body) {
      require 'json' unless defined? JSON
      JSON.parse(body) rescue nil
    }
  }

  def self.get(uri, opts = {})
    Request.new(opts).get(uri)
  end

  def self.head(uri, opts = {})
    Request.new(opts).head(uri)
  end
end
