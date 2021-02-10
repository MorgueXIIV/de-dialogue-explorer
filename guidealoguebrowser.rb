require 'tk'
# require 'bundler'
require 'sqlite3'

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

    def getTitle()
    	return @title
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

	def isHub?()
		if @dialoguetext=="0"
			return true
		else
			return false
		end
	end

	def getLeastHubParentName(reverse=true)
		grandparentslist=[]
		greatgrandparentslist=[]
		if self.isHub?
			getParents()
			@parents.each do |parent|
				print "."
				if not (parent.isHub?)
					return parent.getTitle
				else
					grandparentslist+=parent.getParents
				end
			end
			grandparentslist.each do |parent|
				print "."
				if not parent.isHub?
					return parent.getTitle
				else
					greatgrandparentslist+=parent.getParents
				end
			end
			greatgrandparentslist.each do |parent|
				print "."
				if not parent.isHub?
					return parent.getTitle
				else
					greatgrandparentslist+=parent.getParents
				end
			end

			# GIVE UP ?
			return false

		else
			return "(this isn't a hub)"
		end
	end
				# recurse= parent.getLeastHubParentName()
				# if recurse then 
				# 	return recurse





	def to_s(lomg=false, markdown=false)
		if markdown then
			ital = "*"
			bold = "**"
		else
			ital=""
			bold=""
		end

		lomginfo=extraInfo()
		if isHub? then
			if lomginfo.length<2 or lomginfo=="Continue()"
				lomginfo=@title
			end
			lomginfo+= "(#{getLeastHubParentName})"
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
			hardness=@difficultypass+0
			lomgpossinfo.unshift("passive #{@actor} check, (difficulty #{hardness}-ish)")
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

	def lineFromArray(arrayOfInfo, lomg, markdown)
		if markdown then
			italic="*"
			bold="**"
		else
			italic=""
			bold=""
		end

		actor=arrayOfInfo[0]
		dialoguetext=arrayOfInfo[1]
		conditionstring=arrayOfInfo[2]
		userscript=arrayOfInfo[3]
		sequence=arrayOfInfo[4]
		difficultypass=arrayOfInfo[5]
		title=arrayOfInfo[6]

		lomginfo=""
		if lomg or dialoguetext.length<3 then
			lomgpossinfo=[conditionstring,userscript,sequence]
			lomgpossinfo.reject!{|info| info.nil? or info.length<2 }

			if difficultypass>0 then
				hardness=difficultypass+0
				lomgpossinfo.unshift("passive #{actor} check, (difficulty #{hardness}-ish)")
			end
			lomginfo=lomgpossinfo.join(": ")
		end
		if dialoguetext.length<3
			dialoguetext=title
		end
		strline="#{bold}#{actor}:#{bold} #{dialoguetext}"
		if lomginfo.length>3
			strline+="\n\t#{italic}#{lomginfo}#{italic}"
		end
		return strline
	end

	def dialoguedump(lomg=false, removehubs=false, markdown=false)
		if lineSelected?
			convoID=@nowLine.getConvoID
		elsif collectionStarted
			convoID=@lineCollection[0].getConvoID
		else
			return false			
		end 

		dumpStr=""
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conditionstring, dentries.userscript, dentries.sequence, dentries.difficultypass, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}'"

		searchDias.each do |line|
			if not (removehubs and line[1].length<3) then
				dumpStr+=lineFromArray(line,lomg,markdown)+"\n"
			end
		end
		return dumpStr
	end

	def actorDump(actorID,lomg=false, removehubs=false, markdown=false)

		dumpStr=""
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conditionstring, dentries.userscript, dentries.sequence, dentries.difficultypass, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.actor='#{actorID}'"

		searchDias.each do |line|
			if not (removehubs and line[1].length<3) then
				dumpStr+=lineFromArray(line,lomg,markdown)+"\n"
			end
		end
		return dumpStr
	end 


	def conversationinfo()
		if lineSelected?
			convoID=@nowLine.getConvoID
		elsif collectionStarted
			convoID=@lineCollection[0].getConvoID
		else
			return false			
		end
		searchDias=$db.execute "SELECT title, description FROM dialogues WHERE id='#{convoID}'"
		searchDias.each do |lineArray|
			return "#{lineArray[0]}: #{lineArray[1]}"
			# .colorize(:cyan)
		end
	end 

	def searchlines(searchQ=nil, actorlimit=0,byphrase=true, some=false)

		#  remove " and 's with GSUB"
		searchQ.gsub!("'", "_")
		searchQ.gsub!('"', "_")
		maxsearch=0
		#us SQL query to get the line IDs when they partial match the provided input string.
		if searchQ.strip.length==0 then
			query="SELECT conversationid,id FROM dentries"
			query+="and actor='#{actorlimit.to_i}'"
		else
			if byphrase then
				query= "SELECT conversationid,id FROM dentries WHERE dentries.dialoguetext LIKE '%#{searchQ}%'"
			else
				searchwords=searchQ.split(" ")
				if searchwords.length>0 and searchwords.length<20 then
					searchwords.reject!{|e| e.length<3}
					query="SELECT conversationid,id FROM dentries WHERE "
					searchwords.map! { |e| "(dentries.dialoguetext LIKE'%#{e}%')"}
					boolop = some ? " or " : " and "
					query.concat(searchwords.join(boolop))
				else
					query= "SELECT conversationid,id FROM dentries WHERE dentries.dialoguetext LIKE '%#{searchQ}%'"
				end
			end

			if actorlimit.to_i>0
				query+="and actor='#{actorlimit.to_i}'"
			end
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
	end
end


class GUIllaume
	def initialize()
		@actorlimit=0
		@root = TkRoot.new { title "FAYDE Playback Experiment" }
		# @root.iconbitmap('FAYDE-PbEx.ico')
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
		
		@pageLAST = TkFrame.new(@note)
		@note.add @pageLAST, :text => 'Display Options', :state =>'normal'

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
		@actorStr.value=""
		TkLabel.new(@searchEntry) {text 'only said by:'}.grid( :column => 4, :row => 1, :sticky => 'w')
		@searchnametextbox=TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @actorStr)
		@searchnametextbox.grid( :column =>4, :columnspan=>2, :row => 2, :sticky => 'we' )
		actorfind= proc{getNames}
		actorfinde= proc{getNames(true)}
		actorlose= proc{ungetNames}
		actordump= proc{actorDump}
		@searchnametextbox.bind('Key', actorfind)
		@searchnametextbox.bind('Return', actorfinde)
		@searchnametextbox.bind('FocusOut', actorfinde)
		@actorClear=TkButton.new(@searchEntry, "text"=> "Any Actor", "command"=> actorlose, "state"=>'disabled').grid( :column => 5, :row => 3, :sticky => 'sewn')

		@actorDump=TkButton.new(@searchEntry, "text"=> 'Actor Dump', "command"=> actordump, "state"=>"disabled").grid( :column => 5, :row => 4, :sticky => 'sewn')

		@searchstyle = TkVariable.new
		@searchstyle.value="all"
		TkRadioButton.new(@searchEntry, "text" => 'exact phrase', "variable" => @searchstyle, "value" => 'phrase').grid( :column => 1, :row => 3, :sticky=>"e")
		TkRadioButton.new(@searchEntry, "text" => 'all words', "variable" => @searchstyle, "value" => 'all').grid( :column => 2, :row => 3, :sticky=>"ew")
		TkRadioButton.new(@searchEntry, "text" => 'any words', "variable" => @searchstyle, "value" => 'any').grid( :column => 3, :row => 3, :sticky=>"w")
		# TkRadioButton.new(@searchEntry, "text" => 'all by Actor:', "variable" => @searchstyle, "value" => 'person', "state"=>"disabled").grid( :column => 3, :row => 3, :sticky=>"w")



		@selectedLine = TkVariable.new
		@resultsCount = TkVariable.new
		@selectedLine.value="Select a Line To View More Details Here"
		TkLabel.new(@searchEntry, "textvariable" => @selectedLine,"wraplength"=>600, "height"=>5).grid( :column => 1, :columnspan=>5, :row => 5, :sticky=>"nsew");

		TkGrid.columnconfigure @searchEntry, 1,:weight => 1
		TkGrid.rowconfigure @searchEntry, 4, :weight => 1



		TkLabel.new(@searchEntry) {text 'found;'}.grid( :column => 1, :row => 4, :sticky => 'e')
		TkLabel.new(@searchEntry, "textvariable" => @resultsCount).grid( :column => 2, :row => 4, :sticky => 'e');
		TkLabel.new(@searchEntry) {text 'Dialogue Lines'}.grid( :column => 3, :row => 4, :sticky => 'w')

		@resultsBox = TkFrame.new(@page1).grid(:column=>0,:row=>5,:sticky => 'sewn')
		TkGrid.columnconfigure @page1, 0, :weight => 1
		TkGrid.rowconfigure @page1, 5, :weight => 2

		TkGrid.columnconfigure @resultsBox, 1, :weight => 1
		TkGrid.rowconfigure @resultsBox, 1, :weight => 1

		begintrace=proc{traceLine}
		@traceButton = TkButton.new(@resultsBox, "text"=> 'trace line ', "command"=> begintrace, "state"=>"disabled", "wraplength"=>300).grid( :column => 1, :row => 4, :sticky => 'we')
		begindump=proc{dumpLine}
		@dumpButton = TkButton.new(@resultsBox, "text"=> 'dump conversation ', "command"=> begindump, "state"=>"disabled", "wraplength"=>300).grid( :column => 1, :row => 5, :sticky => 'we')

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

		@forwButtonArea = TkText.new(@underButtonFrame) {width 40; height 2; wrap "word"}
		@forwButtonArea.grid(:column => 0, :row => 1, :sticky => 'nwes')
		TkGrid.columnconfigure(@underButtonFrame, 0, :weight => 1)
		TkGrid.rowconfigure @underButtonFrame, 1, :weight => 1

		fbys = TkScrollbar.new(@underButtonFrame) {orient 'vertical'}
		fbys.grid( :column => 1, :row => 0, :sticky => 'ns')

		@forwButtonArea['yscrollcommand'] = proc{|*args| fbys.set(*args);}
		fbys.command proc{|*args| @forwButtonArea.yview(*args);}

		@overButtonFrame = TkFrame.new(@page2)
		@overButtonFrame.grid(:column=>3,:row=>1, :sticky=>"sewn" )

		@backButtonArea = TkText.new(@overButtonFrame) {width 40; height 2; wrap "word"}
		@backButtonArea.grid(:column => 0, :row => 0, :sticky => 'nwes')
		TkGrid.columnconfigure(@overButtonFrame, 0, :weight => 1)
		TkGrid.rowconfigure @overButtonFrame, 0, :weight => 1

		bbys = TkScrollbar.new(@overButtonFrame) {orient 'vertical'}
		bbys.grid( :column => 1, :row => 0, :sticky => 'ns')

		@backButtonArea['yscrollcommand'] = proc{|*args| bbys.set(*args);}
		bbys.command proc{|*args| @backButtonArea.yview(*args);}

		TkGrid.columnconfigure @page2, 3, :weight => 1

		TkGrid.rowconfigure @page2, 3, :weight => 3
		TkGrid.rowconfigure @page2, 1, :weight => 1
		TkGrid.rowconfigure @page2, 5, :weight => 1

		upda=proc{updateConversation}

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
		@convoDesc=TkVariable.new()

		@dumpDisplayArea = TkFrame.new(@page3)
		@dumpDisplayArea.grid(:column=>3, :row=>3, :sticky=>"sewn" )
		TkGrid.columnconfigure @page3, 3, :weight => 1
		TkGrid.rowconfigure @page3, 3, :weight => 1

		TkLabel.new(@dumpDisplayArea, "textvariable" => @convoDesc,"wraplength"=>500).grid( :column => 0, :row => 1, :sticky => 'ew');

		@dumpTextBox = TkText.new(@dumpDisplayArea) {width 40; height 10; wrap "word"}
		@dumpTextBox.grid(:column => 0, :row => 3, :sticky => 'nwes')
		TkGrid.columnconfigure(@dumpDisplayArea, 0, :weight => 1)
		TkGrid.rowconfigure @dumpDisplayArea, 3, :weight => 1

		yds = TkScrollbar.new(@dumpDisplayArea) {orient 'vertical'}
		yds.grid( :column => 1, :row => 3, :sticky => 'ns')

		@dumpTextBox['yscrollcommand'] = proc{|*args| yds.set(*args);}
		yds.command proc{|*args| @dumpTextBox.yview(*args);}

		selectall=proc{@dumpTextBox.tag_add('sel', 1.0, 'end');@dumpTextBox.mark_set("insert","end");@dumpTextBox.see("end")}
		TkButton.new(@dumpDisplayArea, "text"=> 'Select All Text', "command"=> selectall).grid( :column => 0, :row => 5, :sticky => 'sewn')


		# PAGELAST

		@browseDisplayOptions = TkFrame.new(@pageLAST)
		@browseDisplayOptions.grid(:column=>3, :row=>0, :sticky=>"sewn" )

		# TkLabel.new(@page2, "textvariable" => @pickmeline, "wraplength"=>400).grid( :column => 1, :row => 4, :sticky => 'sw')
		@browserMarkdown = TkVariable.new
		@browserMarkdown.value = true
		browsemarkcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'add markdown?',
	    	"command" =>upda,
	    	"variable" =>@browserMarkdown,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsemarkcheckbox.grid(:row=>1, :column=>5,:sticky => 'w')

		@browserHubs = TkVariable.new
		@browserHubs.value = false 
	    browsehubscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show hubs?',
	    	"command" =>upda,
	    	"variable" =>@browserHubs,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsehubscheckbox.grid(:row=>2, :column=>5,:sticky => 'w')

	    @browserShowMore = TkVariable.new
		@browserShowMore.value = true
	    browsehubscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show details?',
	    	"command" =>upda,
	    	"variable" =>@browserShowMore,
	    	"onvalue" => true, 
	    	"offvalue" => false)
	    browsehubscheckbox.grid(:row=>3, :column=>5,:sticky => 'w')

	    @fontOption = TkVariable.new
		@fontOption.value="courier"
		loadConfigs
		dispoptions=TkLabel.new(@browseDisplayOptions, "text" => "Configuration Options", "wraplength"=>400, "font"=>@fontOption.value).grid( :column => 3,  :row => 0, :columnspan=>3, :sticky => 'w')
		fontprev=proc{dispoptions['font'] = @fontOption.value}
		TkRadioButton.new(@browseDisplayOptions, "text" => 'monospace', "variable" => @fontOption, "value" => 'courier',"command"=>fontprev).grid( :column => 3, :row => 1, :sticky=>"e")
		TkRadioButton.new(@browseDisplayOptions, "text" => 'serif', "variable" => @fontOption, "value" => 'times',"command"=>fontprev).grid( :column => 3, :row => 2, :sticky=>"e")
		TkRadioButton.new(@browseDisplayOptions, "text" => 'sansserif', "variable" => @fontOption, "value" => 'helvetica',"command"=>fontprev).grid( :column => 3, :row => 3, :sticky=>"e")
		TkButton.new(@browseDisplayOptions, "text"=> 'SAVE CONFIGS TO DB', "command"=> proc{saveConfigs}).grid( :column => 3, :row => 5, :sticky => 'sewn')


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

	def getNames(complete=false)
		if @actorStr.value.chomp(' ').length>1
			actormatches = $db.execute("Select name,id from actors where name like '%#{@actorStr.value}%'")
			if actormatches.length==1
				@actorStr.value=actormatches[0][0]
				@searchnametextbox.state="disabled"
				@actorlimit=actormatches[0][1]
				@actorClear.state="normal"
				@actorDump.state="normal"
			end
			if complete
				actormatches.each do |result|
					if @actorStr.value.chomp.casecmp(result[0])==0 then
						@actorStr.value=result[0]
						@searchnametextbox.state="disabled"
						@actorlimit=result[1]
						@actorClear.state="normal"
						@actorDump.state="normal"
					end
				end
			end
		end
	end

	def ungetNames()
		@actorStr.value=""
		@searchnametextbox.state="normal"
		@actorlimit=0
		@actorDump.state="disabled"
		@actorClear.state="disabled"
	end

	def saveConfigs()
		$db.execute "CREATE TABLE IF NOT EXISTS meta (tuple TEXT, value TEXT)"
		$db.execute "delete from meta where tuple='font';"
		$db.execute "delete from meta where tuple='markdown';"
		$db.execute "delete from meta where tuple='hubsshow';"
		$db.execute "delete from meta where tuple='detailshow';"


		$db.execute "insert into meta(tuple,value) values ('font','#{@fontOption.value}');"
		$db.execute "insert into meta(tuple,value) values ('markdown','#{@browserMarkdown.value}');"
		$db.execute "insert into meta(tuple,value) values ('hubsshow','#{@browserHubs.value}');"
		$db.execute "insert into meta(tuple,value) values ('detailshow','#{@browserShowMore.value}');"
	end

	def loadConfigs()
		configs=$db.execute "select tuple,value from meta;"
		configs.each do |config|
			case config[0]
			when 'font'
				@fontOption.value=config[1]
			when 'markdown'
				@browserMarkdown.value=config[1]
			when 'hubsshow'
				@browserHubs.value=config[1]
			when 'detailshow'
				@browserShowMore.value=config[1]
			end
		end
	end

	def printText(areatoprint, texttoprint)
		areatoprint.tag_configure('markdownbold', :font=>"#{@fontOption} 12 bold")
		areatoprint.tag_configure('markdownitalic', :font=>"#{@fontOption} 12 italic")
		areatoprint.tag_configure('markdownblank', :font=>"#{@fontOption} 12")
		# App.text.tag_configure('highlight', background='yellow' font='helvetica 14 bold', relief='raised')

		if @browserMarkdown>0
			italdelim="*"
			bolddelim="**"
		else
			italdelim=""
			bolddelim=""
		end
		convoarr=texttoprint.split("\n")
		convoarr.each do |line|
			boldies=line.split("\*\*")
			boldies.each_with_index do |bold,i|
				if not i.even? then
					areatoprint.insert("end", "#{bolddelim}#{bold}#{bolddelim}", "markdownbold")
				else
					itals= bold.split("\*")
					itals.each_with_index do |ital, j|
						if not j.even? then
							areatoprint.insert("end", "#{italdelim}#{ital}#{italdelim}", "markdownitalic")
						else
							areatoprint.insert("end", ital, "markdownblank")
						end
					end
				end
			end
			areatoprint.insert("end", "\n")
		end
	end


	def updateConversation()
		@convoArea['state'] = :normal

		@convoArea.delete(1.0, 'end')

		convo=@explorer.outputLineCollectionStr(@browserShowMore>0,@browserHubs<1,@browserMarkdown>0)
		printText(@convoArea,convo)
	end

	def dumpLine()
		# @page3["state"]=:normal
		@note.select(2)
		@dumpTextBox.delete(1.0, 'end')
		dump= @explorer.dialoguedump(@browserShowMore>0,@browserHubs<1,true)
		@convoDesc.value=@explorer.conversationinfo

		printText(@dumpTextBox,dump)
	end

	def actorDump()
		# @page3["state"]=:normal
		@note.select(2)
		@dumpTextBox.delete(1.0, 'end')
		dump= @explorer.actorDump(@actorlimit,@browserShowMore>0,@browserHubs<1,true)

		printText(@dumpTextBox,dump)
	end

	def traceLine()
		# @page2["state"]=:normal
		@backButtonArea.state="normal"
		@forwButtonArea.state="normal"
		@note.select(1)
		numberofbuttonstostack=5
		buttonwidth=250

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

			@chbuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectForwTraceOpt(i);traceLine;@convoArea.see("end")} }
			optionsStrs.each_with_index do |par, i|
				@childButtons.push(TkButton.new(@forwButtonArea, "text"=> par, "command" => @chbuttoncommands[i], "wraplength"=>buttonwidth))
				TkTextWindow.new(@forwButtonArea, "end", :window => @childButtons[i])
				# row=(i.div(numberofbuttonstostack))
				# col=(i%numberofbuttonstostack)
				# @childButtons[i].grid(:row =>row, :column => col, :sticky => 'sewn')
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

			@pabuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectBackTraceOpt(i);traceLine;@convoArea.see(1.0)} }
			optionsStrs.each_with_index do |par, i|
				@parentButtons.push(TkButton.new(@backButtonArea, "text"=> par, "command" => @pabuttoncommands[i], "wraplength"=>buttonwidth))
				TkTextWindow.new(@backButtonArea, "end", :window => @parentButtons[i])
				# row=i.div(numberofbuttonstostack)
				# col=(i%numberofbuttonstostack)
				# @parentButtons[i].grid(:row =>row, :column => col, :sticky => 'sewn')
			end
			@backButtonArea.state="disabled"
			@forwButtonArea.state="disabled"

				# ADD BACK BUTTONS
				@parentButtons.push(TkButton.new(@overButtonFrame, "text"=> "Undo last backward step", "command" => proc{@explorer.removeLine(true);traceLine;@convoArea.see(1.0)}, "wraplength"=>buttonwidth))
				i=@parentButtons.length
				row=i.div(numberofbuttonstostack)+1

				@parentButtons.last.grid(:row =>2, :column => 0, :sticky => 'sewn', :columnspan=>numberofbuttonstostack)

				@childButtons.push(TkButton.new(@underButtonFrame, "text"=> "Undo last forward step", "command" => proc{@explorer.removeLine(false);traceLine;@convoArea.see("end")}, "wraplength"=>buttonwidth))
				i=@childButtons.length
				row=i.div(numberofbuttonstostack)+1

				@childButtons.last.grid(:row =>0, :column => 0, :sticky => 'sewn', :columnspan=>numberofbuttonstostack)
			updateConversation

		end
	end



	def makeSearchResults()
		@searchlistbox.state="normal"
		searchStr=@searchStr.value
		searchResults=""

		case @searchstyle
		when "phrase"
			@searchByPhrase=true
			@searchAnyWord=false

		when "all"
			@searchByPhrase=false
			@searchAnyWord=false
		when "any"
			@searchByPhrase=false
			@searchAnyWord=true
		else
			@searchByPhrase=false
			@searchAnyWord=false
		end

		@lineSearch=@explorer.searchlines(searchStr,@actorlimit,@searchByPhrase, @searchAnyWord)
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

