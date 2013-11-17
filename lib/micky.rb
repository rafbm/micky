require 'micky/version'

require 'micky/uri'
require 'micky/request'
require 'micky/response'

module Micky
  class << self
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
  @max_redirects = 10
  @timeout = 5
  @skip_resolve = false
  @resolve_timeout = 2
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
