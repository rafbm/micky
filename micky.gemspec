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

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
