require 'nokogiri'
require 'sidekiq'

require 'parsley/curb_downloader'
require 'parsley/file_system_archiver'
require 'parsley/instant_queue'
require 'parsley/job'
require 'parsley/sidekiq_queue'
require 'parsley/system_unzipper'
require 'parsley/unoconv_extractor'

require 'tmpdir'

class Parsley
  def initialize(options = {})
    @queue = options[:queue] || InstantQueue
    @downloader = options[:downloader] || CurbDownloader
    @archiver = options[:archiver] || FileSystemArchiver.new('~/parsley')
    @unzipper = options[:unzipper] || SystemUnzipper
    @extractor = options[:extractor] || UnoconvExtractor
    @self_class = options[:self] || self.class
    @job_chain = Hash.new { |hash, key| hash[key] = [] }
  end

  def serialize
    @self_class.to_s
  end

  def enqueue(job, *args)
    raise UnsupportedJobError unless job.include?(Parsley::Job)
    @queue.enqueue(job, *args, self)
  end

  def chain(*job_sequence)
    job_sequence.each_cons(2) do |job, successor|
      @job_chain[job] << successor
    end
  end

  def notify_job_finished(job_class, results)
    @job_chain[job_class].each do |successor|
      results = [results] unless results.kind_of? Array
      results.each do |result|
        if result
          enqueue(successor, result)
        else
          enqueue(successor)
        end
      end
    end
  end

  def clean_html(html, options = {})
    html = html.encode('utf-8', options[:encoding]) if options[:encoding]
    html = clean_whitespace(html.gsub('&nbsp;', ' ')) if options[:clean_whitespace]
    html = html.gsub(/<br ?\/?>/i, "\n") if options[:replace_br]
    if options[:parse_html]
      Nokogiri::HTML(html)
    else
      html
    end
  end

  DEFAULT_DOWNLOAD_FILE_OPTIONS = {
      read_contents: false,
      archive: false,
      replace_br: false
  }

  def download_file(url, options = {})
    options = DEFAULT_DOWNLOAD_FILE_OPTIONS.merge(options)
    if options[:read_contents]
      html = if options[:http_options]
               @downloader.download(url, options[:http_options])
             else
               @downloader.download(url)
             end

      @archiver.archive(options[:archive], html) if options[:archive]
      clean_html(html, options)
    else
      path = if options[:archive]
               @archiver.archive_path(options[:archive])
             else
               create_temp_file_name
             end
      @downloader.download_to_file(url, path)
    end
  end

  DEFAULT_DOWNLOAD_HTML_OPTIONS = {
    parse_html: true,
    clean_whitespace: true
  }

  def download_html(url, options = {})
    options = DEFAULT_DOWNLOAD_HTML_OPTIONS.merge({read_contents: true}).merge(options)
    download_file(url, options)
  end

  def extract_text(file)
    clean_whitespace(@extractor.extract(file)).strip
  end

  def archive(path, data, options = {})
    @archiver.archive(path, data, options)
  end

  def unzip(path, options = {})
    if options[:in_place]
      target = nil
    else
      target = create_temp_file_name
    end
    @unzipper.unzip(@archiver.archive_path(path), target)
  end

  def find_files(pattern)
    Dir.glob(@archiver.archive_path(pattern))
  end

  class UnsupportedJobError < RuntimeError; end

  private
  def clean_whitespace(text)
    text.gsub("\u00A0", ' ').gsub("\uFEFF", ' ')
  end

  def create_temp_file_name
    Dir::Tmpname.create('parsley') {} # omg ruby, is this for real?
  end
end
