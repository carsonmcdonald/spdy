$: << 'lib' << '../lib'

require 'eventmachine'
require 'spdy'

class SPDYHandler < EM::Connection
  def post_init
    @use_spdy = false
    @normal = ""

    @parser = SPDY::Parser.new
    @parser.on_headers_complete do |stream_id, associated_stream, priority, headers|
      p [:SPDY_HEADERS, headers]

      sr = SPDY::Protocol::Control::SynReply.new
      h = {'Content-Type' => 'text/plain', 'status' => '200 OK', 'version' => 'HTTP/1.1'}
      sr.create(:stream_id => 1, :headers => h)
      send_data sr.to_binary_s

      p [:SPDY, :sent, :SYN_REPLY]

      d = SPDY::Protocol::Data::Frame.new
      d.create(:stream_id => 1, :data => "This is SPDY.")
      send_data d.to_binary_s

      p [:SPDY, :sent, :DATA]

      d = SPDY::Protocol::Data::Frame.new
      d.create(:stream_id => 1, :flags => 1)
      send_data d.to_binary_s

      p [:SPDY, :sent, :DATA_FIN]
    end

    set_negotiable_protocols(["spdy/2", "http/1.1", "http/1.0"])
    start_tls
  end

  def ssl_handshake_completed
    np = get_negotiated_protocol
    @use_spdy = (np == "spdy/2")
  end

  def receive_data(data)
    if @use_spdy
      @parser << data
    else
      @normal << data
      if @normal[-4,4] == "\r\n\r\n"
        send_data "HTTP/1.1 200\r\n"
        send_data "Connection: close\r\n"
        send_data "Content-Length: 17\r\n"
        send_data "Content-type: text/plain\r\n"
        send_data "\r\n"
        send_data "This is not SPDY."
      end
    end
  end

  def unbind
    p [:SPDY, :connection_closed]
  end
end

EM.run do
  EM.start_server '0.0.0.0', 8000, SPDYHandler
end
