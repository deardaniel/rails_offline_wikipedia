exit if ARGV.count != 1


index = {}
pos = 0
total = 9891051
File.open(ARGV[0]) do |f|
  f.each do |line|
  	b = line[0,3].downcase.bytes.to_a
  	index[((b[0] || 0) << 16) + ((b[1] || 0) << 8) + (b[2] || 0)] ||= { :pos => pos, :length => 0 }
  	index[((b[0] || 0) << 16) + ((b[1] || 0) << 8) + (b[2] || 0)][:length]  += 1
  	pos += line.bytesize
  	STDERR.puts(((f.lineno.to_f / total.to_f) * 100.0).round(3)) if f.lineno % 50000 == 0
	end
end

puts Marshal.dump(index)

# exit if ARGV.count != 1
# 
# index = {}
# pos = 0
# total = 9891051
# File.open(ARGV[0]) do |f|
#   f.each do |line|
#     b = line[0,4].downcase.force_encoding('BINARY').bytes.to_a
#     index[((b[0] || 0) << 24) + ((b[1] || 0) << 16) + (b[2] || 0)] ||= pos
#     # index[line[0,4].downcase.force_encoding('BINARY')[0,4]] ||= pos
#     pos += line.bytesize
#     STDERR.puts ((f.lineno.to_f / total.to_f) * 100.0).round(3) if f.lineno % 50000 == 0
#   end
# end
# 
# puts Marshal.dump(index)
