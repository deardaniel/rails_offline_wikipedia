require 'open-uri'

class DownloadImageJob < Struct.new(:file, :url)
  def perform
    tmp_file = "#{::Rails.root.to_s}/image_cache/#{file}"
    return if File.exists?(tmp_file) && File.size(tmp_file) > 0 # TODO make a cache expiry mechanism
    
    page = open(url).read
    if page.match(/<a href="([^"]+)"[^>]*>(Full resolution|#{Regexp.quote(file.tr(' ', '_'))})<\/a>/i)
      IO.copy_stream(open($1), open(tmp_file, 'wb'))
      # file_data = open($1).read
      # open(tmp_file, 'wb') { |f| f.write file_data } if file_data
      puts "Downloaded \"#{file}\"."
    end
  end
end
