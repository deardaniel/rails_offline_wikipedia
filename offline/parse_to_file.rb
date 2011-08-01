require 'nokogiri'
require 'bzip2'

FULL_SIZE = 29131775005

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

    interval = 25000
    if $pages_count % interval == 0      
      stats_thread = Thread.start({ :pages_count => $pages_count, :pos => @pos, :now => Time.now, :start_time => @start_time }) do |args|
        now = args[:now]
        completion = args[:pos].to_f/FULL_SIZE.to_f
        time_taken = now - $start
        time_total = time_taken / completion
        time_left = time_total - time_taken
        time_left_h = time_left.to_i / 3600
        time_left_m = time_left.to_i / 60 - time_left_h * 60
        time_left_s = time_left.to_i % 60
      
        STDERR.puts "#{(completion * 100.0).round(3)}%", "Pages read: #{args[:pages_count]}"
        STDERR.puts "#{(interval.to_f / (now - args[:start_time])).round 2} pages/sec. #{time_left_h}h#{time_left_m}m#{time_left_s}s" if !args[:start_time].nil?
      end
      @start_time = Time.now
    end

    STDOUT.puts "#{@title.strip} #{@pos}"
  end
end

exit if ARGV.count != 1

$pages_count = 0
$pos = 0
$start = Time.now
parser = Nokogiri::XML::SAX::PushParser.new(MyDoc.new, nil, 'UTF-8')
io = Bzip2::Reader.new(File.open(ARGV[0]))
while line = io.readline
  parser << line
  $pos += line.bytesize
end
parser.finish
