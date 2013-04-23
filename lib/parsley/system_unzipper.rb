class Parsley
  class SystemUnzipper
    def self.unzip(file, target = nil, command = Command.new)
      extension = File.extname(file)
      case extension
      when '.gz' then
        command.run('gzip -f -c -d ? > ?', file, target)
      when '.zip' then
        target ||= File.dirname(file)
        command.run('unzip -o ? -d ?', file, target)
      else
        raise StandardError, "Don't know how to unzip file with extension #{extension}"
      end

      target
    end
  end
end
