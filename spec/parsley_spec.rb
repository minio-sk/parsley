# encoding: utf-8
require 'nokogiri'
require 'sidekiq'

require 'parsley'
require 'parsley/paths'
#require 'active_support/core_ext/string/conversions'
#require 'active_support/core_ext/class/attribute_accessors'

class MockJob
  include Parsley::Job

  def self.args
    @@args
  end

  def perform(*args)
    @@args = args
  end
end

class NonParsleyJob; end
class TestInfrastructure; end

class Parsley::Path
  def ensure_exists!; end
end

describe Parsley do
  describe "#enqueue" do
    it 'enqueues a job and passes parameters with infrastructure' do
      infrastructure = Parsley.new
      infrastructure.enqueue(MockJob, :param1, :param2)

      MockJob.args.should == [:param1, :param2, infrastructure]
    end

    it 'throws error when trying to enqueue a non parsley job' do
      infrastructure = Parsley.new
      expect { infrastructure.enqueue(NonParsleyJob) }.to raise_error(Parsley::UnsupportedJobError)
    end
  end

  let(:downloader) { mock(:Downloader) }
  let(:archiver) { double(:Archiver, root: '/archive') }
  let(:unzipper) { mock(:Unzipper) }
  let(:extractor) { mock(:Extractor) }
  let(:infrastructure) { Parsley.new(downloader: downloader, archiver: archiver, unzipper: unzipper, extractor: extractor) }

  describe '#download_file' do
    it 'downloads a file and return contents' do
      downloader.should_receive(:download).and_return('<html>')
      infrastructure.download_file('http://orsr.sk', read_contents: true).should == '<html>'
    end

    it 'downloads a file and converts it to utf8 from another encoding' do
      downloader.should_receive(:download).and_return("Jožko Mrkvičkovský".encode('windows-1250'))
      html = infrastructure.download_file('url', read_contents: true, encoding: 'windows-1250')
      html.should == "Jožko Mrkvičkovský"
      html.encoding.name.should == 'UTF-8'
    end

    it 'downloads a file and removes nonbreaking spaces' do
      downloader.should_receive(:download).and_return("<html>&nbsp;\u00A0</html>")
      infrastructure.download_file('url', read_contents: true, clean_whitespace: true).should == "<html>  </html>"
    end

    it 'downloads a file and replaces <br> tag by newline' do
      downloader.should_receive(:download).and_return("<html>Ahoj<br>Ferko</html>")
      infrastructure.download_file('url', read_contents: true, replace_br: true).should == "<html>Ahoj\nFerko</html>"
    end

    it 'downloads a file and replaces <br/> tag by newline' do
      downloader.should_receive(:download).and_return("<html>Ahoj<br/>Ferko</html>")
      infrastructure.download_file('url', read_contents: true, replace_br: true).should == "<html>Ahoj\nFerko</html>"
    end

    it 'downloads a file and replaces <BR> tag by newline' do
      downloader.should_receive(:download).and_return("<html>Ahoj<BR>Ferko</html>")
      infrastructure.download_file('url', read_contents: true, replace_br: true).should == "<html>Ahoj\nFerko</html>"
    end

    it 'downloads a file and replaces <br /> tag by newline' do
      downloader.should_receive(:download).and_return("<html>Ahoj<br />Ferko</html>")
      infrastructure.download_file('url', read_contents: true, replace_br: true).should == "<html>Ahoj\nFerko</html>"
    end

    context 'without :archive option' do
      it 'returns instance of full path' do
        downloader.stub(:download_to_file)
        infrastructure.download_file('url').should be_a Parsley::Path::Full
      end

      it 'downloads a file to temporary location and returns its path' do
        downloader.should_receive(:download_to_file).with('url', anything)
        infrastructure.download_file('url').to_s.should =~ /\/tmp/
      end
    end

    context 'with :archive option' do
      it 'downloads a file, returns its contents and archives it' do
        downloader.should_receive(:download).with('url', {}).and_return('<html>')
        archiver.should_receive(:archive).with(Parsley::Path::ArchiveRelative.new('orsr.sk/1/1.html', '/archive'), '<html>', binary: true)
        infrastructure.download_file('url', read_contents: true, archive: 'orsr.sk/1/1.html').should == "<html>"
      end

      it 'downloads a file, returns its path and archives it' do
        archive_path = Parsley::Path::ArchiveRelative.new('orsr.sk/1/1.html', '/archive')
        downloader.should_receive(:download_to_file).with('url', archive_path)
        infrastructure.download_file('url', archive: 'orsr.sk/1/1.html').should == archive_path
      end
    end

    it 'passes http options to downloader' do
      downloader.should_receive(:download).with('url', {useragent: :something}).and_return('<html>')
      infrastructure.download_html('url', http_options: {useragent: :something})
    end
  end

  describe '#clean_html' do
    it 'removes nonbreaking spaces from input' do
      infrastructure.clean_html("<html>&nbsp;\u00A0</html>", clean_whitespace: true).should == "<html>  </html>"
    end

    it 'converts input to utf8' do
      html = infrastructure.clean_html('Mrkvičkový'.encode('windows-1250'), encoding: 'windows-1250')
      html.should == "Mrkvičkový"
      html.encoding.name.should == 'UTF-8'
    end

    it 'parses html' do
      doc = stub
      Nokogiri.should_receive(:HTML).with('<html>').and_return(doc)
      infrastructure.clean_html('<html>', parse_html: true).should == doc
    end
  end

  describe '#download_html' do
    it 'downloads html and returns parsed doc' do
      doc = stub
      downloader.stub(download: 'html')
      Nokogiri.should_receive(:HTML).with('html').and_return(doc)
      infrastructure.download_html('url').should == doc
    end

    it 'downloads html and returns plain html' do
      downloader.stub(download: '<html>')
      infrastructure.download_html('url', parse_html: false).should == '<html>'
    end

    it 'downloads html and cleans it from whitespace' do
      downloader.stub(download: "<html&nbsp;without\u00A0bullshit>")
      infrastructure.download_html('url_with_nonbreakingspaces_and_utf8_special_spaces', parse_html: false).should == '<html without bullshit>'
    end

    it 'downloads html and converts it to utf8' do
      downloader.stub(download: 'Mrkvičkový'.encode('windows-1250'))
      html = infrastructure.download_html('url', encoding: 'windows-1250', parse_html: false)
      html.should == "Mrkvičkový"
      html.encoding.name.should == 'UTF-8'
    end

    pending 'downloads html and cleans it using custom cleaner' do
      infrastructure.download_html(url, cleaner: ->(html) { html.gsub('<br>', ' ') })
    end
  end

  describe '#archive' do
    it 'archives data' do
      archiver.should_receive(:archive).with(Parsley::Path::ArchiveRelative.new('path', '/archive'), 'data', {})
      infrastructure.archive('path', 'data')
    end

    it 'archives binary data' do
      archiver.should_receive(:archive).with(Parsley::Path::ArchiveRelative.new('path', '/archive'), 'data', binary: true)
      infrastructure.archive('path', 'data', binary: true)
    end

    it 'returns path relative to archive' do
      archiver.stub(archive: nil)
      infrastructure.archive('path', 'data').should be_a(Parsley::Path::ArchiveRelative)
    end

    pending 'archives arbitrary file' do
      infrastructure.archive(file, 'archived_file_path')
    end

    pending 'throws error when trying to overwrite archived file'

    pending 'is able to force overwrite on archived file' do
      infrastructure.archive(file, 'path', force_overwrite: true)
    end
  end

  describe '#unzip' do
    context 'when invoked with a Path' do
      it 'sends the path to the archiver verbatim' do
        path = Parsley::Path::Full.new('path')
        unzipper.should_receive(:unzip).with(path, anything)
        infrastructure.unzip(path)
      end
    end

    context 'when invoked with a String instead of a Path' do
      it 'wraps the String path in a Parsley::Path::Full' do
        unzipper.should_receive(:unzip).with(Parsley::Path::Full.new('foo.zip'), anything)
        infrastructure.unzip('foo.zip')
      end
    end

    it 'unzips to temporary path' do
      unzipper.should_receive(:unzip).with do |_, target|
        target.full_path.should =~ /\/tmp/
      end
      infrastructure.unzip('path')
    end

    it 'unzips the file in-place' do
      path = Parsley::Path.new('/somewhere/here/is.zip')
      unzipper.should_receive(:unzip).with(anything, Parsley::Path::Full.new('/somewhere/here'))
      infrastructure.unzip(path, in_place: true)
    end

    it 'unzips the file to the specified target' do
      target = Parsley::Path::Full.new('target')
      unzipper.should_receive(:unzip).with(anything, target)
      infrastructure.unzip('archive.zip', to: target)
    end

    it 'returns the unzipper return value' do
      unzipper.stub(unzip: 'unzipped')
      infrastructure.unzip('path').should == 'unzipped'
    end
  end

  describe '#read_archive' do
    it 'builds archive relative path and delegates to archiver' do
      archiver.should_receive(:read).with(Parsley::Path::ArchiveRelative.new('file.xml', '/archive')).and_return('contents')
      infrastructure.read_archive('file.xml').should == 'contents'
    end
  end

  describe '#extract_text' do
    it 'should extract plain text from a document file' do
      extractor.should_receive(:extract).with(:file).and_return('Hello from RTF.')

      infrastructure.extract_text(:file).should == 'Hello from RTF.'
    end
  end

  pending 'should allow browsing aspx sites' do
    infrastructure.browse do |browser| # mechanize API
      browser.get(url) do |page|
        results = page.form_with(name: 'PC_7_0_5AQJO_form1') do |form|
          form.nazov = name
        end.submit
        # ...
      end
    end
  end

  pending 'extracts text from pdf or doc file' do
    infrastructure.extract_text('pdf_or_doc_file').should == 'extracted text'
    # or
    infrastructure.download_file('pdf_or_doc_file', extract_text: true)
  end

  pending 'requests user interaction before queuing' do
    interaction = mock(:SocPoistCaptchaEntry)
    infrastructure.enqueue_after_user_interaction(interaction, job)
  end

  context 'after the queued job is finished' do
    class NextJob
      include Parsley::Job
      def perform(*); end
    end

    it 'enqueues next job in chain, feeding it with the values piped from the finished job' do
      class JobThatSendsMessage
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.notify_chain(self, 5234, 43)
        end
      end

      infrastructure.chain JobThatSendsMessage, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatSendsMessage).and_call_original
      infrastructure.should_receive(:enqueue).with(NextJob, 5234, 43)

      infrastructure.enqueue(JobThatSendsMessage)
    end

    it 'enqueues next job even if no args were passed' do
      class JobThatSendsEmptyMessage
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.notify_chain(self)
        end
      end

      infrastructure.chain JobThatSendsEmptyMessage, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatSendsEmptyMessage).and_call_original
      infrastructure.should_receive(:enqueue).with(NextJob)

      infrastructure.enqueue(JobThatSendsEmptyMessage)
    end

    it 'enqueues next job even if not explicitely signaled' do
      class JobThatDoesNothing
        include Parsley::Job
        def perform(infrastructure)
        end
      end

      infrastructure.chain JobThatDoesNothing, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatDoesNothing).and_call_original
      infrastructure.should_receive(:enqueue).with(NextJob)

      infrastructure.enqueue(JobThatDoesNothing)
    end

    it 'does not enqueue next job if halted' do
      class JobThatHaltsChain
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.halt_chain(self)
        end
      end

      infrastructure.chain JobThatHaltsChain, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatHaltsChain).and_call_original
      infrastructure.should_not_receive(:enqueue).with(NextJob)
      infrastructure.enqueue(JobThatHaltsChain)
    end

    it 'ignores previous messages if halted' do
      class JobThatSendsMessageAndHalts
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.notify_chain(self)
          infrastructure.halt_chain(self)
        end
      end

      infrastructure.chain JobThatSendsMessageAndHalts, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatSendsMessageAndHalts).and_call_original
      infrastructure.should_not_receive(:enqueue).with(NextJob)

      infrastructure.enqueue(JobThatSendsMessageAndHalts)
    end

    it 'enqueues next job only after the job finished successfully' do
      class JobThatSendsMessageAndRaises
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.notify_chain(self)
          raise "hell"
        end
      end

      infrastructure.chain JobThatSendsMessageAndRaises, NextJob
      infrastructure.should_receive(:enqueue).with(JobThatSendsMessageAndRaises).and_call_original
      infrastructure.should_not_receive(:enqueue).with(NextJob)

      infrastructure.enqueue(JobThatSendsMessageAndRaises) rescue nil
    end

    it 'serializes message if it responds to #serialize' do
      class JobThatWantsToEnqueueSerializable
        include Parsley::Job
        def perform(infrastructure)
          arg = Class.new do
            def serialize
              "serialized"
            end
          end.new
          infrastructure.notify_chain(self, arg)
        end
      end

      infrastructure.chain JobThatWantsToEnqueueSerializable, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatWantsToEnqueueSerializable).and_call_original
      infrastructure.should_receive(:enqueue).with(NextJob, "serialized")

      infrastructure.enqueue(JobThatWantsToEnqueueSerializable)
    end

    it 'enqueues jobs further down the chain' do
      class FirstJob
        include Parsley::Job
        def perform(infrastructure); infrastructure.notify_chain(self); end
      end
      class SecondJob
        include Parsley::Job
        def perform(infrastructure); infrastructure.notify_chain(self); end
      end
      class ThirdJob
        include Parsley::Job
        def perform(infrastructure); end
      end
      infrastructure.chain FirstJob, SecondJob, ThirdJob

      infrastructure.should_receive(:enqueue).with(FirstJob).and_call_original
      infrastructure.should_receive(:enqueue).with(SecondJob).and_call_original
      infrastructure.should_receive(:enqueue).with(ThirdJob)

      infrastructure.enqueue(FirstJob)
    end

    it 'enqueues all successors of the finished job' do
      class JobWithManySuccessors
        include Parsley::Job
        def perform(infrastructure); infrastructure.notify_chain(self); end
      end
      class AnotherJob
        include Parsley::Job
        def perform(infrastructure); end
      end
      class YetAnotherJob
        include Parsley::Job
        def perform(infrastructure); end
      end

      infrastructure.chain JobWithManySuccessors, AnotherJob
      infrastructure.chain JobWithManySuccessors, YetAnotherJob

      infrastructure.should_receive(:enqueue).with(JobWithManySuccessors).and_call_original
      infrastructure.should_receive(:enqueue).with(AnotherJob)
      infrastructure.should_receive(:enqueue).with(YetAnotherJob)

      infrastructure.enqueue(JobWithManySuccessors)
    end

    it 'enqueues successor for each sent message' do
      class JobThatSendsMultipleMessages
        include Parsley::Job
        def perform(infrastructure)
          infrastructure.notify_chain(self, :foo);
          infrastructure.notify_chain(self, :moo);
        end
      end

      infrastructure.chain JobThatSendsMultipleMessages, NextJob

      infrastructure.should_receive(:enqueue).with(JobThatSendsMultipleMessages).and_call_original
      infrastructure.should_receive(:enqueue).with(NextJob, :foo)
      infrastructure.should_receive(:enqueue).with(NextJob, :moo)

      infrastructure.enqueue(JobThatSendsMultipleMessages)
    end
  end
end
