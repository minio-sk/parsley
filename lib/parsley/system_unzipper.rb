class Parsley
  class SystemUnzipper
    def self.unzip(file, target)
      `gzip -c -d #{file} > #{target}`
      target
    end
  end
end
