class Parsley
  class CurbDownloader
    def self.download(url, options = {})
      Curl.get(url) do |curl|
        curl.headers['User-Agent'] = options[:useragent] if options[:useragent]
      end.body_str
    end

    def self.download_to_file(url, path)
      Curl::Easy.download(url, path.full_path)
      path
    end
  end
end
