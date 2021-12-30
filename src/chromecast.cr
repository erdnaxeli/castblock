require "log"
require "http"
require "process"
require "uri"

require "./chromecast/*"

class Castblock::Chromecast
  Log = Castblock::Log.for(self)

  @bin : String
  @client : HTTP::Client? = nil
  @server_running = false
  @video_ids = Channel(String).new

  def initialize
    @bin = find_executable
    spawn start_server
    while !@server_running
      sleep 500.milliseconds
    end
  end

  def list_devices : Array(Device)
    response = client.get("/devices")
    if !response.status.success?
      Log.debug &.emit("Error while getting devices", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end

    Array(Device).from_json(response.body)
  end

  def seek_to(device : Device, timestamp : Float64) : Nil
    params = HTTP::Params.encode({
      "uuid"    => device.uuid,
      "seconds" => timestamp.to_s,
    })
    response = client.post("/seek-to?" + params)

    if !response.status.success?
      Log.error &.emit("Error with seek_to", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end
  end

  def set_mute(device : Device, value : Bool) : Nil
    params = HTTP::Params.encode({
      "uuid" => device.uuid,
    })
    response = client.post("/#{value ? "" : "un"}mute?" + params)

    if !response.status.success?
      Log.error &.emit("Error with mute", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end
  end

  def skip_ad(device : Device) : Nil
    params = HTTP::Params.encode({
      "uuid" => device.uuid,
    })
    response = client.post("/skipad?" + params)

    if !response.status.success?
      Log.error &.emit("Error with skipad", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end
  end

  def start_watcher(device : Device, continue : Channel(Nil), &block : WatchMessage ->) : Nil
    loop do
      Log.info &.emit("Starting go-chromecast watcher", name: device.name, uuid: device.uuid)
      Process.run(
        @bin,
        args: ["watch", "--output", "json", "--interval", "2", "-u", device.uuid, "--retries", "1"],
      ) do |process|
        while output = process.output.gets
          if continue.closed?
            process.terminate
            return
          end

          begin
            message = WatchMessage.from_json(output)
            message.payload.as?(String).try do |payload|
              begin
                message.payload_data = WatchMessagePayload.from_json(payload)
              rescue ex
                Log.debug { "Unhandled payload: #{ex}" }
              end
            end
          rescue ex
            Log.debug { "Invalid message: #{ex}" }
          else
            yield message
          end
        end
      end

      return if continue.closed?

      Log.warn &.emit("go-chromecast has quit.", name: device.name, uuid: device.uuid)
      Log.warn &.emit("Restarting go-chromecast watcher in 5s.", name: device.name, uuid: device.uuid)
      sleep 5.seconds
    end
  end

  def connect(device : Device) : Nil
    params = HTTP::Params.encode({
      "uuid" => device.uuid,
    })
    response = client.post("/connect?" + params)

    if !response.status.success? && response.body.chomp != "device uuid is already connected"
      Log.debug &.emit(
        "Error while connecting to device",
        name: device.name,
        uuid: device.uuid,
        status_code: response.status_code,
        error: response.body.chomp,
      )
      raise CommandError.new
    end
  end

  def disconnect(device : Device) : Nil
    params = HTTP::Params.encode({
      "uuid" => device.uuid,
    })
    response = client.post("/disconnect?" + params)

    if !response.status.success?
      Log.warn &.emit(
        "Error while disconnecting from device",
        name: device.name,
        uuid: device.uuid,
        status_code: response.status_code,
        error: response.body.chomp,
      )
    end
  end

  private def client : HTTP::Client
    if !@server_running
      raise HttpServerNotRunningError.new
    end

    if client = @client
      client
    else
      @client = HTTP::Client.new("127.0.0.1", port: 8011)
    end
  end

  private def find_executable : String
    bin = Process.find_executable("go-chromecast")
    if bin.nil?
      Log.fatal { "No go-chromecast executable found in the PATH." }
      raise "missing go-chromecast executable"
    end

    Log.info { "Found go-chromecast at #{bin}." }
    bin
  end

  private def start_server : Nil
    loop do
      Log.info { "Starting the go-chromecast server." }
      Process.run(@bin, args: ["httpserver", "-p", "8011"]) do |process|
        loop do
          begin
            HTTP::Client.get("http://127.0.0.1:8011/")
          rescue e : Socket::ConnectError
            sleep 500.milliseconds
          else
            break
          end
        end

        Log.info { "The go-chromecast server is up" }

        @server_running = true
        error = process.error.gets_to_end
        @server_running = false

        Log.warn { "The go-chromecast server has quit." }
        Log.warn { error }
      end

      Log.warn { "Restart go-chromecast server in 5s." }
      sleep 5.seconds
    end
  end
end
