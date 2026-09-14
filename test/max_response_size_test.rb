require 'test_helper'

describe 'Micky max_response_size' do
  it 'reads the whole body when the option is not set' do
    response = Micky.get(server.url('/ok'))
    assert_equal 1000, response.body.bytesize
    refute response.truncated?
  end

  it 'leaves a body under the limit alone' do
    response = Micky.get(server.url('/ok'), max_response_size: 100_000)
    assert_equal 1000, response.body.bytesize
    refute response.truncated?
  end

  it 'accepts a body exactly at the limit' do
    response = Micky.get(server.url('/ok'), max_response_size: 1000)
    assert_equal 1000, response.body.bytesize
    refute response.truncated?
  end

  describe 'when the server sends more than the limit' do
    let(:limit) { 50_000 }

    it 'returns nil' do
      assert_nil Micky.get(server.url('/flood'), max_response_size: limit)
    end

    it 'raises Micky::TooLargeResponse when asked to raise' do
      error = assert_raises(Micky::TooLargeResponse) do
        Micky.get(server.url('/flood'), max_response_size: limit, raise_errors: true)
      end
      assert_equal 'Response larger than 50000 bytes', error.message
    end

    it 'gives up as soon as it has read the limit, rather than draining the server' do
      # Unbounded, this reads a gigabyte
      assert_operator elapsed { Micky.get(server.url('/flood'), max_response_size: limit) }, :<, 1.0
    end

    describe 'with truncate: true' do
      let(:response) { Micky.get(server.url('/flood'), max_response_size: limit, truncate: true) }

      it 'returns the first bytes up to the limit' do
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
        assert_operator elapsed { response }, :<, 1.0
      end

      it 'counts what it keeps, not what came off the wire, when Net::HTTP decompresses' do
        response = Micky.get(server.url('/gzipped-flood'), max_response_size: limit, truncate: true)
        assert_equal limit, response.body.bytesize
        assert response.body.start_with?('xxx')
        assert response.truncated?
      end
    end
  end

  it 'caps a redirect body without treating it as too large' do
    # The 302 itself carries a gigabyte; only the hop after it is a real response
    time = elapsed {
      response = Micky.get(server.url('/fat-redirect'), max_response_size: 50_000)
      assert_equal 1000, response.body.bytesize
      refute response.truncated?
    }
    assert_operator time, :<, 2.0
  end

  it 'keeps an empty body empty rather than nil' do
    assert_equal '', Micky.get(server.url('/chunked-empty')).body
    assert_equal '', Micky.get(server.url('/chunked-empty'), max_response_size: 100).body
  end

  it 'keeps a HEAD body nil' do
    assert_nil Micky.head(server.url('/ok'), max_response_size: 100).body
  end
end
