require 'parsley/command'
require 'parsley'

describe Parsley::UnoconvExtractor do
  it 'extracts', slow: true do
    file = File.dirname(__FILE__) + '/fixtures/example.rtf'
    described_class.extract(file).gsub("\u{feff}", "").strip.should == "Hello from RTF."
  end
end
