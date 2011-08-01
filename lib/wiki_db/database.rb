require 'nokogiri'

module WikiDb
  class Database
    def get_page title, ignore_case = false
      title = title.gsub('_', ' ')
      puts "Retrieving #{title}..."
      
      cache_result = WikiDb.cache_get(title, ignore_case)
      puts "Returning cached results for #{title}." unless cache_result.nil?
      return cache_result.dup unless cache_result.nil?
      
      results = query_for_offsets(title) || []
      puts "Found #{results.count} results."
      match = results.grep(Regexp.new("^#{Regexp.escape title} \\d+$", ignore_case)).first
      if match && match.match(/^(.*) (\d+)$/)
        page_content = get_page_at_offset($2.to_i)
        WikiDb.cache_set($1, page_content)
        return page_content
      else
        return nil
      end
    end
    
    def search query
      query_for_offsets(query).map { |r| r.match(/^(.*) \d+$/).captures.first }
    end
    
    private

    def query_for_offsets query
      return nil if WikiDb.index_file.nil?
      File.open(WikiDb.index_file, :external_encoding => "UTF-8") do |index|
        q = title_hash query
        toc_entry = WikiDb.index_toc[q]
        index.seek(toc_entry[:pos], IO::SEEK_SET)
        results = []
        query_downcase = query.downcase
        for i in (0...toc_entry[:length])
          line = index.readline # rescue break
        # while q == title_hash(line = index.readline)
          if line.downcase.start_with? query_downcase
            results << line.chomp
          else
            break if results.count > 0
          end
        end
        return results
      end
    end

    def title_hash s
      b = s[0,3].downcase.bytes.to_a
      ((b[0] || 0) << 16) + ((b[1] || 0) << 8) + (b[2] || 0)
    end

    def find_block_num offset
      low = 0
      high = WikiDb.bzip_table.count
      result = nil
      while result.nil?
        c = low + (high - low) / 2
        b = WikiDb.bzip_table[c]
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
    
    def get_block_data block_num, offset=0
      block = WikiDb.bzip_table[block_num]
      block_data = `#{WikiDb.seek_bunzip_cmd} #{block[:block_offset]} < #{WikiDb.wiki_xml_dump}`
      block_data.force_encoding("BINARY")
      if offset > 0
        offset_within_block = (offset - block[:offset])
        return block_data[offset_within_block..-1]
      else
        return block_data
      end
    end

    def get_page_at_offset offset
      block_num = find_block_num(offset)
      page_data = get_block_data(block_num, offset)

      page = nil
      parser = Nokogiri::XML::SAX::PushParser.new(Class.new(Nokogiri::XML::SAX::Document) {
          attr_reader :text
          attr_reader :title
          
          def done?
            @done || false
          end
          
          def initialize
            @texty_tags = ['text', 'title']
          end

          def start_element name, attrs = []
            @current_tag = name
            @text_buffer = '' if @texty_tags.include? name
          end

          def characters s
            @text_buffer << s if @texty_tags.include? @current_tag
          end

          def end_element name
            self.instance_variable_set("@#{name}", @text_buffer) if @texty_tags.include? name
            @done = true if name == 'page'
          end
        }.new, 'UTF-8')

      lines = page_data.force_encoding("UTF-8").lines
      until parser.document.done?
        begin
          parser << lines.next
        rescue StopIteration
          page_data = get_block_data(block_num += 1)
          lines = page_data.lines
        end
      end
      parser.finish
      
      return parser.document.text
    end
  end
end

# puts WikiDB::Database.new.search("Haruhi")
