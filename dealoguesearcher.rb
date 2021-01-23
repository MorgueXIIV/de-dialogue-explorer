require "rubygems"
require 'sqlite3'
require 'pry'
require "colorize"

class DialogueEntry
	def initialize(convoID,lineID)
		dialogueArray=$db.execute "SELECT id,title,dialoguetext,actor,conversant,conversationid,isgroup,hascheck,sequence,hasalts,conditionstring,userscript FROM dentries WHERE conversationid='#{convoID}' AND id='#{lineID}'";
		dialogueArray=dialogueArray.first
		@id=dialogueArray[0]
		@title=dialogueArray[1]
		@dialoguetext=dialogueArray[2]

		@actorid=dialogueArray[3]
		actorname=$db.execute "SELECT name FROM actors WHERE id='#{@actorid}'";
		@actor=actorname[0][0]

		@conversantid=dialogueArray[4]
		actorname=$db.execute "SELECT name FROM actors WHERE id='#{@conversantid}'";
		@conversant=actorname[0][0]

		@conversationid=dialogueArray[5]
		@isgroup=dialogueArray[6]
		@hascheck=dialogueArray[7]
		@sequence=dialogueArray[8]
		@hasalts=dialogueArray[9]
		@conditionstring=dialogueArray[10]
		@userscript=dialogueArray[11]

    end

    def getParents()
    	idsArray=$db.execute"SELECT originconversationid, origindialogueid FROM dlinks WHERE destinationconversationid='#{@conversationid}' AND destinationdialogueid='#{@id}'";
    	parentsList=[]
    	idsArray.each do |idPair|
    		parentsList.push(DialogueEntry.new(idPair[0],idPair[1]))
    	end
    	@parents=parentsList
    	return parentsList
    end

    def getChildren()
    	idsArray=$db.execute"SELECT destinationconversationid, destinationdialogueid FROM dlinks WHERE originconversationid='#{@conversationid}' AND origindialogueid='#{@id}'";
		childsList=[]
		idsArray.each do |idPair|
			childsList.push(DialogueEntry.new(idPair[0],idPair[1]))
		end
		@children=childsList
		return childsList
	end


	def to_s(lomg=false)
		if @dialoguetext=="0" then
			stringV = "#{@actor}: #{@title}".colorize(:cyan)
		else
			stringV = "#{@actor}:".light_blue.bold+" #{@dialoguetext}"
		end

		if lomg
			stringV.concat("/#{@condition}/#{@userscript}/#{@sequence}")
		end

		return stringV
	end

	def myStory(lomg=true)
		story=""
		story+= (@actor==0 ? "this is a hub " : "#{@actor} says #{@dialoguetext} to #{@conversant}")
		if lomg
			story+= @conditionstring.length>1 ? " if #{@conditionstring}" : " unconditionally" 
			story+= @userscript.length>1 ? " and causing #{@userscript}" : " with no action"
			story += @sequence.length>1 ? " and showing #{@sequence}" : " normally"
		end
		return story
	end

	def getConvoID()
		return @conversationid
	end


end


class DialogueExplorer
	def initialize()
		@nowLine=nil
		@lineCollection=Array.new()
		@nowOptions=Array.new()
		@nowJob=""
		choiceprocess()
		output()
	end

	def optionsAvail?()
		if (@nowOptions.nil? or @nowOptions.empty?)
			return false
		else
			return true
		end
	end

	def output()
		puts "Thank You For Using the".colorize(:light_green) + " FAYDE Playback Experiment!".colorize(:yellow)
		@lineCollection.each do |line|
			puts line.to_s
		end
	end

	def lineSelected?()
		# TODO refactor to use a method that returns true if it's a dialogue line that I'll add to that class
		return !(@nowLine.nil?)
	end

	def choiceprocess()
		if (optionsAvail?)
			puts "choose a number: ".light_red
			@nowOptions.each_with_index { |dia,i| puts "#{i+1}: ".light_red.underline + dia.to_s(true) } 
			puts "Or change to:"
		end

		if lineSelected?()
			puts " (n)ext lines, (p)revious lines, \n view (c)onversation info, (d)ump entire conversation,".light_red
		end
		puts  "(s)earch for a new line (q)uit (d)ump based on ID".light_red
		choice = gets.chomp
		case choice
		when "q"
			self.output
		when "n"
			self.nextlines
		when "p"
			self.prevlines
		when "c"
			self.conversationinfo
		when "d"
			self.dialoguedump
		when "s"
			self.searchlines
			choiceprocess
		else
			optionnum=(choice.to_i)-1
			if optionsAvail? then
				if @nowOptions[optionnum].nil? then
					"option selected out of range, try again"
					choiceprocess()
				else
					@nowLine=@nowOptions[optionnum]
					@nowOptions=[]
					choiceprocess
				end
			end
		end
		return optionnum
	end

	def dialoguedump()
		if @nowLine.nil?
			puts "What conversation is this?"
			convoID=gets.chomp.to_i
		else
			convoID=@nowLine.getConvoID
		end
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}'"
		searchDias.each do |lineArray|
			if lineArray[1]=="0" && lineArray.length>4 then
				puts "#{lineArray[0]}: #{lineArray[4]}".colorize(:cyan)
			else
				puts "#{lineArray[0]}:".light_blue.bold+" #{lineArray[1]}"
			end
		end
	end 


	def searchlines()
		#receive text input from command line, remove " and 's with GSUB"
		puts "Enter search query:"
		searchQ=gets.chomp
		searchQ.gsub!("'", "_")
		searchQ.gsub!('"', "_")
				#us SQL query to get the actor name, and dialogue text from two joined tables, when they partial match the provided input string.
				#todo refactor ot only return IDs
		searchDias=$db.execute "SELECT conversationid,id FROM dentries WHERE dentries.dialoguetext LIKE '%#{searchQ}%'";
		#iterates over array of results, outputing the name and then dialogue
		@nowOptions=[]
		searchDias.each {|dia| @nowOptions.push(DialogueEntry.new(dia[0],dia[1]))}
		choiceprocess()
	end

	def nextlines()
		@currentJob="next"

		if lineSelected? then
			@lineCollection.push(@nowLine)
			puts @nowLine.to_s
			@nowOptions=@nowLine.getChildren()
			@nowLine=nil
		end

		if optionsAvail?
			if @nowOptions.length==1
				@nowLine = @nowOptions[0]
				nextlines()
			else
				puts "choose a line (type number) ".light_red
				choiceprocess()
			end
		end

	end
end

# id,title,dialoguetext,actor,conversant,conversationid,isgroup,hascheck,sequence,hasalts,conditionstring,userscript

def findParentLineIDs(db,convoID,lineID)
	idsArray=db.execute"SELECT originconversationid, origindialogueid FROM dlinks WHERE destinationconversationid='#{convoID}' AND destinationdialogueid='#{lineID}'";
	return idsArray;
end

def findChildLineIDs(db,convoID,lineID)
	idsArray=db.execute"SELECT destinationconversationid, destinationdialogueid FROM dlinks WHERE originconversationid='#{convoID}' AND origindialogueid='#{lineID}'";
	return idsArray;
end

def getLineByIDs(db,convoID,lineID)
	dialogueArray=db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conversationid, dentries.id, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}' AND dentries.id='#{lineID}'";
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
	if lineArray[1]=="0" && lineArray.length>4 then
		return "#{lineArray[0]}: #{lineArray[4]}".colorize(:cyan)
	else
		return "#{lineArray[0]}:".light_blue.bold+" #{lineArray[1]}"
	end
end



begin
	# opens a DB file to search
	$db = SQLite3::Database.open 'test.db'
    db=$db

    ourprogram=DialogueExplorer.new()

# 	# asks user which of the searc results they "like"
# 	puts "select a line: (q to exit)"
# 	diaCollection=[];
# 	lineSelector=gets.chomp;


# 	while not lineSelector=="q" do
# 		lineSelector=(lineSelector.to_i)
# 		diaCollection.unshift(searchDias[lineSelector])
# 		# binding.pry
		
# 		firstParents=[]
# 		#finds the lines that LEAD TO that line, then prints them
# 		if searchDias.length > 0 then
# 			firstParents=findParentLineIDs(db,searchDias[lineSelector][2],searchDias[lineSelector][3]);
# 		end

# 		lineSelector=0
# 		searchDias=[]

# 		if (firstParents.nil? || firstParents.empty?) then
# 			puts "Tree Root/End here, outputting conversation, and quiting."
# 			lineSelector="q"
# 		else
# 			# searchDias=[]
# 			searchDias=(makeIDsLines(db,firstParents))

# 			if searchDias.length==1 then
# 				lineSelector="0";
# 				puts strADiaLine(searchDias[0]).colorize(:gray)
# 			elsif searchDias.length>1 then
# 				puts "select a dialogue option:".colorize(:light_red)
# 				searchDias.each_with_index do |dia, i|
# 					puts i.to_s.colorize(:light_red).underline + ": " + strADiaLine(dia)
# 				end
# 				lineSelector=gets.chomp;
# 			else
# 				"huh so I can't find the right lines sorry"
# 				lineSelector="q"
# 			end
# 		end
# 	end

# 	puts "find (n)ext lines, or (q)uit?".colorize(:light_red)
# 	lineSelector=gets.chomp;
# 	if not lineSelector=="q"
# 		searchDias=diaCollection.pop(1)
# 		lineSelector=="0"
# 	end

# 	while not lineSelector=="q" do
# 		lineSelector=lineSelector.to_i
# 		# if diaCollection.nil? then
# 		# 	diaCollection=[];
# 		# end
		
# 		diaCollection.push(searchDias[lineSelector])
# 		# binding.pry
		
# 		firstChildren=[]
# 		#finds the lines that LEAD TO that line, then prints them
# 		if searchDias.length > 0 then
# 			firstChildren=findChildLineIDs(db,searchDias[lineSelector][2],searchDias[lineSelector][3]);
# 		end

# 		lineSelector=0
# 		searchDias=[]

# 		if (firstChildren.nil? || firstChildren.empty?) then
# 			puts "Tree Root/End here, outputting conversation, and quiting."
# 			lineSelector="q"
# 		else
# 			# searchDias=[]
# 			searchDias=(makeIDsLines(db,firstChildren))


# 			if searchDias.length==1 then				
# 				lineSelector="0";
# 				puts strADiaLine(searchDias[0]).colorize(:gray)
# 			elsif searchDias.length>1 then
# 				puts "select a dialogue option:".colorize(:light_red)
# 				searchDias.each_with_index {|dia, i| puts i.to_s.colorize(:light_red) + ": " + strADiaLine(dia)}
# 				lineSelector=gets.chomp;
# 			else
# 				"huh so I can't find the right lines sorry"
# 				lineSelector="q"
# 			end
# 		end
# 	end
# 	puts "Thank You For Using the".colorize(:light_green) + " FAYDE Playback Experiment!".colorize(:yellow)
# 	#ouput the lines found one dialogue has been finished
# 	diaCollection.each{|dia| puts strADiaLine(dia);}

# end

#error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end
