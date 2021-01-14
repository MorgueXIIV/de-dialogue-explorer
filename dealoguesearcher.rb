require "rubygems"
require 'sqlite3'

puts "Enter search query:"
searchQ=gets.chomp

begin
	# opens a DB file, Creates our database tables	
	db = SQLite3::Database.open 'test.db'


	dialogueArray=db.execute "SELECT actors.name, dentries.dialoguetext FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.dialoguetext LIKE '%#{searchQ}%'";
	dialogueArray.each do |dia| 
		puts dia[0]+": "+dia[1];
	end

rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end
