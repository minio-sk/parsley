class Parsley
  class UnoconvExtractor
    def self.extract(file)
      `unoconv -f txt --stdout #{file} 2>/dev/null`
    end
  end
end