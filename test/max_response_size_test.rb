require 'test_helper'

describe 'Micky max_response_size' do
  it 'reads the whole body when the option is not set' do
    response = Micky.get(server.url('/ok'))
    assert_equal 500, response.body.bytesize
    refute response.truncated?
  end

  it 'leaves a body under the limit alone' do
    response = Micky.get(server.url('/ok'), max_response_size: 100_000)
    assert_equal 500, response.body.bytesize
    refute response.truncated?
  end

  it 'does not mark a body exactly at the limit as truncated' do
    response = Micky.get(server.url('/ok'), max_response_size: 500)
    assert_equal 500, response.body.bytesize
    refute response.truncated?
  end

  describe 'when the server sends more than the limit' do
    let(:limit) { 50_000 }
    let(:response) { Micky.get(server.url('/flood'), max_response_size: limit) }

    it 'stops at the limit instead of reading the whole body' do
      assert_equal limit, response.body.bytesize
      assert response.truncated?
    end

    it 'does not resume reading when the body is asked for again' do
      response.body
      assert_equal limit, response.body.bytesize
    end

    it 'reports a content length that matches what it holds' do
      assert_equal limit, response.content_length
    end

    it 'returns as soon as it has enough, rather than draining the server' do
      # Unbounded, this reads a gigabyte
      assert_operator elapsed { response }, :<, 1.0
    end
  end

  it 'caps redirect bodies too, not just the body it hands back' do
    # The 302 itself carries a gigabyte; only the hop after it is a real response
    time = elapsed {
      response = Micky.get(server.url('/fat-redirect'), max_response_size: 50_000)
      assert_equal 500, response.body.bytesize
      refute response.truncated?
    }
    assert_operator time, :<, 2.0
  end

  it 'counts what it keeps, not what came off the wire, when Net::HTTP decompresses' do
    response = Micky.get(server.url('/gzipped-flood'), max_response_size: 50_000)
    assert_equal 50_000, response.body.bytesize
    assert response.body.start_with?('xxx')
    assert response.truncated?
  end

  it 'keeps an empty body empty rather than nil' do
    assert_equal '', Micky.get(server.url('/chunked-empty')).body
    assert_equal '', Micky.get(server.url('/chunked-empty'), max_response_size: 100).body
  end

  it 'keeps a HEAD body nil' do
    assert_nil Micky.head(server.url('/ok'), max_response_size: 100).body
  end
end
