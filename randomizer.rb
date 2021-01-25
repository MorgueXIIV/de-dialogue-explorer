require 'csv'

table = CSV.parse(File.read("sample.csv"), headers: true)

lineNumber=0
categoryNumber=0

# CSV.foreach("ford_escort.csv") do |readout|
# 	lineNumber+=1
# 	puts lineNumber.to_s + ' ' + readout[0].to_s
# end
# table.headers.each do
# 	puts (categoryNumber+1).to_s + ' ' + table[categoryNumber][0].to_s
# 	categoryNumber+=1
# end

table.headers.each do
	puts (lineNumber+1).to_s + ' ' + table.headers[lineNumber]
	lineNumber+=1
end

puts "Select a line:"
colSelect=gets.chomp.to_i
colLength = (table.by_col[colSelect-1]).length

puts table[colSelect-1][rand(colLength)]