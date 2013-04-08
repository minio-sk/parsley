# encoding: utf-8
require 'nokogiri'
require 'sidekiq'

require 'parsley'
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
  let(:archiver) { mock(:Archiver) }
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

    it 'downloads a file and returns its path' do
      downloader.should_receive(:download_to_file).with('url', anything).and_return('file')
      infrastructure.download_file('url').should == 'file'
    end

    it 'downloads a file returns its contents and archives it' do
      downloader.should_receive(:download).with('url').and_return('<html>')
      archiver.should_receive(:archive).with('orsr.sk/1/1.html', '<html>')
      infrastructure.download_file('url', read_contents: true, archive: 'orsr.sk/1/1.html').should == "<html>"
    end

    it 'download a file, returns its path and archives it' do
      archive_path = 'archive/path/orsr.sk/1/1.html'
      archiver.should_receive(:archive_path).with('orsr.sk/1/1.html').and_return(archive_path)
      downloader.should_receive(:download_to_file).with('url', archive_path).and_return(archive_path)
      infrastructure.download_file('url', archive: 'orsr.sk/1/1.html').should == archive_path
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
      archiver.should_receive(:archive).with('path', 'data', {})
      infrastructure.archive('path', 'data')
    end

    it 'archives binary data' do
      archiver.should_receive(:archive).with('path', 'data', binary: true)
      infrastructure.archive('path', 'data', binary: true)
    end

    it 'returns path to archived data' do
      archiver.stub(archive: '/archive/path')
      infrastructure.archive('path', 'data').should == '/archive/path'
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
    it 'unzips the file' do
      unzipper.should_receive(:unzip).with('path/to/archive.zip', anything).and_return('unzipped_file')
      infrastructure.unzip('path/to/archive.zip').should == 'unzipped_file'
    end

    it 'unzips the file in-place' do
      unzipper.should_receive(:unzip).with('path/to/archive.zip', nil)
      infrastructure.unzip('path/to/archive.zip', in_place: true)
    end
  end

  describe '#extract_text' do
    it 'should extract plain text from a document file' do
      extractor.should_receive(:extract).with(:file).and_return('Hello from RTF. ')

      infrastructure.extract_text(:file).should == 'Hello from RTF.'
    end
  end

  describe '#find_files' do
    it 'finds files matching the pattern' do
      archiver.stub(archive_path: '/archives/dir/*.xml')
      Dir.should_receive(:glob).with('/archives/dir/*.xml').and_return([])
      infrastructure.find_files('dir/*.xml').should == []
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
    class ImportExtract
      include Parsley::Job

      def perform(*)
        {imported_id: 5234}
      end
    end
    class CleanExtract
      include Parsley::Job

      def perform(*)
        {id: 5234}
      end
    end
    class DeduplicateExtract
      include Parsley::Job

      def perform(*)
      end
    end

    it 'enqueues next job in chain, feeding it with the return value of the finished job' do
      infrastructure.chain ImportExtract, CleanExtract

      infrastructure.should_receive(:enqueue).with(ImportExtract).and_call_original
      infrastructure.should_receive(:enqueue).with(CleanExtract, {imported_id: 5234})

      infrastructure.enqueue(ImportExtract)
    end

    it 'enqueues next job even if the finished job is further in chain' do
      infrastructure.chain ImportExtract, CleanExtract, DeduplicateExtract

      infrastructure.should_receive(:enqueue).with(ImportExtract).and_call_original
      infrastructure.should_receive(:enqueue).with(CleanExtract, {imported_id: 5234}).and_call_original
      infrastructure.should_receive(:enqueue).with(DeduplicateExtract, {id: 5234})

      infrastructure.enqueue(ImportExtract)
    end

    it 'enqueues next job if the finished job has no return value' do
      infrastructure.chain DeduplicateExtract, CleanExtract

      infrastructure.should_receive(:enqueue).with(DeduplicateExtract).and_call_original
      infrastructure.should_receive(:enqueue).with(CleanExtract)

      infrastructure.enqueue(DeduplicateExtract)
    end

    it 'enqueues all successors of the finished jobs' do
      infrastructure.chain ImportExtract, CleanExtract
      infrastructure.chain ImportExtract, DeduplicateExtract

      infrastructure.should_receive(:enqueue).with(ImportExtract).and_call_original
      infrastructure.should_receive(:enqueue).with(CleanExtract, {imported_id: 5234})
      infrastructure.should_receive(:enqueue).with(DeduplicateExtract, {imported_id: 5234})

      infrastructure.enqueue(ImportExtract)
    end

    context 'when the return value is enumerable' do
      class ImportIssue
        include Parsley::Job

        def perform(*)
          [{path: 'path/to/xml1'}, {path: 'path/to/xml2'}]
        end
      end
      class ImportPleading
        include Parsley::Job

        def perform(*)
        end
      end

      it 'enqueues next job in chain for each element of the enumeration' do
        infrastructure.chain ImportIssue, ImportPleading

        infrastructure.should_receive(:enqueue).with(ImportIssue).and_call_original
        infrastructure.should_receive(:enqueue).with(ImportPleading, {path: 'path/to/xml1'})
        infrastructure.should_receive(:enqueue).with(ImportPleading, {path: 'path/to/xml2'})

        infrastructure.enqueue(ImportIssue)
      end
    end
  end
end
