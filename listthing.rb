require 'csv'

table = CSV.parse(File.read("ford_escort.csv"), headers: true)

lineNumber=0

CSV.foreach("ford_escort.csv") do |readout|
	lineNumber+=1
	puts lineNumber.to_s + ' ' + readout[0].to_s
end
puts "Select a line:"
rowSelect=gets.chomp.to_i

puts table[rowSelect-1][rand(2)]