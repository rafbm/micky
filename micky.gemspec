# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'micky/version'

Gem::Specification.new do |spec|
  spec.name          = 'micky'
  spec.version       = Micky::VERSION
  spec.authors       = ['Rafaël Blais Masson']
  spec.email         = ['rafbmasson@gmail.com']
  spec.description   =
    'Micky makes simple HTTP requests (GET/HEAD), follows redirects, handles ' \
    'exceptions (invalid hosts/URIs, server errors, timeouts, redirect loops), ' \
    'automatically parses responses (JSON, etc.), is very lightweight, and has no ' \
    'dependency.'
  spec.summary       = 'Lightweight and worry-free HTTP client'
  spec.homepage      = 'http://github.com/rafBM/micky'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Shipped with Ruby, but no longer default gems (logger since 4.0, base64 since 3.4)
  spec.add_dependency 'logger'
  spec.add_dependency 'base64'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
end
