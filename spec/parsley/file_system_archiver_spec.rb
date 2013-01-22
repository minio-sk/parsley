require 'parsley/file_system_archiver'

describe Parsley::FileSystemArchiver do
  subject { Parsley::FileSystemArchiver.new('/app/archives') }

  it 'computes segmented archive path' do
    segmenter = mock
    archiver = described_class.new('/app/archives', segmenter)
    segmenter.should_receive(:segment).with("path/1.html").and_return("segmented/path/1.html")
    FileUtils.should_receive(:mkdir_p).with("/app/archives/segmented/path")
    archiver.archive_path("path/1.html").should == "/app/archives/segmented/path/1.html"
  end

  it 'archives arbitrary data' do
    FileUtils.stub(mkdir_p: nil)
    File.should_receive(:write).with("/app/archives/orsr.sk/1.html", "<html>", mode: "w")
    subject.archive('orsr.sk/1.html', '<html>')
  end

  it 'archives arbitrary binary data' do
    FileUtils.stub(mkdir_p: nil)
    File.should_receive(:write).with("/app/archives/orsr.sk/1.html", "<html>", mode: "wb")
    subject.archive('orsr.sk/1.html', '<html>', binary: true)
  end
end
