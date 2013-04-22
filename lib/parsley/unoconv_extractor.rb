class Parsley
  class UnoconvExtractor
    def self.extract(file, command = Command.new)
      command.run('unoconv -f txt --stdout ? 2>/dev/null', file)
    end
  end
end
