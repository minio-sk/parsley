require 'nokogiri'
require 'sidekiq'

require 'parsley/paths'
require 'parsley/command'
require 'parsley/curb_downloader'
require 'parsley/file_system_archiver'
require 'parsley/instant_queue'
require 'parsley/job'
require 'parsley/sidekiq_queue'
require 'parsley/system_unzipper'
require 'parsley/unoconv_extractor'

require 'tmpdir'
require 'fileutils'

class Parsley
  def initialize(options = {})
    @queue = options[:queue] || InstantQueue
    @downloader = options[:downloader] || CurbDownloader
    @archiver = options[:archiver] || FileSystemArchiver.new('~/parsley')
    @unzipper = options[:unzipper] || SystemUnzipper.new
    @extractor = options[:extractor] || UnoconvExtractor
    @self_class = options[:self] || self.class
    @job_chain = Hash.new { |hash, key| hash[key] = [] }
    @messages = Hash.new { |hash, key| hash[key] = [] }
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

  def notify_job_finished(job)
    @job_chain[job.class].each do |successor|
      @messages[job].each { |args| enqueue(successor, *args) }
    end
    @messages.delete(job)
  end

  def message(source, *args)
    @messages[source] << args.map { |arg| arg.respond_to?(:serialize) ? arg.serialize : arg }
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
    http_options = options[:http_options] || {}
    target_path = archive_path_or_tmp_path(options[:archive])

    if options[:read_contents]
      html = @downloader.download(url, http_options)
      @archiver.archive(target_path, html, binary: true) if options[:archive]
      clean_html(html, options)
    else
      @downloader.download_to_file(url, target_path)
      target_path
    end
  end

  def archive_path_or_tmp_path(archive_path)
    target_path = if archive_path
      archive_relative_path(archive_path)
    else
      full_path(create_temp_file_name)
    end
    target_path.ensure_exists!
    target_path
  end
  private :archive_path_or_tmp_path

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
    archive_path = archive_relative_path(path)
    archive_path.ensure_exists!
    @archiver.archive(archive_path, data, options)
    archive_path
  end

  def unzip(path, options = {})
    path = full_path(path) unless path.respond_to?(:full_path)
    if options[:in_place]
      target = path.dirname
    elsif options[:to]
      target = options[:to]
    else
      target = full_path(create_temp_file_name)
      target.ensure_exists!
    end
    @unzipper.unzip(path, target)
  end

  def read_archive(path)
    @archiver.read(archive_relative_path(path))
  end

  def archive_relative_path(path)
    Parsley::Path::ArchiveRelative.new(path, @archiver.root)
  end

  def full_path(path)
    Parsley::Path::Full.new(path)
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
