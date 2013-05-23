class Parsley
  class CurbDownloader
    def self.download(url, options = {})
      Curl.get(url) do |curl|
        curl.headers['User-Agent'] = options[:useragent] if options[:useragent]
        if options[:cookies]
          cookies = []
          options[:cookies].each do |key, value|
            cookies << "#{key}=#{value};"
          end
          curl.cookies = cookies.join(' ')
        end
      end.body_str
    end

    def self.download_to_file(url, path)
      Curl::Easy.download(url, path.full_path)
      path
    end
  end
end
