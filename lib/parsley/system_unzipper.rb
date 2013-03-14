class Parsley
  class SystemUnzipper
    def self.unzip(file, target = nil)
      extension = File.extname(file)
      case extension
      when '.gz' then
        `gzip -c -d #{file} > #{target}`
      when '.zip' then
        if target
          `unzip #{file} -d #{target}`
        else
          `unzip #{file} -d #{File.dirname(file)}`
        end
      else
        raise StandardError, "Don't know how to unzip file with extension #{extension}"
      end
      target
    end
  end
end
