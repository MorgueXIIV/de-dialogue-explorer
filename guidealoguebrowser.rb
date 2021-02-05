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
		# # @notepan.add(p2, :text => 'Two')
		# @root['minsize'] = 50, 50
		# @root['maxsize'] = 70, 70

		@explorer=DialogueExplorer.new()

		@note = Tk::Tile::Notebook.new(@root) do
	   		height 610
	   		width 600
	   		# place('height' => 600, 'width' => 600, 'x' => 10, 'y' => 10)
		end		
		@page1 = TkFrame.new(@note)
		@page2 = TkFrame.new(@note)
		f3 = TkFrame.new(@note)		
		@note.add @page1, :text => 'Search'
		@note.add @page2, :text => 'Browse'
		@note.add f3, :text => 'To be determined', :state =>'disabled'
		@note.grid(:sticky => 'news')

		@searchEntry = TkFrame.new(@page1).grid(:sticky => 'new')

		ph = { 'padx' => 10, 'pady' => 10 } 

		sear= proc {makeSearchResults}
		TkGrid.columnconfigure @root, 0, :weight => 1; TkGrid.rowconfigure @root, 0, :weight => 1

		@searchStr = TkVariable.new;
		@searchStr.value="tiptop"
		TkLabel.new(@searchEntry) {text 'search for;'}.grid( :column => 1, :row => 1, :sticky => 'e')
		TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @searchStr).grid( :column => 1, :row => 2, :columnspan=>2, :sticky => 'wes' )
		TkButton.new(@searchEntry, "text"=> 'search', "command"=> sear).grid( :column => 3, :row => 2, :sticky => 'w')

		@selectedLine = TkVariable.new
		@resultsCount = TkVariable.new
		@selectedLine.value="Select a Line To View More Details Here"
		TkLabel.new(@searchEntry, "textvariable" => @selectedLine,"wraplength"=>400, "height"=>5).grid( :column => 1, :columnspan=>3, :row => 4, :sticky=>"nsw");

		begintrace=proc{traceLine}
		@traceButton = TkButton.new(@searchEntry, "text"=> 'trace   line ', "command"=> begintrace, "state"=>"disabled", "wraplength"=>50).grid( :column => 4, :row => 4, :sticky => 'w')

		TkLabel.new(@searchEntry) {text 'we found;'}.grid( :column => 1, :row => 3, :sticky => 'e')
		TkLabel.new(@searchEntry, "textvariable" => @resultsCount).grid( :column => 2, :row => 3, :sticky => 'e');
		TkLabel.new(@searchEntry) {text 'Dialogue Lines'}.grid( :column => 3, :row => 3, :sticky => 'w')

		@resultsBox = TkFrame.new(@page1).grid(:sticky => 'sew')

		sel= proc{lineSelect}
		@searchlistbox = TkListbox.new(@resultsBox) do
			listvariable @searchlist
			width 20
			height 10
			setgrid 1
			selectmode 'browse'
			state "disabled"
			# pack('fill' => 'x')
		end

		# @searchlistbox.place('height' => 200,'width'  => 300, 'x'=> 10,'y'=> 10)
		@searchlistbox.grid(:column=>1, :row => 1, :sticky => "sewn", :columnspan => 3)

		scroll = TkScrollbar.new(@resultsBox) do
		   orient 'vertical'
		   # place('height' => 200, 'x' => 310, 'y'=>10)
		end
		scroll.grid(:column=>5, :row => 1, :sticky => "news")

		@searchlistbox.bind('ButtonRelease-1', sel)

		@searchlistbox.yscrollcommand(proc { |*args|
		   scroll.set(*args)
		})

		scroll.command(proc { |*args|
		   @searchlistbox.yview(*args)
		}) 

		# PAGE 2:

		@childsstring=TkVariable.new
		@parentsstring=TkVariable.new
		# @pickmeline=TkVariable.new
		TkLabel.new(@page2, "textvariable" => @parentsstring, "wraplength"=>400).grid( :column => 1, :row => 1, :sticky => 'nw')
		TkLabel.new(@page2, "textvariable" => @selectedLine, "wraplength"=>400).grid( :column => 1, :row => 3, :sticky => 'w')
		TkLabel.new(@page2, "textvariable" => @childsstring, "wraplength"=>400).grid( :column => 1, :row => 5, :sticky => 'sw')
		# TkLabel.new(@page2, "textvariable" => @pickmeline, "wraplength"=>400).grid( :column => 1, :row => 4, :sticky => 'sw')
	end

	def lineSelect()
		selected=@searchlistbox.curselection
		if selected.length>0
			selected=selected[0]
			@nowLine=@lineSearch[selected]
			@selectedLine.value="selected: "+ @nowLine.to_s(true)
			@traceButton.state="active"
		end
	end

	def traceLine() 
		@note.select(1)
		if not @nowLine.nil?
			setchild=proc{@childsstring.value=@nowLine.getChildren[0].to_s}

			children=@nowLine.getChildren()
			puts children.length

			if @childrenButtons.nil? or @childrenButtons.empty? then
				@childrenButtons=Array.new()
			else
				@childrenButtons.each do |butter| 
					butter.destroy()
				end
				@childrenButtons=Array.new()
				@chbuttoncommands=[]
			end

			@chbuttoncommands=Array.new(children.length) { |i| proc{@childsstring.value=@nowLine.getChildren[i].to_s} }
			children.each_with_index do |par, i|
				@childrenButtons.push(TkButton.new(@page2, "text"=> par.to_s(true), "command" => @chbuttoncommands[i],"wraplength"=>100))
				@childrenButtons[i].grid(:row =>4, :column => i, :sticky => 'ns')
			end

			parents=@nowLine.getParents()
			parentsstring=""
			parents.each do |par|
				parentsstring+=par.to_s(true)+"\n"
			end

			@parentsstring.value=parentsstring
			@childsstring.value=""


		end
	end



	def makeSearchResults()
		@searchlistbox.state="normal"
		searchStr=@searchStr.value
		searchResults=""
		@lineSearch=@explorer.searchlines(searchStr)
		@resultsCount.value=@lineSearch.length

		itemsinbox=@searchlistbox.size

		if itemsinbox>0 then
			@searchlistbox.delete(0, :end)
		end

		@lineSearch.each{|result| @searchlistbox.insert "end", result}

		# @lineSearch.each_with_index do |result, i|
		# 	@searchRadio[i]=TkRadioButton.new(@resultsBox, "text" => result.to_s(true).slice(0,250), "variable" => @lineSelect, "value" =>i, "command"=>sel).grid( :column => 1, :row => i+1, :sticky=>"w")



		# @selectedLine.value=searchResults
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

