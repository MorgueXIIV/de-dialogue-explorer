require "rubygems"
require 'sqlite3'
require 'pry'

def findParentLineIDs(db,convoID,lineID)
	idsArray=db.execute"SELECT originconversationid, origindialogueid FROM dlinks WHERE destinationconversationid='#{convoID}' AND destinationdialogueid='#{lineID}'";
	return idsArray;
end

def getLineByIDs(db,convoID,lineID)
	dialogueArray=db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}' AND dentries.id='#{lineID}'";
	return dialogueArray;
end

def makeIDsLines(db,lineIDs)
	arrayOfLines=[]
	lineIDs.each do |aLineID|
		arrayOfLines.concat(getLineByIDs(db, aLineID[0],aLineID[1]));
	end
	return arrayOfLines;
end

def strADiaLine(lineArray)
	return "#{lineArray[0]}: #{lineArray[1]}"
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
	searchDias.each_with_index{|dia,i| puts i.to_s+": "+ strADiaLine(dia)}
	# asks user which of the searc results they "like"
	puts "select a line: (q to exit)"
	diaCollection=[];
	lineSelector=gets.chomp;

	while not lineSelector=="q" do
		lineSelector=lineSelector.to_i
		diaCollection.unshift(searchDias[lineSelector])
		# binding.pry
		
		firstParents=[]
		#finds the lines that LEAD TO that line, then prints them
		if searchDias.length > 0 then
			firstParents=findParentLineIDs(db,searchDias[lineSelector][2],searchDias[lineSelector][3]);
		end

		lineSelector=0
		searchDias=[]

		if (firstParents.nil? || firstParents.empty?) then
			puts "Tree Root/End here, outputting conversation, and quiting."
			lineSelector="q"
		else
			# searchDias=[]
			searchDias=(makeIDsLines(db,firstParents))

			searchDias.each_with_index do |dia, i|
				puts i.to_s + ": " + strADiaLine(dia)
			end

			if searchDias.length==1 then
				lineSelector="0";
			elsif searchDias.length>1 then
				puts "select a dialogue option:"
				lineSelector=gets.chomp;
			else
				"huh so I can't find the right lines sorry"
				lineSelector="q"
			end
		end

		# if firstParents.length==1 then
		# 	searchDias=getLineByIDs(db,firstParents[0][0],firstParents[0][1])
		# 	puts searchDias[0][0]+": " + searchDias[0][1]
		# 	lineSelector=0;
		# elsif firstParents.length>0 then
		# 	firstParents.each_with_index do |dia,i|
		# 		searchDias.concat(getLineByIDs(db,dia[0],dia[1]))
		# 			puts i.to_s+": " + searchDias[i][0]+": " + searchDias[i][1]
		# 	end
		# else 
		#  	puts "No more results.";
		#  	lineSelector="q"
		# end
		# if lineSelector==-1
		# 	puts "select a line: (q to exit)"
		# 	lineSelector=gets.chomp
		# end
	end

	#ouput the lines found one dialogue has been finished
	diaCollection.each{|dia| puts dia[0] + ": " + dia[1];}

#error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end
