class Parsley
  class SystemUnzipper
    def initialize(command = Command.new)
      @command = command
      @inflaters = [GunzipInflater.new, UnzipInflater.new]
    end

    def unzip(path, target)
      unzipper_for(path.extension).run(@command, path.full_path, target.full_path)
      target.glob('**/*')
    end

    def unzipper_for(extension)
      inflater = @inflaters.detect { |i| i.can_inflate?(extension) }
      if inflater
        inflater
      else
        raise StandardError, "Don't know how to unzip file with extension #{extension}"
      end
    end

    class GunzipInflater
      def run(command, path, target)
        command.run('gzip -f -c -d ? > ?', path, target)
      end

      def can_inflate?(extension)
        extension == '.gz'
      end
    end

    class UnzipInflater
      def run(command, path, target)
        command.run('unzip -o ? -d ?', path, target)
      end

      def can_inflate?(extension)
        extension == '.zip'
      end
    end
  end
end
