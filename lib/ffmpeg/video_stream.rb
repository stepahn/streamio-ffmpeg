module FFMPEG
  class VideoStream
    attr_reader :language, :codec, :colorpsace, :bitrate, :resolution, :dar, :frame_rate
    
    def initialize(language, raw)
      @codec, @colorspace, resolution, bitrate = raw.split(/\s?,\s?/)
      @bitrate = bitrate =~ %r(\A(\d+) kb/s\Z) ? $1.to_i : nil
      @resolution = resolution.split(" ").first rescue nil # get rid of [PAR 1:1 DAR 16:9]
      @dar = $1 if raw[/DAR (\d+:\d+)/]
      @frame_rate = raw[/(\d*\.?\d*)\s?fps/] ? $1.to_f : nil
    end
    
  end
end
