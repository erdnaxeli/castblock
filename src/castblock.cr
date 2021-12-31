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
    @[Clip::Option("--category")]
    @[Clip::Doc("The category of segments to block. It can be repeated to block multiple categories.")]
    @categories = ["sponsor"]
    @[Clip::Option("--mute-ads")]
    @[Clip::Doc("Enable auto muting adsense ads on youtube.")]
    @mute_ads : Bool = false
    @[Clip::Option("--skip-ads")]
    @[Clip::Doc("Enable auto skipping adsense ads on youtube.")]
    @skip_ads : Bool = false
    @[Clip::Option("--merge-threshold")]
    @[Clip::Doc("The maximum number of seconds between segments to be merged. " \
                "Adjust this value to skip multiple adjacent segments that don't overlap.")]
    @merge_threshold = 0.0

    def read_env
      # If a config option equals its default value, we try to read it from the env.
      # This is a temporary hack while waiting for Clip to handle it in a better way.
      if @debug.nil? && (debug = ENV["DEBUG"]?)
        @debug = debug.downcase == "true"
      end

      if @seek_to_offset == 0 && (seek_to_offset = ENV["OFFSET"]?)
        @seek_to_offset == seek_to_offset.to_i
      end

      if @categories == ["sponsor"] && (categories = ENV["CATEGORIES"]?)
        @categories = categories.split(',')
      end

      if @mute_ads == false && (mute_ads = ENV["MUTE_ADS"]?)
        @mute_ads = mute_ads.downcase == "true"
      end

      if @skip_ads == false && (skip_ads = ENV["SKIP_ADS"]?)
        @skip_ads = skip_ads.downcase == "true"
      end

      if @merge_threshold == 0.0 && (merge_threshold = ENV["MERGE_THRESHOLD"]?)
        @merge_threshold == merge_threshold.to_f
      end
    end

    def run : Nil
      read_env

      if @debug
        ::Log.setup(:debug)
      end

      begin
        sponsorblock = Sponsorblock.new(@categories.to_set)
      rescue Sponsorblock::CategoryError
        return
      end

      chromecast = Chromecast.new
      blocker = Blocker.new(chromecast, sponsorblock, @seek_to_offset, @mute_ads, @skip_ads, @merge_threshold)

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
