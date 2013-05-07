class Parsley
  class FileSystemArchiver
    def initialize(root)
      @root = root
    end

    attr_reader :root

    def archive(archive_path, contents, options = {})
      if options[:binary]
        write_options = { mode: "wb" }
      else
        write_options = { mode: "w" }
      end
      File.write(archive_path.full_path, contents, write_options)
      archive_path
    end

    def read(archive_path)
      File.read(archive_path.full_path)
    end
  end
end
