require "log"

class Castblock::Blocker
  Log = Castblock::Log.for(self)

  @devices = Hash(Chromecast::Device, Channel(Nil)).new

  def initialize(@chromecast : Chromecast, @sponsorblock : Sponsorblock)
  end

  def run : Nil
    watch_new_devices
  end

  private def watch_new_devices : Nil
    loop do
      Log.debug { "Checking for new devices" }
      @devices.reject! { |_, continue| continue.closed? }

      begin
        devices = @chromecast.list_devices.to_set
      rescue Chromecast::CommandError
        Log.warn { "Error while listing devices" }
      else
        new_devices = devices - @devices.keys
        new_devices.each do |device|
          Log.info &.emit("New device found", name: device.device_name, uuid: device.uuid)
          @devices[device] = Channel(Nil).new
          spawn watch_device(device, @devices[device])
        end

        @devices.each_key do |device|
          if !devices.includes?(device) && (continue = @devices.delete(device))
            Log.info &.emit("A device is gone", name: device.device_name, uuid: device.uuid)
            continue.close
          end
        end
      end

      sleep 30.seconds
    end
  end

  private def watch_device(device : Chromecast::Device, continue : Channel(Nil)) : Nil
    @chromecast.start_watcher(device, continue) do |message|
      Log.debug &.emit("Received message", application: message.application.display_name)

      if message.application.display_name.downcase == "youtube" && (media = message.media)
        handle_media(device, media)
      end
    end
  end

  private def handle_media(device : Chromecast::Device, media : Chromecast::Media) : Nil
    Log.debug &.emit("Youtube video playing", id: media.media.content_id, current_time: media.current_time)

    segments = @sponsorblock.get_segments(media.media.content_id)
    if segments.nil?
      Log.debug &.emit("Unknown video", id: media.media.content_id)
      return
    end

    segments.each do |segment|
      if segment.segment[0] <= media.current_time < segment.segment[1] - 5
        Log.info &.emit(
          "Found a sponsor segment, skipping it.",
          id: media.media.content_id,
          start: segment.segment[0],
          end: segment.segment[1],
        )

        begin
          @chromecast.seek_to(device, segment.segment[1] - 1)
        rescue Chromecast::CommandError
          Log.error { "Error while seeking" }
        end
        break
      end
    end
  end
end
