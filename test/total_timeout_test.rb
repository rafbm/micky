require 'test_helper'

describe 'Micky total_timeout' do
  it 'defaults to 20 seconds' do
    assert_equal 20, Micky.total_timeout
  end

  it 'leaves a fast response alone' do
    assert_equal 1000, Micky.get(server.url('/ok'), total_timeout: 5).body.bytesize
  end

  describe 'against a server that drips bytes slower than it is read' do
    # Every read succeeds, so `timeout` never fires however low it is set
    let(:opts) { { timeout: 5, total_timeout: 1 } }

    it 'gives up at the deadline' do
      assert_in_delta 1, elapsed { Micky.get(server.url('/drip'), **opts) }, 0.5
    end

    it 'returns nil by default' do
      assert_nil Micky.get(server.url('/drip'), **opts)
    end

    it 'raises Micky::TotalTimeout when asked to raise' do
      assert_raises(Micky::TotalTimeout) do
        Micky.get(server.url('/drip'), raise_errors: true, **opts)
      end
    end

    it 'never returns without the deadline, which is what makes it necessary' do
      assert_raises(Timeout::Error) do
        Timeout.timeout(2) { Micky.get(server.url('/drip'), timeout: 5, total_timeout: nil) }
      end
    end
  end

  it 'does not relabel an enclosing block’s expiry as its own' do
    assert_raises(ArgumentError) do
      Timeout.timeout(0.2, ArgumentError) do
        Micky.get(server.url('/drip'), timeout: 5, total_timeout: 30)
      end
    end
  end
end
