require "rubygems"
require 'sqlite3'

def findParentLineIDs(db,convoID,lineID)
	idsArray=db.execute"SELECT originconversationid, origindialogueid FROM dlinks WHERE destinationconversationid='#{convoID}' AND destinationdialogueid='#{lineID}'";
	return idsArray;
end

def getLineByIDs(db,convoID,lineID)
	dialogueArray=db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}' AND dentries.id='#{lineID}'";
	return dialogueArray;
end

#receive text input from command line
puts "Enter search query:"
searchQ=gets.chomp

begin
	# opens a DB file to search
	db = SQLite3::Database.open 'test.db'

	#us SQL query to get the actor name, and dialogue text from two joined tables, when they partial match the provided input string.
	dialogueArray=db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.dialoguetext LIKE '%#{searchQ}%'";
	#iterates over array of results, outputing the name and then dialogue
	dialogueArray.each_with_index do |dia,i| 
		puts i.to_s+": "+dia[0]+": "+dia[1];
	end
# asks user which of the searc results they "like"
	puts "select a line: "
	lineSelector=gets.chomp.to_i
	puts dialogueArray[lineSelector].to_s

#finds the lines that LEAD TO that line, then prints them
	firstParents=findParentLineIDs(db,dialogueArray[lineSelector][2],dialogueArray[lineSelector][3]);

	firstParents.each_with_index do |dia,i|
		myline=getLineByIDs(db,dia[0],dia[1])
		puts i.to_s+": " + myline[0][0]+": " + myline[0][1]
	end

#error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end
