require 'parsley/system_unzipper'
require 'parsley/command'

class Parsley
  describe SystemUnzipper do
    let(:command) { mock(:Command) }

    it 'extracts gzipped archives' do
      command.should_receive(:run).with('gzip -c -d ? > ?', 'archive.gz', 'target')
      SystemUnzipper.unzip('archive.gz', 'target', command).should == 'target'
    end

    it 'extracts zipped archives' do
      command.should_receive(:run).with('unzip ? -d ?', 'archive.zip', 'target')
      SystemUnzipper.unzip('archive.zip', 'target', command).should == 'target'
    end

    it 'fails when trying to unzip unkown extension' do
      expect { SystemUnzipper.unzip('archive.foo', 'target', command) }.to raise_error(StandardError)
    end

    it 'fails when the system command fails' do
      command.should_receive(:run).with('unzip ? -d ?', 'archive.zip', 'target').and_raise(Parsley::CommandFailed)
      expect { SystemUnzipper.unzip('archive.zip', 'target', command) }.to raise_error(Parsley::CommandFailed)
    end
  end
end
