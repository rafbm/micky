require 'minitest/autorun'
require 'micky'
require 'socket'
require 'logger'

# WebMock and friends intercept above Net::HTTP’s body reading, so they can’t
# test how many bytes come off the socket or how long we wait. This serves real
# HTTP over a real socket instead.
class TestServer
  attr_reader :port

  RESPONSES = {
    # A small, ordinary response
    '/ok' => ->(socket) {
      body = 'hello' * 100
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{body.bytesize}\r\n\r\n"
      socket.write body
    },
    '/dir/ok' => ->(socket) { RESPONSES['/ok'].call(socket) },
    # A 200 whose chunked body is empty; Net::HTTP yields no chunk for it
    '/chunked-empty' => ->(socket) {
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n"
    },
    # Redirects with a host-relative Location
    '/host-relative-redirect' => ->(socket) {
      socket.write "HTTP/1.1 302 Found\r\nLocation: /ok\r\nContent-Length: 0\r\n\r\n"
    },
    # Redirects with a path-relative Location, to /dir/ok
    '/dir/path-relative-redirect' => ->(socket) {
      socket.write "HTTP/1.1 302 Found\r\nLocation: ok\r\nContent-Length: 0\r\n\r\n"
    },
    # Streams for as long as anyone reads
    '/flood' => ->(socket) {
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 1000000000\r\n\r\n"
      loop { socket.write('x' * 8192) }
    },
    # One byte at a time, never idle long enough to trip a per-read timeout
    '/drip' => ->(socket) {
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 100000\r\n\r\n"
      loop { socket.write('x'); socket.flush; sleep 0.2 }
    },
    # A redirect that itself carries a huge body
    '/fat-redirect' => ->(socket) {
      socket.write "HTTP/1.1 302 Found\r\nLocation: /ok\r\nContent-Length: 1000000000\r\n\r\n"
      loop { socket.write('x' * 8192) }
    },
    # gzip, so Net::HTTP’s transparent decoding is in the path
    '/gzipped-flood' => ->(socket) {
      require 'zlib'
      socket.write "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Encoding: gzip\r\n\r\n"
      writer = Zlib::GzipWriter.new(socket)
      loop { writer.write('x' * 8192) }
    },
  }

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @thread = Thread.new { accept_loop }
    @thread.abort_on_exception = false
  end

  def url(path) = "http://127.0.0.1:#{@port}#{path}"

  def stop
    @thread.kill
    @server.close
  end

private

  def accept_loop
    loop do
      socket = @server.accept
      Thread.start(socket) do |s|
        begin
          path = s.gets.to_s.split(' ')[1]
          while (line = s.gets) && line != "\r\n"; end
          RESPONSES.fetch(path, ->(so) { so.write("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n") }).call(s)
        rescue StandardError, Timeout::Error
          # The client hung up, as most of these specs expect
        ensure
          s.close rescue nil
        end
      end
    end
  end
end

class MickyTest < Minitest::Spec
  def self.server
    @server ||= begin
      server = TestServer.new
      Minitest.after_run { server.stop }
      server
    end
  end

  def server = self.class.server

  def setup
    Micky::DEFAULTS.each { |key, value| Micky.public_send("#{key}=", value) }
    Micky.logger = Logger.new(nil)
    Micky.skip_resolve = true
  end

  def elapsed
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  end
end

# Every `describe` block inherits the server and the defaults reset above
Minitest::Spec.register_spec_type(//, MickyTest)
