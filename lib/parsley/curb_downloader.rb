class Parsley
  class CurbDownloader
    def self.download(url)
      Curl.get(url).body_str
    end

    def self.download_to_file(url, path)
      Curl::Easy.download(url, path)
      path
    end
  end
end
