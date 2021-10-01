require "log"
require "math"

class Castblock::Blocker
  Log = Castblock::Log.for(self)

  @devices = Hash(Chromecast::Device, Channel(Nil)).new

  def initialize(@chromecast : Chromecast, @sponsorblock : Sponsorblock, @seek_to_offset : Int32, @mute_ads : Bool, @merge_threshold : Float64)
  end

  def run : Nil
    watch_new_devices
  end

  private def watch_new_devices : Nil
    loop do
      Log.debug { "Checking for new devices" }
      @devices.each { |device, continue| remove_device(device) if continue.closed? }

      begin
        devices = @chromecast.list_devices.to_set
      rescue Chromecast::CommandError
        Log.warn { "Error while listing devices" }
      else
        new_devices = devices - @devices.keys
        new_devices.each do |device|
          Log.info &.emit("New device found", name: device.name, uuid: device.uuid)

          Log.info &.emit("Connect to device", name: device.name, uuid: device.uuid)
          begin
            @chromecast.connect(device)
          rescue Chromecast::CommandError
            Log.error &.emit("Error while connecting", name: device.name, uuid: device.uuid)
          else
            @devices[device] = Channel(Nil).new
            spawn watch_device(device, @devices[device])
          end
        end

        @devices.each_key do |device|
          if !devices.includes?(device)
            Log.info &.emit("A device is gone, stopping watcher", name: device.name, uuid: device.uuid)
            remove_device(device)
          end
        end
      end

      sleep 30.seconds
    end
  end

  private def watch_device(device : Chromecast::Device, continue : Channel(Nil)) : Nil
    @chromecast.start_watcher(device, continue) do |message|
      if application = message.application
        Log.debug &.emit("Received message", application: application.display_name)
        if application.display_name.downcase == "youtube" && (media = message.media) && media.player_state == "PLAYING"
          handle_media(device, media)
        end
      end

      if @mute_ads && (payload = message.payload_data) && payload.status.size > 0
        if payload.status[0].custom_data.player_state == 1081 && payload.status[0].volume.muted == false
          Log.info &.emit("Found ad, muting audio", device: device.name)
          @chromecast.set_mute(device, true)
        elsif payload.status[0].custom_data.player_state != 1081 && payload.status[0].volume.muted
          Log.info &.emit("Ad ended, unmuting audio", device: device.name)
          @chromecast.set_mute(device, false)
        end
      end
    end
  end

  private def handle_media(device : Chromecast::Device, media : Chromecast::Media) : Nil
    Log.debug &.emit("Youtube video playing", id: media.media.content_id, current_time: media.current_time)

    begin
      segments = @sponsorblock.get_segments(media.media.content_id)
    rescue Sponsorblock::Error
      return
    end

    if segments.nil?
      Log.debug &.emit("Unknown video", id: media.media.content_id)
      return
    end

    segments.each do |segment|
      segment_start = segment.segment[0]
      segment_end = Math.min(segment.segment[1], media.media.duration).to_f

      # Check if we are in the segment
      if segment_start <= media.current_time < segment_end
        Log.info &.emit(
          "Found a #{segment.category} segment.",
          id: media.media.content_id,
          start: segment_start,
          end: segment_end,
        )

        # Extend segment_end using merge_threshold
        sorted_segments = segments.sort { |x, y| x.segment[0] <=> y.segment[0] }
        sorted_segments.each do |segment_next|
          if segment_next.segment[0] - @merge_threshold <= segment_end < segment_next.segment[1]
            Log.info &.emit("Segment extended from #{segment_end} to #{segment_next.segment[1]}.")
            segment_end = Math.min(segment_next.segment[1], media.media.duration).to_f
          end
        end

        # Check if the segment meets minimum length
        if media.current_time < segment_end - Math.max(5, @seek_to_offset)
          Log.info &.emit(
            "Segment meets criteria, skipping it.",
            id: media.media.content_id,
            start: segment_start,
            end: segment_end,
          )
          begin
            @chromecast.seek_to(device, segment_end - @seek_to_offset)
          rescue Chromecast::CommandError
            Log.error &.emit("Trying to reconnect to the device", name: device.name, uuid: device.uuid)
            @chromecast.disconnect(device)
            begin
              @chromecast.connect(device)
            rescue Chromecast::CommandError
              Log.error &.emit("Error while reconnecting to the device", name: device.name, uuid: device.uuid)
              remove_device(device, disconnect: false)
            end
          end
          # Only break if segment met the criteria and was skipped
          break
        end
      end
    end
  end

  private def remove_device(device : Chromecast::Device, disconnect = true) : Nil
    if continue = @devices.delete(device)
      continue.close

      if disconnect
        Log.info &.emit("Disconnecting from device", name: device.name, uuid: device.uuid)
        @chromecast.disconnect(device)
      end
    end
  end
end
