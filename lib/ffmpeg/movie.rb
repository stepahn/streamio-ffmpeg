module FFMPEG
  class Movie
    attr_reader :path, :duration, :time, :bitrate
    attr_reader :audio_streams, :video_streams, :subtitles
    
    LANGUAGE_MAP = {
      'deu' => 'ger',
      'und' => nil
    }
    
    def self.language(value)
      LANGUAGE_MAP.include?(value) ? LANGUAGE_MAP[value] : value
    end
    
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
      
      @audio_streams = []
      @video_streams = []
      @subtitles     = []
      
      # parse streams
      output.scan(/(\((\w+)\))?: (Audio|Video|Subtitle): (.+)/).each do |stream|
        language = self.class.language(stream[1])
        raw      = stream[3]
        
        case stream[2]
          when 'Audio'
            @audio_streams << AudioStream.new(language, raw)
          when 'Video'
            @video_streams << VideoStream.new(language, raw)
          when 'Subtitle'
            @subtitles << Subtitle.new(language, raw)
        end
      end
      
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
