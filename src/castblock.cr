require "clip"

require "./blocker"
require "./chromecast"
require "./sponsorblock"

module Castblock
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Command
    include Clip::Mapper

    @debug : Bool? = nil
    @[Clip::Option("--offset")]
    @[Clip::Doc("When skipping a sponsor segment, jump to this number of seconds before " \
                "the end of the segment.")]
    @seek_to_offset = 0

    def run
      if @debug
        ::Log.setup(:debug)
      end

      chromecast = Chromecast.new
      sponsorblock = Sponsorblock.new
      blocker = Blocker.new(chromecast, sponsorblock, @seek_to_offset)

      blocker.run
    end
  end

  def self.run
    begin
      command = Command.parse
    rescue ex : Clip::Error
      puts ex
      return
    end

    case command
    when Clip::Mapper::Help
      puts command.help
    else
      command.run
    end
  end
end

Castblock.run
