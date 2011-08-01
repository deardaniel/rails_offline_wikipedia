module WikiDb
  mattr_accessor :max_search_results
  @@max_search_results = 25

  mattr_accessor :index_toc_file
  @@index_toc_file = nil

    mattr_accessor :index_file
  @@index_file = nil

  mattr_accessor :bz2table_file
  @@bz2table_file = nil

  mattr_accessor :wiki_xml_dump
  @@wiki_xml_dump = nil

  mattr_accessor :seek_bunzip_cmd
  @@seek_bunzip_cmd = nil
  
  # private
  
  mattr_accessor :index_toc
  @@index_toc = nil
  
  mattr_accessor :bzip_table
  @@bzip_table = nil
  
  mattr_accessor :page_cache_size
  @@page_cache_size = 100
  
  @@cache = {}
  
  def self.cache_set(key, value)
    @@cache[key] = value
    @@cache.delete[@@cache.first[0]] while @@cache.count > @@page_cache_size
  end
  
  def self.cache_get(key, ignore_case = false)
    if ignore_case
      return @@cache[key]
    else
      @@cache.each_key { |k| return @@cache[k] if k.casecmp(key) == 0 }  # A little expensive perhaps..?
    end
    return nil
  end
  
  def self.setup
    yield self

    @@index_toc = Marshal.load File.open(@@index_toc_file)

    @@bzip_table = []
    open(@@bz2table_file).each do |line|
      block_offset, length, offset = line.split(' ')
      @@bzip_table << { :block_offset => block_offset.to_i, :length => length.to_i, :offset => offset.to_i }
    end
  end
end
