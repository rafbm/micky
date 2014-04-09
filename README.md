# Micky

Micky makes simple HTTP requests (`GET`/`HEAD`), follows redirects, handles
exceptions (invalid hosts/URIs, server errors, timeouts, redirect loops),
automatically parses responses (JSON, etc.), is very lightweight, and has no
dependency.

Micky is for those times you would have used
[`Net::HTTP`](http://ruby-doc.org/stdlib/libdoc/net/http/rdoc/Net/HTTP.html‎)
or [`OpenURI`](http://ruby-doc.org/stdlib/libdoc/open-uri/rdoc/OpenURI.html),
but don’t want to bother handling all the sneaky things mentionned above, and
don’t want to add heavy dependencies to your app.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'micky'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install micky
```

## Usage

Micky provides two methods: `get` and `head`.

On successful requests, it will return a subclass of
[`Net::HTTPReponse`](http://ruby-doc.org/stdlib/libdoc/net/http/rdoc/Net/HTTPResponse.html).
For any error it might encounter during the request (invalid hosts/URIs,
server errors, timeouts, redirect loops), it will return `nil`.

```ruby
response = Micky.get('http://google.com')
response.content_type # "text/html"
response.body         # "<!doctype html><html ..."

response = Micky.get('http://invalidhost.foo')
response # nil
```

### Classic example

```ruby
if Micky.head(params[:website_url])
  # User provided a valid URL
  url = URI(params[:website_url])
  url.path = '/favicon.ico'

  if favicon = Micky.get(url)
    # Do whatever with the raw `favicon.body`, for whatever reason
  else
    # This site has no favicon, or a broken one, too bad
  end
else
  # Some error happened, display error message to user
end
```

### Headers and query strings

Request headers and query string params can be passed as `:headers` and `:query`.

```ruby
Micky.get('http://drpm.me/unwz.jpg', headers: { 'Accept' => 'text/html' })
Micky.get('http://urls.api.twitter.com/1/urls/count.json', query: { url: 'dropmeme.com' })
```

### OAuth `Authorization` header

Micky supports creating a OAuth `Authorization` header with the help of the
[SimpleOAuth](https://github.com/laserlemon/simple_oauth) gem.

```ruby
Micky.get(
  'https://api.twitter.com/1.1/statuses/user_timeline.json',
  oauth: {
    consumer_key: 'l0tSAl3tT3RsAnD1G1tS',
    consumer_secret: 'l0tSAl3tT3RsAnD1G1tS',
    token: 'l0tSAl3tT3RsAnD1G1tS',
    token_secret: 'l0tSAl3tT3RsAnD1G1tS',
  },
)
```

To use the `:oauth` argument, just ensure [`simple_oauth`](http://rubygems.org/gems/simple_oauth) is available:

```ruby
gem 'simple_oauth'
```

### Automatically parse responses into Ruby objects

`Micky::Response#body` always returns the response as a string. To parse this
string into a Ruby object, use `Micky::Response#data`.

Responses with `Content-Type: application/json` are automatically parsed by
Ruby’s [`JSON`](http://ruby-doc.org/stdlib/libdoc/json/rdoc/JSON.html) library.

```ruby
response = Micky.get('http://urls.api.twitter.com/1/urls/count.json?url=dropmeme.com')
response.content_type # 'application/json'

# plain string
response.body # '{"count":33,"url":"http://dropmeme.com/"}'

# proper hash
response.data # {"count"=>33, "url"=>"http://dropmeme.com/"}
```

#### Add custom parsers

To add custom response parsers for specific content-types, insert lambdas in
the `Micky.parsers` hash.

For instance, to parse HTML documents with [Nokogiri](http://nokogiri.org):

```ruby
Micky.parsers['text/html'] = -> (body) {
  Nokogiri::HTML(body)
}
```

Overwrite the default `application/json` parser to use
[Oj](http://github.com/ohler55/oj):

```ruby
Micky.parsers['application/json'] = -> (body) {
  begin
    Oj.load(body)
  rescue Oj::ParseError
  end
}
```

Parse images into [MiniMagick](https://github.com/minimagick/minimagick)
instances:

```ruby
image_parser = -> (body) {
  begin
    MiniMagick::Image.read(body)
  rescue MiniMagick::Invalid
  end
}

%w[image/png image/jpeg image/jpg image/gif].each do |type|
  Micky.parsers[type] = image_parser
end
```

## TODO

- Support :basic_auth and :digest_auth through [HTTPauth](https://github.com/Manfred/HTTPauth)
- Add tests
- Better document configuration options in README

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

---

© 2013 [Rafaël Blais Masson](http://rafbm.com). Micky is released under the MIT license.
