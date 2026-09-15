# frozen_string_literal: true

require_relative 'lib/micky/version'

Gem::Specification.new do |spec|
  spec.name = 'micky'
  spec.version = Micky::VERSION
  spec.authors = ['Rafael Masson']
  spec.email = ['rafbmasson@gmail.com']

  spec.description =
    'Micky makes simple HTTP requests (GET/HEAD), follows redirects, handles ' \
    'exceptions (invalid hosts/URIs, server errors, timeouts, redirect loops), ' \
    'automatically parses responses (JSON, etc.), is very lightweight, and has no ' \
    'dependency.'
  spec.summary = 'Lightweight and worry-free HTTP client'
  spec.homepage = 'https://github.com/rafbm/micky'
  spec.license = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.3'

  # All shipped with Ruby. logger and base64 stopped being default gems (4.0 and
  # 3.4). uri 0.13.1 is the first with ::URI::RFC2396_PARSER; Ruby 3.3.0 to 3.3.4 ship 0.13.0.
  spec.add_dependency 'logger'
  spec.add_dependency 'base64'
  spec.add_dependency 'uri', '>= 0.13.1'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
end
