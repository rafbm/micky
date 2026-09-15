require 'test_helper'

describe 'Micky redirects' do
  # The test server listens on a random port, so a redirect that loses the port
  # goes to 127.0.0.1:80 and fails
  it 'keeps the port when the Location is host-relative' do
    response = Micky.get(server.url('/host-relative-redirect'))
    assert_equal 1000, response.body.bytesize
  end

  it 'keeps the port when the Location is path-relative' do
    response = Micky.get(server.url('/dir/path-relative-redirect'))
    assert_equal 1000, response.body.bytesize
  end

  it 'redirects to the resolved URL' do
    log = StringIO.new
    Micky.logger = Logger.new(log, level: Logger::DEBUG)
    Micky.get(server.url('/host-relative-redirect'))
    assert_includes log.string, "302 redirect to #{server.url('/ok')}"
  end
end
