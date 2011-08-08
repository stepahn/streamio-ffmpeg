module FFMPEG
  class Movie
    attr_reader :path, :duration, :time, :bitrate
    attr_reader :audio_streams, :video_streams, :subtitles
    
    def initialize(path)
      raise Errno::ENOENT, "the file '#{path}' does not exist" unless File.exists?(path)
      
      @path = escape(path)

      stdin, stdout, stderr = Open3.popen3("ffmpeg", "-i", path) # Output will land in stderr
      output = stderr.read
      
      fix_encoding(output)
      
      output[/Duration: (\d{2}):(\d{2}):(\d{2}\.\d{1})/]
      @duration = ($1.to_i*60*60) + ($2.to_i*60) + $3.to_f
      
      output[/start: (\d*\.\d*)/]
      @time = $1 ? $1.to_f : 0.0
      
      output[/bitrate: (\d*)/]
      @bitrate = $1 ? $1.to_i : nil
      
      @audio_streams = output.scan(/\((\w+)\): Audio: (.*)/).map{|arr| AudioStream.new(arr[0], arr[1]) }
      @video_streams = output.scan(/\((\w+)\): Video: (.*)/).map{|arr| VideoStream.new(arr[0], arr[1]) }
      @subtitles     = output.scan(/\((\w+)\): Subtitle: (.*)/).map{|arr| Subtitle.new(arr[0], arr[1]) }
      
      @uncertain_duration = true #output.include?("Estimating duration from bitrate, this may be inaccurate") || @time > 0
      
      @invalid = @video_streams.empty? && @audio_streams.empty?
    end
    
    def valid?
      not @invalid
    end
    
    def uncertain_duration?
      @uncertain_duration
    end
    
    def resolution
      stream = video_streams.first
      stream ? stream.resolution : nil
    end
    
    def width
      resolution.to_s.split("x")[0].to_i
    end
    
    def height
      resolution.to_s.split("x")[1].to_i
    end
    
    def calculated_aspect_ratio
      if dar
        w, h = dar.split(":")
        w.to_f / h.to_f
      else
        aspect = width.to_f / height.to_f
        aspect.nan? ? nil : aspect
      end
    end
    
    def size
      File.size(@path)
    end
    
    def transcode(output_file, options = EncodingOptions.new, transcoder_options = {}, &block)
      Transcoder.new(self, output_file, options, transcoder_options).run &block
    end
    
    protected
    def escape(path)
      map  =  { '\\' => '\\\\', '</' => '<\/', "\r\n" => '\n', "\n" => '\n', "\r" => '\n', '"' => '\\"', "'" => "\\'" }
      path.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { map[$1] }
    end
    
    def fix_encoding(output)
      output[/test/] # Running a regexp on the string throws error if it's not UTF-8
    rescue ArgumentError
      output.force_encoding("ISO-8859-1")
    end
  end
end
