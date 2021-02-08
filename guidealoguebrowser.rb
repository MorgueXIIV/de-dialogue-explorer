require 'tk'

# require "rubygems"
require 'sqlite3'
require 'pry'
require "colorize"

class DialogueEntry
	def initialize(convoID,lineID)
		dialogueArray=$db.execute "SELECT id, title, dialoguetext, actor, conversant, conversationid,isgroup, hascheck,sequence, hasalts,conditionstring, userscript, difficultypass FROM dentries WHERE conversationid='#{convoID}' AND id='#{lineID}'";
		dialogueArray.flatten!
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
		@difficultypass=dialogueArray[12]

    end

    def getParents()
    	if @parents.nil? then
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
    	if @children.nil? then
	    	idsArray=$db.execute"SELECT destinationconversationid, destinationdialogueid FROM dlinks WHERE originconversationid='#{@conversationid}' AND origindialogueid='#{@id}'";
			childsList=[]
			idsArray.each do |idPair|
				childsList.push(DialogueEntry.new(idPair[0], idPair[1]))
			end
			@children=childsList
		end
		return @children
	end


	def to_s(lomg=false, markdown=false)
		if markdown then
			ital = "*"
			bold = "**"
		else
			ital=""
			bold=""
		end

		lomginfo=extraInfo()
		if @dialoguetext=="0" then
			if lomginfo.length<2 or lomginfo=="Continue()"
				lomginfo=@title
			end
			stringV = "\t#{ital}HUB: #{lomginfo}#{ital}"
			#.colorize(:cyan)
		else
			stringV = "#{bold}#{@actor}:#{bold} #{@dialoguetext}"
			# ".light_blue.bold+"
			if lomg and lomginfo.length > 1
				stringV.concat("\n\t#{ital}#{lomginfo}#{ital}")
			end
		end

		return stringV
	end

	def extraInfo()
		lomgpossinfo=[@conditionstring,@userscript,@sequence]
		lomgpossinfo.reject!{|info| info.nil? or info.length<2 }

		if @difficultypass>0 then
			hardness=@difficultypass+3
			lomgpossinfo.unshift("If #{@actor} better than #{hardness}")
		end

		lomginfo=lomgpossinfo.join(": ")
		return lomginfo
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
		@searchOptions=Array.new()
		@nowJob=""
	end

	def optionsAvail?()
		if (@nowOptions.nil? or @nowOptions.empty?)
			return false
		else
			return true
		end
	end

	def outputLineCollectionStr(lomg=false, removehubs=false, markdown=false)
		lineCollStr = @lineCollection.map { |e| e.to_s(lomg, markdown) }
			if removehubs then
				lineCollStr.select! {|e| (e["HUB"]).nil?}
			end
		lineCollStr = lineCollStr.join("\n")
		# @lineCollection.each do |line|
		# 	lineCollStr.concat(line.to_s(lomg) + "\n")
		# end
		return lineCollStr
	end


	def outputLineCollectionArr()
		lineCollArr=[]
		@lineCollection.each do |line|
			lineCollArr.push(line)
		end
		return lineCollArr
	end

	def getCurrentLineStr(lomg=false)
		return @nowLine.to_s(lomg)
	end

	def getSearchOptStrs(lomg=false)
		# @searchOptions.flatten!
		countOpts=@searchOptions.length
		if countOpts>0 then
			optStrs=Array.new(countOpts) { |i| @searchOptions[i].to_s }
		else
			optStrs=[]
		end
		return optStrs
	end


	def getForwardOptStrs(lomg=false)
		countOpts=@forwOptions.length
		if countOpts>0 then
			optStrs=Array.new(countOpts) { |i| @forwOptions[i].to_s(lomg) }
		else
			optStrs=[]
		end
		return optStrs
	end

	def getBackwardOptStrs(lomg=false)
		countOpts=@backOptions.length
		if countOpts>0 then
			optStrs=Array.new(countOpts) { |i| @backOptions[i].to_s(lomg) }
		else
			optStrs=[]
		end
		return optStrs
	end

	def lineSelected?()
		# TODO refactor to use a method that returns true if it's a dialogue line that I'll add to that class
		return !(@nowLine.nil?)
	end

	def collectionStarted()
		if @lineCollection.empty? or @lineCollection.nil? then
			return false
		else
			return true
		end
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

	# TODO refactor to RETURN not print the dump
	def dialoguedump()
		if lineSelected?
			convoID=@nowLine.getConvoID
		elsif collectionStarted
			convoID=@lineCollection[0].getConvoID
		else
			return false			
		end 
		dumpStr=""
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conditionstring, dentries.userscript, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}'"
		searchDias.each do |lineArray|
			if lineArray[1]=="0" && lineArray.length>4 then
				dumpStr.concat("#{lineArray[0]}: #{lineArray[4]}\n")
			else
				dumpStr.concat("#{lineArray[0]}: #{lineArray[1]}\n")
			end
			bonusinfo=lineArray[2]+" : " +lineArray[3]
			if bonusinfo.length>5
				dumpStr.concat("\t #{bonusinfo} \n")
			end
		end
		return dumpStr
	end 

	# refactor to RETURN not output
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

	def searchlines(searchQ=nil, actorlimit=false)
		if searchQ.nil? or searchQ.length<3
			#receive text input from command line,
			puts "Enter search query: (over 3 chars)"
			searchQ=gets.chomp
		end
		#  remove " and 's with GSUB"
		searchQ.gsub!("'", "_")
		searchQ.gsub!('"', "_")
		maxsearch=0
		#us SQL query to get the line IDs when they partial match the provided input string.
		query= "SELECT conversationid,id FROM dentries WHERE dentries.dialoguetext LIKE '%#{searchQ}%'"
		if actorlimit.to_i>0
			query+="and actor='#{actorlimit}'"
		end
		if maxsearch<0
			query+="limit #{maxsearch}"
		end
		searchDias=$db.execute query
		#iterates over array of results, getting objects based on their id
		@searchOptions=[]
		searchDias.each do |dia|
			@searchOptions.push(DialogueEntry.new(dia[0],dia[1]))
		end
		optionsStrs=getSearchOptStrs
		return optionsStrs
	end

	def selectSearchOption(optToSelect)
		selOpt=@searchOptions[optToSelect]
		if selOpt.nil?
			return false
		else
			@lineCollection=[]
			@lineCollection.push(selOpt)
		end
		return selOpt.to_s(true)
	end

	def selectForwTraceOpt(optToSelect)
		selOpt=@forwOptions[optToSelect]
		if selOpt.nil?
			return false
		else
			@lineCollection.push(selOpt)
			return @lineCollection.last.to_s(true)
		end
	end

	def selectBackTraceOpt(optToSelect)
		selOpt=@backOptions[optToSelect]
		if selOpt.nil?
			return false
		else
			@lineCollection.unshift(selOpt)
			return @lineCollection.last.to_s(true)
		end
	end

	def removeLine(backw=false)
		ret=[]
		if backw then
			loop do
				if @lineCollection.length>1 then
					ret.push(@lineCollection.shift)
				else
					break
				end
				# this is tricky, it's more efficient in tersm of DB queries to see that the first line only had one parent (already queried while the list was made originally, rather than check the children of the popped line... which I think would add another db execution.
				break if @lineCollection.first.getParents.length>1
			end
		else
			loop do
				if @lineCollection.length>1 then
					ret.unshift(@lineCollection.pop)
				else
					break
				end
				break if @lineCollection.last.getChildren.length>1
			end
		end

		traceBackOrForth(backw)
		return ret
	end


	def traceBackOrForth(backw=false)
		if collectionStarted then
			if backw then
				lineToWorkOn = @lineCollection.first
				# @lineCollection.unshift(lineToAdd)
				nowOptions=lineToWorkOn.getParents()
			else
				lineToWorkOn = @lineCollection.last
				# @lineCollection.push(lineToAdd)
				nowOptions=lineToWorkOn.getChildren()
			end
		else
			raise "No Starting Point In Line Collection."
		end

		if nowOptions.length==1
			if backw then
				@lineCollection.unshift(nowOptions[0])
			else
				@lineCollection.push(nowOptions[0])
			end
			traceBackOrForth(backw)
		elsif backw
			@backOptions=nowOptions
		else 
			@forwOptions=nowOptions
		end
	end

	def traceBackAndForth()
		traceBackOrForth(true)
		traceBackOrForth(false)

	# 	if @lineCollection.empty? or @lineCollection.nil? then
	# 		raise "No Starting Point In Line Collection."
	# 	else
	# 		lineToWorkOn = @lineCollection.first
	# 		# @lineCollection.unshift(lineToAdd)
	# 		nowOptions=lineToAdd.getParents()
	# 		if nowOptions.length==1	then
	# 			@lineCollection.unshift(nowOptions[0])
	# 			traceBackOrForth(true)
	# 		else
	# 			@backOptions=nowOptions
	# 		end
	# 		lineToWorkOn = @lineCollection.last
	# 		# @lineCollection.push(lineToAdd)
	# 		nowOptions=lineToAdd.getChildren()
	# 		if nowOptions.length==1
	# 			@lineCollection.push(nowOptions[0])
	# 			traceBackOrForth(false)
	# 		else
	# 			@forwOptions=nowOptions
	# 		end
	# 	end
	end
end


class GUIllaume
	def initialize()
		@actorlimit=0
		@root = TkRoot.new { title "FAYDE Playback Experiment" }
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
		@page3 = TkFrame.new(@note)		
		@note.add @page1, :text => 'Search'
		@note.add @page2, :text => 'Browse', :state=>"normal"
		@note.add @page3, :text => 'Dialogue Dump', :state =>'normal'
		@note.grid(:row=>0,:column=>0,:sticky => 'news')

		@searchEntry = TkFrame.new(@page1).grid(:sticky => 'new')

		ph = { 'padx' => 10, 'pady' => 10 } 


		TkGrid.columnconfigure @root, 0, :weight => 1
		TkGrid.rowconfigure @root, 0, :weight => 1

		@searchStr = TkVariable.new;
		@searchStr.value="tiptop"
		TkLabel.new(@searchEntry) {text 'search for:'}.grid( :column => 1, :row => 1, :sticky => 'w')
		searchtextbox=TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @searchStr).grid( :column => 1, :row => 2, :columnspan=>2, :sticky => 'wnes' )
		sear= proc {makeSearchResults}
		searchtextbox.bind('Return', proc {makeSearchResults})
		TkButton.new(@searchEntry, "text"=> 'search', "command"=> sear).grid( :column => 3, :row => 2, :sticky => 'w')

		@actorStr = TkVariable.new;
		@actorStr.value="kim"
		TkLabel.new(@searchEntry) {text 'only said by:'}.grid( :column => 4, :row => 1, :sticky => 'w')
		@searchnametextbox=TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @actorStr)
		@searchnametextbox.grid( :column =>4, :columnspan=>2, :row => 2, :sticky => 'we' )
		actorfind= proc{getNames}
		actorlose= proc{ungetNames}
		@searchnametextbox.bind('Key', actorfind)
		TkButton.new(@searchEntry, "text"=> 'clear', "command"=> actorlose).grid( :column => 5, :row => 3, :sticky => 'sewn')


		@selectedLine = TkVariable.new
		@resultsCount = TkVariable.new
		@selectedLine.value="Select a Line To View More Details Here"
		TkLabel.new(@searchEntry, "textvariable" => @selectedLine,"wraplength"=>400, "height"=>5).grid( :column => 1, :columnspan=>3, :row => 4, :sticky=>"nsew");

		TkGrid.columnconfigure @searchEntry, 1,:weight => 1
		TkGrid.rowconfigure @searchEntry, 4, :weight => 1

		begintrace=proc{traceLine}
		@traceButton = TkButton.new(@searchEntry, "text"=> 'trace   line ', "command"=> begintrace, "state"=>"disabled", "wraplength"=>50).grid( :column => 4, :row => 4, :sticky => 'we')
		begindump=proc{dumpLine}
		@dumpButton = TkButton.new(@searchEntry, "text"=> 'dump   convo ', "command"=> begindump, "state"=>"disabled", "wraplength"=>50).grid( :column => 5, :row => 4, :sticky => 'we')

		TkLabel.new(@searchEntry) {text 'we found;'}.grid( :column => 1, :row => 3, :sticky => 'e')
		TkLabel.new(@searchEntry, "textvariable" => @resultsCount).grid( :column => 2, :row => 3, :sticky => 'e');
		TkLabel.new(@searchEntry) {text 'Dialogue Lines'}.grid( :column => 3, :row => 3, :sticky => 'w')

		@resultsBox = TkFrame.new(@page1).grid(:column=>0,:row=>5,:sticky => 'sewn')
		TkGrid.columnconfigure @page1, 0, :weight => 1
		TkGrid.rowconfigure @page1, 5, :weight => 2

		TkGrid.columnconfigure @resultsBox, 1, :weight => 1
		TkGrid.rowconfigure @resultsBox, 1, :weight => 1

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
		@searchlistbox.grid(:column=>1, :row => 1, :sticky => "sewn")

		@searchlistbox.bind('ButtonRelease-1', sel)
		@searchlistbox.bind('Return', sel)


		scroll = TkScrollbar.new(@resultsBox) do
		   orient 'vertical'
		end
		scroll.grid(:column=>2, :row => 1, :sticky => "ns")

		@searchlistbox.yscrollcommand(proc { |*args|
		   scroll.set(*args)
		})

		scroll.command(proc { |*args|
		   @searchlistbox.yview(*args)
		}) 

		scrollx = TkScrollbar.new(@resultsBox) do
		   orient 'horizontal'
		end
		scrollx.grid(:column=>1, :row => 2, :sticky => "ew")

		@searchlistbox.xscrollcommand(proc { |*args|
		   scrollx.set(*args)
		})

		scrollx.command(proc { |*args|
		   @searchlistbox.xview(*args)
		}) 

		# PAGE 2:

		@convoDisplayArea = TkFrame.new(@page2)
		@convoDisplayArea.grid(:column=>3, :row=>3, :sticky=>"sewn" )

		@underButtonFrame = TkFrame.new(@page2)
		@underButtonFrame.grid(:column=>3,:row=>5, :sticky=>"sewn" )

		@overButtonFrame = TkFrame.new(@page2)
		@overButtonFrame.grid(:column=>3,:row=>1, :sticky=>"sewn" )


		@browseDisplayOptions = TkFrame.new(@page2)
		@browseDisplayOptions.grid(:column=>3, :row=>0, :sticky=>"sewn" )


		TkGrid.columnconfigure @page2, 3, :weight => 1
		TkGrid.rowconfigure @page2, 3, :weight => 1

		upda=proc{updateConversation}

		TkLabel.new(@browseDisplayOptions, "textvariable" => @selectedLine, "wraplength"=>400).grid( :column => 3,  :row => 1, :rowspan=>3, :sticky => 'w')
		# TkLabel.new(@page2, "textvariable" => @pickmeline, "wraplength"=>400).grid( :column => 1, :row => 4, :sticky => 'sw')
		@browserMarkdown = TkVariable.new
		@browserMarkdown.value = false 
		browsemarkcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'add markdown?',
	    	"command" =>upda,
	    	"variable" =>@browserMarkdown,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsemarkcheckbox.grid(:row=>1, :column=>5)

		@browserHubs = TkVariable.new
		@browserHubs.value = false 
	    browsehubscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show hubs?',
	    	"command" =>upda,
	    	"variable" =>@browserHubs,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsehubscheckbox.grid(:row=>2, :column=>5)

	    @browserShowMore = TkVariable.new
		@browserShowMore.value = true
	    browsehubscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show details?',
	    	"command" =>upda,
	    	"variable" =>@browserShowMore,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsehubscheckbox.grid(:row=>3, :column=>5)



		@convoArea = TkText.new(@convoDisplayArea) {width 40; height 10; wrap "word"}
		@convoArea.grid(:column => 0, :row => 0, :sticky => 'nwes')
		TkGrid.columnconfigure(@convoDisplayArea, 0, :weight => 1)
		TkGrid.rowconfigure @convoDisplayArea, 0, :weight => 1

		ys = TkScrollbar.new(@convoDisplayArea) {orient 'vertical'}
		ys.grid( :column => 1, :row => 0, :sticky => 'ns')

		@convoArea['yscrollcommand'] = proc{|*args| ys.set(*args);}
		ys.command proc{|*args| @convoArea.yview(*args);}
		@convoArea.insert('end', "Conversation Will Display Here When Tracing Begins ")

		# xs = Tk::Tile::Scrollbar.new(@convoDisplayArea) {orient 'horizontal'; command proc{|*args| @convoArea.xview(*args);}}
		# @convoArea['xscrollcommand'] = proc{|*args| xs.set(*args);}
		# xs.grid( :column => 0, :row => 1, :sticky => 'we')

		# TkGrid.columnconfigure(@convoDisplayArea, 2, :weight => 1)
		TkGrid.rowconfigure(@page2, 3, :weight => 1)




		# PAGE 3:

		@dumpDisplayArea = TkFrame.new(@page3)
		@dumpDisplayArea.grid(:column=>3, :row=>3, :sticky=>"sewn" )
		TkGrid.columnconfigure @page3, 3, :weight => 1
		TkGrid.rowconfigure @page3, 3, :weight => 1

		@dumpTextBox = TkText.new(@dumpDisplayArea) {width 40; height 10; wrap "word"}
		@dumpTextBox.grid(:column => 0, :row => 0, :sticky => 'nwes')
		TkGrid.columnconfigure(@dumpDisplayArea, 0, :weight => 1)
		TkGrid.rowconfigure @dumpDisplayArea, 0, :weight => 1

		yds = TkScrollbar.new(@dumpDisplayArea) {orient 'vertical'}
		yds.grid( :column => 1, :row => 0, :sticky => 'ns')

		@dumpTextBox['yscrollcommand'] = proc{|*args| yds.set(*args);}
		yds.command proc{|*args| @dumpTextBox.yview(*args);}
		@convoArea.insert('end', "Dump Will Display Here ")
	end

	def lineSelect()
		selected=@searchlistbox.curselection
		if selected.length>0
			selected=selected[0]
			selectedStr=@explorer.selectSearchOption(selected)
			@selectedLine.value="selected: #{selectedStr}"
			@traceButton.state="active"
			@dumpButton.state="active"
		end
	end

	def getNames()
		if @actorStr.value.chomp(' ').length>2
			puts @actorStr.value
			actormatches = $db.execute("Select name,id from actors where name like '%#{@actorStr.value}%'")
			if actormatches.length==1
				@actorStr.value=actormatches[0][0]
				@searchnametextbox.state="disabled"
				@actorlimit=actormatches[0][1]
			end
		end
	end

	def ungetNames()
		@actorStr.value=""
		@searchnametextbox.state="normal"
		@actorlimit=0

	end


	def updateConversation()
		@convoArea['state'] = :normal
		convo=@explorer.outputLineCollectionStr(@browserShowMore>0,@browserHubs<1,@browserMarkdown>0)

		@convoArea.delete(1.0, 'end')
		@convoArea.insert(1.0, convo)

		# convo.each do |line|
		# 	@convoArea.insert("end", line)
		# end
	end

	def dumpLine()
		# @page3["state"]=:normal
		@note.select(2)
		@dumpTextBox.delete(1.0, 'end')
		dump= @explorer.dialoguedump
		@dumpTextBox.insert(1.0, dump)
	end

	def traceLine()
		# @page2["state"]=:normal
		@note.select(1)
		numberofbuttonstostack=5
		if @explorer.collectionStarted
			@explorer.traceBackOrForth(false)
			optionsStrs=@explorer.getForwardOptStrs

			if @childButtons.nil? or @childButtons.empty? then
				@childButtons=[]
			else
				@childButtons.each do |butter|
					butter.destroy()
				end
				@childButtons=[]
				@chbuttoncommands=[]
			end

			@chbuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectForwTraceOpt(i);traceLine} }
			optionsStrs.each_with_index do |par, i|
				@childButtons.push(TkButton.new(@underButtonFrame, "text"=> par, "command" => @chbuttoncommands[i], "wraplength"=>100))
				row=(i.div(numberofbuttonstostack))
				col=(i%numberofbuttonstostack)

				@childButtons[i].grid(:row =>row, :column => col, :sticky => 'sewn')
			end



			@explorer.traceBackOrForth(true)
			optionsStrs=@explorer.getBackwardOptStrs

			if not(@parentButtons.nil? or @parentButtons.empty?) then
				@parentButtons.each do |butter|
					butter.destroy()
				end
			end		

			@parentButtons=[]
			@pabuttoncommands=[]

			@pabuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectBackTraceOpt(i);traceLine} }
			optionsStrs.each_with_index do |par, i|
				@parentButtons.push(TkButton.new(@overButtonFrame, "text"=> par, "command" => @pabuttoncommands[i], "wraplength"=>100))
				row=i.div(numberofbuttonstostack)
				col=(i%numberofbuttonstostack)

				@parentButtons[i].grid(:row =>row, :column => col, :sticky => 'sewn')
			end

				# ADD BACK BUTTONS
				@parentButtons.push(TkButton.new(@overButtonFrame, "text"=> "backstep", "command" => proc{@explorer.removeLine(true);traceLine}, "wraplength"=>100))
				i=@parentButtons.length
				row=i.div(numberofbuttonstostack)+1

				@parentButtons.last.grid(:row =>row, :column => 0, :sticky => 'sewn', :columnspan=>numberofbuttonstostack)

				@childButtons.push(TkButton.new(@underButtonFrame, "text"=> "backstep", "command" => proc{@explorer.removeLine(false);traceLine}, "wraplength"=>100))
				i=@childButtons.length
				row=i.div(numberofbuttonstostack)+1

				@childButtons.last.grid(:row =>row, :column => 0, :sticky => 'sewn', :columnspan=>numberofbuttonstostack)
			updateConversation

		end
	end



	def makeSearchResults()
		@searchlistbox.state="normal"
		searchStr=@searchStr.value
		searchResults=""
		@lineSearch=@explorer.searchlines(searchStr,@actorlimit)
		@resultsCount.value=@lineSearch.length

		itemsinbox=@searchlistbox.size

		if itemsinbox>0 then
			@searchlistbox.delete(0, :end)
		end

		@lineSearch.each{|result| @searchlistbox.insert "end", result}
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

