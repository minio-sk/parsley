require 'parsley/file_system_archiver'
require 'parsley/paths'

describe Parsley::FileSystemArchiver do
  let(:root) { '/app/archives' }
  subject(:archiver) { Parsley::FileSystemArchiver.new(root) }

  it 'archives arbitrary data' do
    File.should_receive(:write).with("/app/archives/orsr.sk/1.html", "<html>", mode: "w")
    archiver.archive(Parsley::Path::ArchiveRelative.new('orsr.sk/1.html', root), '<html>')
  end

  it 'archives arbitrary binary data' do
    File.should_receive(:write).with("/app/archives/orsr.sk/1.html", "<html>", mode: "wb")
    archiver.archive(Parsley::Path::ArchiveRelative.new('orsr.sk/1.html', root), '<html>', binary: true)
  end

  it 'returns the original path' do
    File.should_receive(:write)
    path = Parsley::Path::ArchiveRelative.new('path', root)
    archiver.archive(path, 'content').should == path
  end
end
