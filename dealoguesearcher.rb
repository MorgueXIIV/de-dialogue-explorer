require "rubygems"
require 'sqlite3'
require 'pry'
require "colorize"

class DialogueEntry
	def initialize(convoID,lineID)
		dialogueArray=$db.execute "SELECT id, title, dialoguetext, actor, conversant, conversationid,isgroup, hascheck,sequence, hasalts,conditionstring, userscript FROM dentries WHERE conversationid='#{convoID}' AND id='#{lineID}'";
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
    	if @parents.nil? or @parents.empty? then
	    	idsArray=$db.execute"SELECT originconversationid, origindialogueid FROM dlinks WHERE destinationconversationid='#{@conversationid}' AND destinationdialogueid='#{@id}'";
	    	parentsList=[]
	    	idsArray.each do |idPair|
	    		parentsList.push(DialogueEntry.new(idPair[0],idPair[1]))
	    	end
	    	@parents=parentsList
	    end
    	return @parents
    end

    def getChildren()
    	idsArray=$db.execute"SELECT destinationconversationid, destinationdialogueid FROM dlinks WHERE originconversationid='#{@conversationid}' AND origindialogueid='#{@id}'";
		childsList=[]
		idsArray.each do |idPair|
			childsList.push(DialogueEntry.new(idPair[0], idPair[1]))
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
			@nowOptions.each_with_index { |dia, i| puts "#{i+1}: ".light_red.underline + dia.to_s(true) } 
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
			exit
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
					if @currentJob=="next"
						nextlines
					elsif @currentJob=="prev"
						prevlines
					end						
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

	def conversationinfo()
		if @nowLine.nil?
			puts "Which conversation ID?"
			convoID=gets.chomp.to_i
		else
			convoID=@nowLine.getConvoID
		end
		searchDias=$db.execute "SELECT title, description FROM dialogues WHERE id='#{convoID}'"
		searchDias.each do |lineArray|
			puts "#{lineArray[0]}: #{lineArray[1]}".colorize(:cyan)
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
		elsif not @lineCollection[-1].nil? 
			@nowOptions=@lineCollection[-1].getChildren()
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


	def prevlines()
		@currentJob="prev"

		if lineSelected? then
			@lineCollection.unshift(@nowLine)
			puts @nowLine.to_s
			@nowOptions=@nowLine.getParents()
			@nowLine=nil
		elsif not @lineCollection[0].nil? 
			@nowOptions=@lineCollection[0].getParents()
		end

		if optionsAvail?
			if @nowOptions.length==1
				@nowLine = @nowOptions[0]
				prevlines()
			else
				puts "choose a line (type number) ".light_red
				choiceprocess()
			end
		end
	end

end

begin
	# opens a DB file to search
	$db = SQLite3::Database.open 'test.db'
    # db=$db

    ourprogram=DialogueExplorer.new()

#error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    $db.close if $db
end
