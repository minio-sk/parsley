class Parsley
  class FileSystemArchiver
    def initialize(root, segmenter = NumericSegmenter)
      @root = root
      @segmenter = segmenter
    end

    def archive_path(path)
      segmented_path = @segmenter.segment(path)
      target_path = "#{@root}/#{segmented_path}"
      FileUtils.mkdir_p(File.dirname(target_path))
      target_path
    end

    def archive(path, contents, options = {})
      if options[:binary]
        write_options = { mode: "wb" }
      else
        write_options = { mode: "w" }
      end
      File.write(archive_path(path), contents, write_options)
    end

    class NumericSegmenter
      def self.segment(path)
        path_chunks = path.split('/')
        output = []
        path_chunks.each do |chunk|
          numbers = chunk.scan(/[0-9]{3,}/).collect do |part|
            part.to_i / 1000 * 1000
          end
          output += numbers if numbers.any?
          output << chunk
        end
        "#{output.join('/')}"
      end
    end
  end
end
