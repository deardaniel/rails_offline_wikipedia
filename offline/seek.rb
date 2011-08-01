require 'nokogiri'
require 'wikicloth'

class WikiDB
  INDEX_TOC_FILE = 'wikidb/wikidb.index_toc'
  INDEX_FILE = 'wikidb/wikidb.index'
  BZ2TABLE_FILE = 'wikidb/wikidb.bz2t'
  
  def initialize
    index_toc = Marshal.load File.open(INDEX_TOC_FILE)
    # puts "Loaded index TOC. (#{index_toc.length} entries)"

    $bzip_table = []
    open(BZ2TABLE_FILE).each do |line|
      block_offset, length, offset = line.split(' ')
      $bzip_table << { :block_offset => block_offset.to_i, :length => length.to_i, :offset => offset.to_i }
    end

    # puts "Loaded bzip2 index. (#{$bzip_table.length} entries)"
  end
  
  def search query
    File.open(INDEX_FILE, :external_encoding => "UTF-8") do |index|
      q = title_hash query
      index.seek(index_toc[q], IO::SEEK_SET)
      results = []
      while q == title_hash(line = index.readline)
        results << line.chomp if line.downcase.start_with? search.downcase
      end
      match = results.grep(/^#{search} \d+$/).first
      puts "Found #{results.count} results."
      if match && match.match(/ (\d+)$/)
        puts "Found perfect match."
        return get_page($1.to_i)
      else
        return nil
      end
    end
  end

  private

  def title_hash s
    b = s[0,3].downcase.bytes.to_a
    ((b[0] || 0) << 16) + ((b[1] || 0) << 8) + (b[2] || 0)
  end

  def find_block_num offset
    low = 0
    high = $bzip_table.count
    result = nil
    while result.nil?
      c = low + (high - low) / 2
      b = $bzip_table[c]
      if offset < b[:offset]
        high = c
      elsif offset > (b[:offset]+b[:length])
        low = c
      else
        result = c
      end
    end
    c
  end

  def get_page offset
    block = $bzip_table[find_block_num(offset)]
    offset_within_block = (offset - block[:offset])
    block_data = `./seek-bunzip #{block[:block_offset]} < ../enwiki-latest-pages-articles.xml.bz2`
    page_data = block_data.force_encoding("BINARY")[offset_within_block..-1]
  
    page = nil
    parser = Nokogiri::XML::SAX::PushParser.new(Class.new(Nokogiri::XML::SAX::Document) {
        attr_reader :page
      
        def start_element name, attrs = []
          @current_tag = name
          # @title = '' if name == "title"
          @text_buffer = '' if name == "text"
        end
      
        def characters s
          # @title << s if @current_tag == "title"
          @text_buffer << s if @current_tag == "text"
        end

        def end_element name
          if name == 'page'
            @page = @text_buffer
          end
        end
      }.new, 'UTF-8')
    
    lines = page_data.force_encoding("UTF-8").lines
    while parser.document.page.nil?
      parser << lines.next
    end
    parser.finish

    return parser.document.page
  end
  
end

puts WikiDB.new.query("Haruhi")
# puts WikiCloth::Parser.new({
#     :data => parser.document.page }).to_html
