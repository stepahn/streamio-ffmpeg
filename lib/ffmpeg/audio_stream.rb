module FFMPEG
  class AudioStream
    attr_reader :language, :codec, :bitrate, :sample_rate, :channels
    
    def initialize(language, raw)
      @language = language
      @codec, sample_rate, @channels, unused, bitrate = raw.split(/\s?,\s?/)
      @bitrate = bitrate =~ %r(\A(\d+) kb/s\Z) ? $1.to_i : nil
      @sample_rate = sample_rate[/\d*/].to_i
    end
    
    def channels
      return nil unless @channels
      return @channels[/\d*/].to_i if @channels["channels"]
      return 1 if @channels["mono"]
      return 2 if @channels["stereo"]
      return 6 if @channels["5.1"]
    end
  end
end
