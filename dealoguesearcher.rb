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
	searchDias=db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.dialoguetext LIKE '%#{searchQ}%'";
	#iterates over array of results, outputing the name and then dialogue
	searchDias.each_with_index{|dia,i| puts i.to_s+": "+dia[0]+": "+dia[1];}
	# asks user which of the searc results they "like"
	puts "select a line: (q to exit)"
	diaCollection=[];
	lineSelector=gets.chomp.to_i
	while not lineSelector=="q" do
		lineSelector=lineSelector.to_i
		diaCollection.unshift(searchDias[lineSelector])

		#finds the lines that LEAD TO that line, then prints them
		firstParents=findParentLineIDs(db,searchDias[lineSelector][2],searchDias[lineSelector][3]);
		searchDias=[]
		if firstParents.length>0 then
				firstParents.each_with_index do |dia,i|
				searchDias.concat(getLineByIDs(db,dia[0],dia[1]))
				if searchDias.length>0
					puts i.to_s+": " + searchDias[i][0]+": " + searchDias[i][1]
				end
			end
		else 
		 	puts "No more results.";
		end

		puts "select a line: (q to exit)"
		lineSelector=gets.chomp
	end
	#ouput the lines found
	diaCollection.each{|dia| puts dia[0] + ": " + dia[1];}

#error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end
