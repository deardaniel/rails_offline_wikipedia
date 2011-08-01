require 'nokogiri'
require 'bzip2'
require 'sqlite3'

puts "Loading database."

$db = SQLite3::Database.new( "wiki.db" )
create_query = <<SQL
    create table if not exists pages (
      title text,
      pos integer
    );
    
    create index if not exists idx_title on pages (title);
SQL

$db.execute_batch(create_query)

puts "Counting pages."
$skip = $db.get_first_value( "select count(*) from pages" )
puts "Skipping first #{$skip} pages." if $skip > 0

FULL_SIZE = 53223693756

class MyDoc < Nokogiri::XML::SAX::Document
  def start_element name, attrs = []
    @inTitleTag = false
    case name
    when "page"
      @pos = $pos
    when "title"
      @inTitleTag = true
      @title = ''
    end
  end

  def characters string
    @title += string if @inTitleTag
  end

  def end_element name
    return unless name == 'page'
    
    $pages_count += 1
    return if $pages_count < $skip

    @batch ||= []
    
    interval = 25000
    if $pages_count % interval == 0
      if @batch.count > 0
        puts "Adding #{@batch.count} entries to DB."
        sql_thread = Thread.start(@batch) do |batch|
          $db.execute('begin transaction')
          $db.prepare('insert into pages (title, pos) values (?, ?)') do |s|
            batch.each do |p|
              begin
                s.execute p[:title], p[:pos]
              rescue
                p p
                p $!
              end
            end
          end
          $db.execute('end transaction')
        end
        @batch = []
      end
      
      stats_thread = Thread.start({ :pages_count => $pages_count, :pos => @pos, :now => Time.now, :start_time => @start_time }) do |args|
        now = args[:now]
        completion = args[:pos].to_f/FULL_SIZE.to_f
        time_taken = now - $start
        time_total = time_taken / completion
        time_left = time_total - time_taken
        time_left_h = time_left.to_i / 3600
        time_left_m = time_left.to_i / 60 - time_left_h * 60
        time_left_s = time_left.to_i % 60
      
        puts "#{(completion * 100.0).round(3)}%", "Pages read: #{args[:pages_count]}"
        puts "#{(interval.to_f / (now - args[:start_time])).round 2} pages/sec. #{time_left_h}h#{time_left_m}m#{time_left_s}s" if !args[:start_time].nil?
      end
      # stats_thread.priority = -2
      @start_time = Time.now
    end

    @batch << { :title => @title.strip, :pos => @pos }
  end
end

def save_results
  puts "INTERRUPTED!"
#  p $db.get_first_value( "select count(*) from pages" )
end

trap("INT") {
  save_results
  exit
}

$pages_count = 0
$pages = []
$pos = 0
$start = Time.now
parser = Nokogiri::XML::SAX::PushParser.new(MyDoc.new, nil, 'UTF-8')
io = Bzip2::Reader.new(File.open('/Users/daniel/enwiki-latest-pages-articles.xml.bz2'))
while line = io.readline
  parser << line
  $pos += line.length
end
parser.finish

# save_results()