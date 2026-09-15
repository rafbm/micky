require 'test_helper'

describe 'Micky.URI' do
  # Ruby only prints the deprecation under $VERBOSE, so turn it on to see it
  def without_warnings
    verbose, $VERBOSE = $VERBOSE, true
    _, err = capture_io { yield }
    err
  ensure
    $VERBOSE = verbose
  end

  it 'escapes a URL that ::URI.parse rejects' do
    uri = nil
    err = without_warnings { uri = Micky.URI('http://example.com/a b?x=1|2') }
    assert_equal 'http://example.com/a%20b?x=1%7C2', uri.to_s
    assert_empty err
  end

  it 'extracts http URLs from text' do
    urls = nil
    err = without_warnings { urls = Micky::URI.extract('see http://a.com and ftp://c.com') }
    assert_equal ['http://a.com'], urls
    assert_empty err
  end
end
