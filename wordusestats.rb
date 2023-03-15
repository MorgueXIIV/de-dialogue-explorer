require 'sqlite3'
puts "Reading lines"
lines_data = File.read("wordusestatsseedtext.txt").split("\n")
lines_data.map!{ |e| e.downcase }

puts "counting words:"
wordcount = Hash.new
lines_data.each_with_index do |line,idx|
	#reasurance dot every 1000 lines
	print "." if ((idx%1000) == 0)
	words = line.split(/[^[[:word:]]]+/) # line.split(/'?[!\/\[\]()? *".,-]+'?/)
	words.each do |word|
		wordcount[word]= (wordcount.fetch(word, 0)) + 1
	end
end

puts "\ncreate DB:"
db = SQLite3::Database.open "wordusedisco5.db"
db.execute """CREATE TABLE IF NOT EXISTS words
	(word TEXT PRIMARY KEY, length INT, frequency INT)""";

puts "start transaction, write data"
db.transaction
	wordcount.each_pair do |key,value|
		db.execute "INSERT INTO words (word, length, frequency) values (?,?,?)", [key,key.length,value]
	end
db.commit

puts "done!"

# puts "creating array"
# arrayofinfo=[]
# wordcount.each_pair do |key,value|
# 	arrayofinfo.push(["#{key},#{key.length},#{value}"])
# end



# puts "Writing file"
# File.write("wordStats.csv", arrayofinfo.join("\n"))
# puts "done!"
		# if wordcount.has_key?(word)
		# 	wordcount[word]++
		# else

