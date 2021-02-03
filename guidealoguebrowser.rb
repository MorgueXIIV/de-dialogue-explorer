require 'tk'

# require "rubygems"
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
		if actorname[0].nil? then
			@actor=@actorid
		else
			@actor=actorname[0][0]
		end

		@conversantid=dialogueArray[4]
		actorname=$db.execute "SELECT name FROM actors WHERE id='#{@conversantid}'";
		if actorname[0].nil? then
			@conversant=@conversantid
		else
			@conversant=actorname[0][0]
		end
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
	    	idsArray=$db.execute"SELECT originconversationid/., origindialogueid FROM dlinks WHERE destinationconversationid='#{@conversationid}' AND destinationdialogueid='#{@id}'";
	    	parentsList=[]
	    	idsArray.each do |idPair|
	    		parentsList.push(DialogueEntry.new(idPair[0],idPair[1]))
	    	end
	    	@parents=parentsList
    	end
    	return @parents
    end

    def getChildren()
    	if @children.nil? or @children.empty?
	    	idsArray=$db.execute"SELECT destinationconversationid, destinationdialogueid FROM dlinks WHERE originconversationid='#{@conversationid}' AND origindialogueid='#{@id}'";
			childsList=[]
			idsArray.each do |idPair|
				childsList.push(DialogueEntry.new(idPair[0], idPair[1]))
			end
			@children=childsList
		end
		return @children
	end


	def to_s(lomg=false)
		if @dialoguetext=="0" then
			stringV = "#{@actor}: #{@title}"
			#.colorize(:cyan)
		else
			stringV = "#{@actor}: #{@dialoguetext}"
			# .light_blue.bold+
		end

		if lomg
			stringV.concat("\n/#{@condition}/#{@userscript}/#{@sequence}")
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
			# self.output
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

	def searchlines(searchQ=nil)
		if searchQ.nil? or searchQ.length<3
			#receive text input from command line, remove " and 's with GSUB"
			puts "Enter search query: (over 3 chars)"
			searchQ=gets.chomp
		end
		searchQ.gsub!("'", "_")
		searchQ.gsub!('"', "_")
				#us SQL query to get the line IDs when they partial match the provided input string.
		searchDias=$db.execute "SELECT conversationid,id FROM dentries WHERE dentries.dialoguetext LIKE '%#{searchQ}%' limit 100";
		#iterates over array of results, getting objects based on their id
		@nowOptions=[]
		searchDias.each {|dia| @nowOptions.push(DialogueEntry.new(dia[0],dia[1]))}
		return @nowOptions;
	end

	def nextlines()
		@currentJob="next"

		if lineSelected? then			@lineCollection.push(@nowLine)
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
			end
		end
	end

end


class GUIllaume
	def initialize()
		@root = TkRoot.new { title "FAYDE Playback Experiment" }
		# @notepan = TkNotebook.new(@root)
		# @p1 = TkFrame.new(@notepan); # first page, which would get widgets gridded into it
		# @p2 = TkFrame.new(@notepan); # second page
		# @notepan.add(p1, :text => 'One')
		# @notepan.add(p2, :text => 'Two')

		@explorer=DialogueExplorer.new()

		@content = TkFrame.new(@root).grid(:sticky => 'new')

		ph = { 'padx' => 10, 'pady' => 10 } 

		sear= proc {makeSearchResults}
		TkGrid.columnconfigure @root, 0, :weight => 1; TkGrid.rowconfigure @root, 0, :weight => 1

		@searchStr = TkVariable.new;
		@searchStr.value="tiptop"
		@searchBox = TkEntry.new(@content, 'width'=> 30, 'textvariable' => @searchStr).grid( :column => 1, :row => 2, :sticky => 'we' )

		@searchResults = TkVariable.new
		@resultsCount = TkVariable.new
		@searchResults.value="pending"
		TkLabel.new(@content, "textvariable" => @searchResults).grid( :column => 1, :row => 4, :sticky=>"nsew");

		TkButton.new(@content, "text"=> 'search', "command"=> sear).grid( :column => 3, :row => 2, :sticky => 'w')

		TkLabel.new(@content) {text 'search for;'}.grid( :column => 1, :row => 1, :sticky => 'e')
		TkLabel.new(@content) {text 'we found;'}.grid( :column => 1, :row => 3, :sticky => 'e')
		TkLabel.new(@content, "textvariable" => @resultsCount).grid( :column => 2, :row => 3, :sticky => 'e');
		TkLabel.new(@content) {text 'Dialogue Lines'}.grid( :column => 3, :row => 3, :sticky => 'w')

		@resultsBox = TkFrame.new(@root, "width"=>200, "height"=>600).grid(:sticky => 'new')

		sel= proc{lineSelect}
		@searchlistbox = TkListbox.new(@resultsBox) do
			listvariable @searchlist
			width 20
			height 15
			setgrid 1
			selectmode 'browse'
			pack('fill' => 'x')
		end

		@searchlistbox.place('height' => 200,
           'width'  => 300,
           'x'      => 10,
           'y'      => 10)

		scroll = TkScrollbar.new(@resultsBox) do
		   orient 'vertical'
		   place('height' => 200, 'x' => 310, 'y'=>10)
		end



		@searchlistbox.bind('ButtonRelease-1', sel)


		@searchlistbox.yscrollcommand(proc { |*args|
		   scroll.set(*args)
		})

		scroll.command(proc { |*args|
		   @searchlistbox.yview(*args)
		}) 
	end

	def lineSelect()
		selected=@searchlistbox.curselection
		if selected.length>0
			selected=selected[0]
			@nowLine=@lineSearch[selected]
		# @lineSearch[@lineSelect.value.to_i]
		# @resultsCount.value=@lineSelect
		end

		# stringLine=
		@searchResults.value="selected: "+ @nowLine.to_s(true)
		# TkLabel.new(@content, "textvariable" => stringLine).grid( :column => 1, :row => 4, :sticky => 'e')
	end

	def traceLine() 

	end



	def makeSearchResults()
		searchStr=@searchStr.value
		searchResults=""
		@lineSearch=@explorer.searchlines(searchStr)
		@resultsCount.value=@lineSearch.length
		# @lineSelect=TkVariable.new

		itemsinbox=@searchlistbox.size

		if itemsinbox>0 then
			# @searchlistbox.destroy()
			for i in 1..@searchlistbox.size do
				@searchlistbox.delete(0)
			end
		end


		@searchlist=TkVariable.new(@lineSearch)

		# @searchlist.value=@lineSearch


		@lineSearch.each{|result| @searchlistbox.insert "end", result}
		# puts @searchlist.value.to_s

		# @lineSearch.each_with_index do |result, i|
		# 	@searchRadio[i]=TkRadioButton.new(@resultsBox, "text" => result.to_s(true).slice(0,250), "variable" => @lineSelect, "value" =>i, "command"=>sel).grid( :column => 1, :row => i+1, :sticky=>"w")


		# trace the line?? Does nothing now

		begintrace=proc{traceLine}
		TkButton.new(@content, "text"=> 'trace line', "command"=> begintrace).grid( :column => 3, :row => 4, :sticky => 'w')
		# @searchResults.value=searchResults
		# return searchResults
	end

end


begin
	# opens a DB file to search
	$db = SQLite3::Database.open 'test.db'
    GUIllaume.new()
	
	Tk.mainloop

    # commenting out because creating this is now handled in the GUI for scope reasons
    # ourprogram=DialogueExplorer.new()

# #error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    $db.close if $db
end

