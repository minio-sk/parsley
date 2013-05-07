require 'parsley/system_unzipper'
require 'parsley/command'
require 'parsley/paths'

class Parsley
  describe SystemUnzipper do
    let(:command) { mock(:Command) }
    let(:target) { Parsley::Path::Full.new('target') }
    subject(:unzipper) { SystemUnzipper.new(command) }

    it 'extracts gzipped archives' do
      command.should_receive(:run).with('gzip -f -c -d ? > ?', 'archive.gz', 'target')
      unzipper.unzip(Parsley::Path::Full.new('archive.gz'), target)
    end

    it 'extracts zipped archives' do
      command.should_receive(:run).with('unzip -o ? -d ?', 'archive.zip', 'target')
      unzipper.unzip(Parsley::Path::Full.new('archive.zip'), target)
    end

    it 'fails when trying to unzip unkown extension' do
      expect { unzipper.unzip(Parsley::Path.full('archive.foo'), target) }.to raise_error(StandardError)
    end

    it 'fails when the system command fails' do
      command.should_receive(:run).and_raise(Parsley::CommandFailed)
      expect { unzipper.unzip(Parsley::Path::Full.new('archive.zip'), target) }.to raise_error(Parsley::CommandFailed)
    end

    it 'returns list of files from the target directory' do
      command.stub(:run)
      target.should_receive(:glob).with('**/*').and_return(['file.txt'])
      unzipper.unzip(Parsley::Path::Full.new('archive.zip'), target).should == ['file.txt']
    end
  end
end
