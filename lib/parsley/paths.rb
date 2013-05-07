class Parsley
  class Path
    def initialize(path)
      @path = path
    end

    def to_str
      @path
    end
    alias :to_s :to_str

    def serialize
      @path
    end

    def extension
      File.extname(@path)
    end

    def ensure_exists!
      FileUtils.mkdir_p(dirname.full_path)
    end

    def ==(other)
      if other.respond_to?(:full_path)
        full_path == other.full_path
      else
        super
      end
    end

    class ArchiveRelative < Path
      def initialize(path, archive_root)
        super(path)
        @root = archive_root
      end

      def full_path
        File.join(@root, @path)
      end

      def dirname
        self.class.new(File.dirname(@path), @root)
      end

      def append(path)
        self.class.new(File.join(@path, path), @root)
      end

      def glob(pattern)
        Dir.glob(File.join(full_path, pattern)).map { |f| append(f.sub(full_path, "")) }
      end
    end

    class Full < Path
      def full_path
        @path
      end

      def dirname
        self.class.new(File.dirname(full_path))
      end

      def append(path)
        self.class.new(File.join(@path, path))
      end

      def glob(pattern)
        Dir.glob(File.join(@path, pattern))
      end
    end
  end
end
