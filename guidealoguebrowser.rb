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
		difficultypass=dialogueArray[12]
		@difficultypass = difficultypass>7 ? (difficultypass-7)*2-1 : difficultypass*2

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

	def getCheck()
		if not @checkDataHash.nil?
			return @checkDataHash
		elsif @hascheck>0
			check=$db.execute "SELECT isred,difficulty,flagname,forced,skilltype FROM checks WHERE conversationid='#{@conversationid}' AND dialogueid='#{@id}'"
			if check.empty? then
				@checkDataHash=false
			else
				check=check[0]
				@checkDataHash={"isred"=>check[0],"difficulty"=>check[1],"flag"=>check[2],"forced"=>check[3],"skill"=>check[4]}
			end
		else
			@checkDataHash=false
		end
		return @checkDataHash
	end

	def getModifiers()
		if @modifiers.nil? then
			if @hascheck>0
				modifiers=$db.execute "SELECT tooltip,modifier,variable FROM modifiers WHERE conversationid='#{@conversationid}' AND dialogueid='#{@id}'"
				if modifiers.empty?
					@modifiers=false
				else
					@modifiers=modifiers
				end
			end
		end
		return @modifiers
	end

	def getAlternates()
		if @alternates.nil? then
			if @hasalts>0
				alts=$db.execute "SELECT condition,alternateline FROM alternates WHERE conversationid='#{@conversationid}' AND dialogueid='#{@id}'"
				if alts.empty?
					@alternates=false
				else
					@alternates=alts
				end
			else
				@alternates=false
			end
		end
		return @alternates
	end

	def getCheckString(showModifiers=true,markdown=true)
		if markdown then
			ital = "*"
			bold = "**"
		else
			ital=""
			bold=""
		end
		check=getCheck()
		stringcheck=""
		if check then
			stringcheck="\n\t#{ital}#{check["skill"]} "
			if check['isred']>0
				stringcheck+= " RED check#{ital}"
			else
				stringcheck+= " WHITE check#{ital}"
			end
			stringcheck+="\n\t #{ital}Difficulty: #{check["difficulty"]}#{ital} \n \t#{ital}(flag: #{check["flag"]})#{ital} "
		end
		if showModifiers then
			mods=getModifiers
			if mods then
				mods.each do |mod|
					stringcheck+="\n\t\t #{ital}#{mod[1]} #{mod[0]}#{ital} \n\t\t #{ital}(#{mod[2]})#{ital} "
				end
			end
		end
		return stringcheck
	end

	def getAltStrings(markdown=true)
		if markdown then
			ital = "*"
			bold = "**"
		else
			ital=""
			bold=""
		end

		stringalts=""
		alts=getAlternates
		if alts then
			alts.each do |alt|
				stringalts+="\n\t #{ital}(replaced with:#{alt[1]}#{ital} "
				stringalts+= "\n\t #{ital}if #{alt[0]})#{ital} "
			end
		end
		return stringalts
	end


	def getLeastHubParentName(reverse=true)
		grandparentslist=[]
		greatgrandparentslist=[]
		if self.isHub?
			getParents()
			@parents.each do |parent|
				if not (parent.isHub?)
					return parent.getTitle
				else
					grandparentslist+=parent.getParents
				end
			end
			grandparentslist.each do |parent|
				if not parent.isHub?
					return parent.getTitle
				else
					greatgrandparentslist+=parent.getParents
				end
			end
			greatgrandparentslist.each do |parent|
				if not parent.isHub?
					return parent.getTitle
				else
					greatgrandparentslist+=parent.getParents
				end
			end

			# GIVE UP ?
			return "(no useful parent)"
		else
			return "(this isn't a hub)"
		end
	end

	def to_s(lomg=false, markdown=false,check=false,altshow=false)
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
			stringV = "\t#{ital}HUB: #{lomginfo}#{ital} "
			#.colorize(:cyan)
		else
			stringV = "#{bold}#{@actor}:#{bold} #{@dialoguetext}"
			# ".light_blue.bold+"
			if (lomg and lomginfo.length > 1)
				stringV.concat("\n\t#{ital}#{lomginfo}#{ital} ")
			end

			if check then
				checkinfo=getCheckString(true,markdown)
				stringV.concat("#{checkinfo} ")
			end
			if altshow then
				alts=getAltStrings(markdown)
				stringV.concat("#{alts} ")
			end
		end
		return stringV
	end

	def extraInfo()
		lomgpossinfo=[@conditionstring,@userscript,@sequence]
		lomgpossinfo.reject!{|info| info.nil? or info.length<2 }

		if @difficultypass>0 then
			hardness=@difficultypass
			lomgpossinfo.unshift("passive check (estimate; requires #{hardness} in #{@actor})")
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

	def outputLineCollectionStr(lomg=false, removehubs=false, markdown=false,showchecks=true,showalts=false)
		lineCollStr = @lineCollection.map { |e| e.to_s(lomg, markdown,showchecks,showalts) }
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
			lineCollArr.push(line.to_s)
		end
		return lineCollArr
	end

	def getCurrentLineStr(lomg=false)
		return @nowLine.to_s(lomg)
	end

	def getSearchOptStrs(lomg=false)
		if @searchOptions.nil?
			return []
		end
		optStrs=@searchOptions.map { |e| (e[4]=="ALT" ? "(ALT)" : "") + (e[3].length>3 ? "#{e[2]}: #{e[3]}" : e[4]) }
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
			if arrayOfInfo.length>=9 then
				if arrayOfInfo[7]>0 and lomg then
					lomginfo+=" (has an active check) "
				end
				if arrayOfInfo[8]>0 and lomg then
					lomginfo+=" (has alternate lines) "
				end
			end
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
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conditionstring, dentries.userscript, dentries.sequence, dentries.difficultypass, dentries.title, dentries.hascheck, dentries.hasalts FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.conversationid='#{convoID}'"

		searchDias.each do |line|
			if not (removehubs and line[1].length<3) then
				dumpStr+=lineFromArray(line,lomg,markdown)+"\n"
			end
		end
		return dumpStr
	end

	def actorDump(actorID,lomg=false, removehubs=false, markdown=false)

		dumpStr=""
		searchDias=$db.execute "SELECT actors.name, dentries.dialoguetext, dentries.conditionstring, dentries.userscript, dentries.sequence, dentries.difficultypass, dentries.title, dentries.hascheck, dentries.hasalts FROM dentries INNER JOIN actors ON dentries.actor=actors.id WHERE dentries.actor='#{actorID}'"
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

	def searchlines(searchQ=nil, actorlimit=0, searchStyle="all")

		#  remove " and 's with GSUB"
		searchQ.gsub!("'", "_")
		searchQ.gsub!('"', "_")
		maxsearch=0
		#us SQL query to get the line IDs when they partial match the provided input string.
		#for performance reasons, willl no longer get the IDs and make objects, that was INSANELY slow
		altquery="SELECT dentries.conversationid,dentries.id,actors.name, alternates.alternateline, 'ALT' FROM dentries INNER JOIN actors ON dentries.actor=actors.id left join alternates on alternates.conversationid=dentries.conversationid and alternates.dialogueid=dentries.id "
		query= "SELECT dentries.conversationid,dentries.id,actors.name, dentries.dialoguetext, dentries.title FROM dentries INNER JOIN actors ON dentries.actor=actors.id "
		if searchQ.strip.length==0 then
			query+= " where actor='#{actorlimit.to_i}'"
			altquery+= " where actor='#{actorlimit.to_i}'"
		elsif searchStyle=="variable"
			searchwords=searchQ.split(" ")
			searchwords.reject!{|e| e.length<2}
			altquery=""
			if searchwords.length>0 and searchwords.length<5 then
				searchwords.map! { |e| "(dentries.userscript LIKE '%#{e}%')"}
				boolop = " and "
				query+="WHERE (#{searchwords.join(boolop)})"
				query+="OR (#{searchwords.join(boolop).gsub("userscript","conditionstring")})"
			else
				query+= " WHERE dentries.userscript LIKE '%#{searchQ.gsub(" ","%")}%' or dentries.conditionstring LIKE '%#{searchQ.gsub(" ","%")}%'"
			end				
		elsif searchStyle=="phrase" then
			query+= " WHERE dentries.dialoguetext LIKE '%#{searchQ}%'"
			altquery+= " WHERE alternates.alternateline LIKE '%#{searchQ}%'"
		else
			searchwords=searchQ.split(" ")
			searchwords.reject!{|e| e.length<3}
			if searchwords.length>0 and searchwords.length<20 then
				corewords=searchwords.map { |e| "(dentries.dialoguetext LIKE '%#{e}%')"}
				altwords=searchwords.map { |e| "(alternates.alternateline LIKE '%#{e}%')"}
				boolop = searchStyle=="any" ? " or " : " and "
				query+="WHERE (#{corewords.join(boolop)})"
				altquery+="WHERE (#{altwords.join(boolop)})"
			else
				query+= " WHERE dentries.dialoguetext LIKE '%#{searchQ}%'"
				altquery+= " WHERE alternates.alternateline LIKE '%#{searchQ}%'"
			end
		end

		if actorlimit.to_i>0
			query+=" and actor='#{actorlimit.to_i}'"
			altquery+=" and actor='#{actorlimit.to_i}'"
		end
		if maxsearch>0
			query+="limit #{maxsearch}"
		end
		# puts query
		# puts altquery
		searchDias=$db.execute query
		if altquery.length>1
			searchDias+=$db.execute altquery
		end

		@searchOptions=searchDias

		# #iterates over array of results, getting objects based on their id
		# @searchOptions=[]
		# searchDias.each do |dia|
		# 	@searchOptions.push(DialogueEntry.new(dia[0],dia[1]))
		# end

		optionsStrs=getSearchOptStrs
		return optionsStrs
	end

	def selectSearchOption(optToSelect)
		selOpt=@searchOptions[optToSelect]
		if selOpt.nil?
			return false
		else
			@nowLine=DialogueEntry.new(selOpt[0],selOpt[1])
			@lineCollection=[]
			@lineCollection.push(@nowLine)
		end
		return @nowLine.to_s(true)
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
	    @versionInfo = TkVariable.new($versionNumber)
		TkLabel.new("textvariable"=>@versionInfo).grid(:row=>10,:column=>0,:sticky => 'news')


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
		@note.add @page2, :text => 'Browse', :state=>'disabled'
		@note.add @page3, :text => 'Dialogue Dump', :state =>'disabled'
		
		@pageLAST = TkFrame.new(@note)
		@note.add @pageLAST, :text => 'Display Options', :state =>'normal'

		@note.grid(:row=>0,:column=>0,:sticky => 'news')

		loadConfigs
		checkDatabase

		TkGrid.columnconfigure @root, 0, :weight => 1
		TkGrid.rowconfigure @root, 0, :weight => 1
		buildConfigPage
		buildSearcherPage
		buildBrowserPage
		buildDumpPage
	end

	def buildSearcherPage()

		@searchEntry = TkFrame.new(@page1).grid(:sticky => 'new')
		@searchStr = TkVariable.new;
		@searchStr.value="tiptop"
		TkLabel.new(@searchEntry) {text 'Search dialogue text for:'; font "TkHeadingFont"}.grid( :column => 1, :columnspan =>2,:row => 1, :sticky => 'w')

		searchtextbox=TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @searchStr).grid( :column => 1, :row => 2, :columnspan=>2, :sticky => 'wnes' )
		sear= proc {makeSearchResults}
		searchtextbox.bind('Return', sear)
		TkButton.new(@searchEntry, "text"=> 'search', "command"=> sear).grid( :column => 4, :row => 2, :rowspan => 2, :sticky => 'sewn')

		@actorStr = TkVariable.new;
		@actorStr.value=""
		TkLabel.new(@searchEntry) {text 'only said by:'}.grid( :column => 1, :row => 3, :sticky => 'w')
		@searchnametextbox=TkEntry.new(@searchEntry, 'width'=> 30, 'textvariable' => @actorStr)
		@searchnametextbox.grid( :column =>2, :columnspan=>1, :row => 3, :sticky => 'we' )
		actorfind= proc{getNames}
		actorfinde= proc{getNames(true)}
		actorlose= proc{ungetNames}
		actordump= proc{actorDump}
		@searchnametextbox.bind('Key', actorfind)
		@searchnametextbox.bind('Return', actorfinde)
		@searchnametextbox.bind('FocusOut', actorfinde)
		@actorClear=TkButton.new(@searchEntry, "text"=> "Any Actor", "command"=> actorlose, "state"=>'disabled').grid( :column => 3, :row => 3, :sticky => 'sewn')
		@actorDump=TkButton.new(@searchEntry, "text"=> 'Actor Dump', "command"=> actordump, "state"=>"disabled").grid( :column => 4, :row => 4, :sticky => 'new')


		searchstylebox=TkFrame.new(@searchEntry).grid(:row => 1, :column => 3, :columnspan => 2, :sticky=>"nw")
		@searchstyle = TkVariable.new
		@searchstyle.value="all"
		TkRadioButton.new(searchstylebox, "text" => 'exact phrase', "variable" => @searchstyle, "value" => 'phrase').grid( :column => 2, :row => 1, :sticky=>"w")
		TkRadioButton.new(searchstylebox, "text" => 'all words', "variable" => @searchstyle, "value" => 'all').grid( :column => 3, :row => 1, :sticky=>"w")
		TkRadioButton.new(searchstylebox, "text" => 'any words', "variable" => @searchstyle, "value" => 'any').grid( :column => 2, :row => 2, :sticky=>"w")
		TkRadioButton.new(searchstylebox, "text" => 'affects/checks variable:', "variable" => @searchstyle, "value" => 'variable').grid( :column => 3, :row => 2, :sticky=>"w")

		@selectedLine = TkVariable.new
		@resultsCount = TkVariable.new
		@selectedLine.value="Select a Line To View More Details Here"
		TkLabel.new(@searchEntry, "textvariable" => @selectedLine,"wraplength"=>450, "height"=>5).grid( :column => 1, :columnspan=>3, :row => 5, :sticky=>"nsew");

		TkGrid.columnconfigure @searchEntry, 2,:weight => 1
		TkGrid.rowconfigure @searchEntry, 5, :weight => 1

		TkLabel.new(@searchEntry, "textvariable" => @resultsCount).grid( :column => 1, :columnspan=>2, :row => 4, :sticky => 'e');
		# TkLabel.new(@searchEntry) {text 'Dialogue Lines'}.grid( :column => 3, :row => 4, :sticky => 'w')

		@resultsBox = TkFrame.new(@page1).grid(:column=>0,:row=>5,:sticky => 'sewn')
		TkGrid.columnconfigure @page1, 0, :weight => 1
		TkGrid.rowconfigure @page1, 5, :weight => 2

		TkGrid.columnconfigure @resultsBox, 1, :weight => 1
		TkGrid.rowconfigure @resultsBox, 5, :weight => 1

		begintrace=proc{traceLine}
		@traceButton = TkButton.new(@resultsBox, "text"=> 'trace line ', "command"=> begintrace, "state"=>"disabled", "wraplength"=>300).grid( :column => 1, :row => 1, :sticky => 'we')
		begindump=proc{dumpLine}
		@dumpButton = TkButton.new(@resultsBox, "text"=> 'dump conversation ', "command"=> begindump, "state"=>"disabled", "wraplength"=>300).grid( :column => 1, :row => 2, :sticky => 'we')

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
		@searchlistbox.grid(:column=>1, :row => 5, :sticky => "sewn")

		@searchlistbox.bind('ButtonRelease-1', sel)
		@searchlistbox.bind('Return', sel)


		scroll = TkScrollbar.new(@resultsBox) do
		   orient 'vertical'
		end
		scroll.grid(:column=>2, :row => 5, :sticky => "ns")

		@searchlistbox.yscrollcommand(proc { |*args|
		   scroll.set(*args)
		})

		scroll.command(proc { |*args|
		   @searchlistbox.yview(*args)
		}) 

		scrollx = TkScrollbar.new(@resultsBox) do
		   orient 'horizontal'
		end
		scrollx.grid(:column=>1, :row => 6, :sticky => "ew")

		@searchlistbox.xscrollcommand(proc { |*args|
		   scrollx.set(*args)
		})

		scrollx.command(proc { |*args|
		   @searchlistbox.xview(*args)
		}) 
	end
	def buildBrowserPage()
		# PAGE 2:
		@convoDisplayArea = TkFrame.new(@page2)
		@convoDisplayArea.grid(:column=>3, :row=>3, :sticky=>"sewn" )

		@underButtonFrame = TkFrame.new(@page2)
		@underButtonFrame.grid(:column=>3,:row=>5, :sticky=>"sewn" )

		@overButtonFrame = TkFrame.new(@page2)
		@overButtonFrame.grid(:column=>3,:row=>1, :sticky=>"sewn" )

		if @browserButtons.value.to_i >0 then
			@forwButtonArea = TkText.new(@underButtonFrame) {width 40; height 2; wrap "word"; background "grey"; height 3}
			@forwButtonArea.grid(:column => 0, :row => 1, :sticky => 'nwes')
			TkGrid.columnconfigure(@underButtonFrame, 0, :weight => 1)
			TkGrid.rowconfigure @underButtonFrame, 1, :weight => 1

			fbys = TkScrollbar.new(@underButtonFrame) {orient 'vertical'}
			fbys.grid( :column => 1, :row => 0, :sticky => 'ns')

			@forwButtonArea['yscrollcommand'] = proc{|*args| fbys.set(*args);}
			fbys.command proc{|*args| @forwButtonArea.yview(*args);}


			@backButtonArea = TkText.new(@overButtonFrame) {width 40; height 2; wrap "word"; background "grey"; height 3}
			@backButtonArea.grid(:column => 0, :row => 0, :sticky => 'nwes')
			TkGrid.columnconfigure(@overButtonFrame, 0, :weight => 1)
			TkGrid.rowconfigure @overButtonFrame, 0, :weight => 1

			bbys = TkScrollbar.new(@overButtonFrame) {orient 'vertical'}
			bbys.grid( :column => 1, :row => 0, :sticky => 'ns')

			@backButtonArea['yscrollcommand'] = proc{|*args| bbys.set(*args);}
			bbys.command proc{|*args| @backButtonArea.yview(*args);}
		end

				# ADD BACK BUTTONS
		TkButton.new(@overButtonFrame, "text"=> "Undo last backward step", "command" => proc{@explorer.removeLine(true);traceLine;@convoArea.see(1.0)}).grid(:row =>2, :column => 0, :sticky => 'sewn', :columnspan=>2)

		TkButton.new(@underButtonFrame, "text"=> "Undo last forward step", "command" => proc{@explorer.removeLine(false);traceLine;@convoArea.see("end")}).grid(:row =>0, :column => 0, :sticky => 'sewn', :columnspan=>2)

		TkGrid.columnconfigure @page2, 3, :weight => 1

		TkGrid.rowconfigure @page2, 3, :weight => 3
		# TkGrid.rowconfigure @page2, 1, :weight => 1
		# TkGrid.rowconfigure @page2, 5, :weight => 1

		@upda=proc{updateConversation}
		@updas=proc{updateConversation(true)}

		@convoArea = TkText.new(@convoDisplayArea) {width 40; height 10; wrap "word"}
		@convoArea.grid(:column => 0, :row => 0, :sticky => 'nwes')
		TkGrid.columnconfigure(@convoDisplayArea, 0, :weight => 1)
		TkGrid.rowconfigure @convoDisplayArea, 0, :weight => 1

		ys = TkScrollbar.new(@convoDisplayArea) {orient 'vertical'}
		ys.grid( :column => 1, :row => 0, :sticky => 'ns')

		@convoArea['yscrollcommand'] = proc{|*args| ys.set(*args);}
		ys.command proc{|*args| @convoArea.yview(*args);}
		@convoArea.insert('end', "Conversation Will Display Here When Tracing Begins ")

		TkGrid.rowconfigure(@page2, 3, :weight => 1)
	end

	def buildDumpPage()
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
		TkLabel.new(@dumpDisplayArea, "text" => "Apologies, for performance reasons, these dumps do not show red checks or alternate lines, these can only be viewed in the conversation browser.","wraplength"=>500).grid( :column => 0, :row => 10, :sticky => 'ew');
	end

	def buildConfigPage()
		# PAGELAST
		@browseDisplayOptions = TkFrame.new(@pageLAST)
		@browseDisplayOptions.grid(:column=>3, :row=>0, :sticky=>"sewn" )

		# TkLabel.new(@page2, "textvariable" => @pickmeline, "wraplength"=>400).grid( :column => 1, :row => 4, :sticky => 'sw')

		browsemarkcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show markdown tags?',
	    	"command" =>@updas,
	    	"variable" =>@browserMarkdown,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browsemarkcheckbox.grid(:row=>1, :column=>5,:sticky => 'w')

	    browsehubscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show hubs?',
	    	"command" =>@upda,
	    	"variable" =>@browserHubs,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browsehubscheckbox.grid(:row=>2, :column=>5,:sticky => 'w')

	    browselomgcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show details?',
	    	"command" =>@upda,
	    	"variable" =>@browserShowMore,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browselomgcheckbox.grid(:row=>3, :column=>5,:sticky => 'w')

	    browsealtscheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show alternate lines?',
	    	"command" =>@upda,
	    	"variable" =>@browserShowAlts,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browsealtscheckbox.grid(:row=>4, :column=>5,:sticky => 'w')


	    browsehlcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'highlight new lines?',
	    	"variable" =>@browserHightlightLines,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browsehlcheckbox.grid(:row=>5, :column=>5,:sticky => 'w')


	    browserbuttonchanger=proc{buildBrowserPage;traceLine}
	    browsebutcheckbox = TkCheckButton.new(@browseDisplayOptions,
			"text"=>'show buttons instead of links?',
	    	"variable" =>@browserButtons,
	    	"command"=>browserbuttonchanger,
	    	"onvalue" => 1, 
	    	"offvalue" => 0)
	    browsebutcheckbox.grid(:row=>6, :column=>5,:sticky => 'w')
		
        
		dbget=proc{@dbFname = Tk::getOpenFile; checkDatabase}
		@dbfnamedisplay=TkLabel.new(@browseDisplayOptions, "text"=>@dbFname.split("/")[-1]).grid( :column => 3, :row => 1, :sticky => 'sewn')
		TkButton.new(@browseDisplayOptions, "text"=> 'Load Database', "command"=> dbget).grid( :column => 3, :row => 2, :sticky => 'sewn')

		@dispoptions=TkLabel.new(@browseDisplayOptions, "text" => "Configuration Options", "wraplength"=>400, "font"=>@fontOption.value, "background"=>@highlightColour).grid( :column => 3,  :row => 0, :columnspan=>3, :sticky => 'w')
		fontprev=proc{@dispoptions['font'] = @fontOption.value}

		# Deprecated Font Settngs

		# TkRadioButton.new(@browseDisplayOptions, "text" => 'monospace', "variable" => @fontOption, "value" => 'courier 12',"command"=>fontprev).grid( :column => 3, :row => 1, :sticky=>"e")
		# TkRadioButton.new(@browseDisplayOptions, "text" => 'serif', "variable" => @fontOption, "value" => 'times 12',"command"=>fontprev).grid( :column => 3, :row => 2, :sticky=>"e")
		# TkRadioButton.new(@browseDisplayOptions, "text" => 'sansserif', "variable" => @fontOption, "value" => 'helvetica 12',"command"=>fontprev).grid( :column => 3, :row => 3, :sticky=>"e")

		TkButton.new(@browseDisplayOptions, "text"=> 'Save Configs', "command"=> proc{saveConfigs}).grid( :column => 3, :row => 10, :sticky => 'sewn')
		TkButton.new(@browseDisplayOptions, "text"=> 'Load Configs', "command"=> proc{loadConfigs}).grid( :column => 5, :row => 10, :sticky => 'sewn')

		TkFont::Fontchooser.configure :font => @fontOption.value, :command => proc{|f| font_changed(f);}

		fontget=proc{TkFont::Fontchooser.show}

		TkButton.new(@browseDisplayOptions, "text"=> 'Font Options', "command"=> fontget).grid( :column => 3, :row => 4, :sticky => 'sewn')

		colget=proc{colorPicker}
		TkButton.new(@browseDisplayOptions, "text"=> 'Highlight Colour:', "command"=> colget).grid( :column => 3, :row => 5, :sticky => 'sewn')
	end
    
    def checkDatabase()
    	if File.exists?(@dbFname)
			@databaseTemp= SQLite3::Database.open @dbFname
			presence=@databaseTemp.execute "SELECT name FROM sqlite_master WHERE type='table'ORDER BY name;"
			presence.flatten!
			checklist=["actors", "alternates", "checks","dentries", "dialogues", "dlinks", "meta", "modifiers", "variables"]
			missingTables=checklist-presence
			if missingTables.length>0 then
				msgBox = Tk::messageBox :type   => "okcancel", :icon => "warning",:message => "Database is missing some tables and may cause crashes:", :detail => "missing tables: #{missingTables.join(", ")}"
			else
				msgBox="ok"
			end

			if msgBox=="ok"
				$db=@databaseTemp
				if not @dbfnamedisplay.nil? then 
					@dbfnamedisplay.text=@dbFname.split("/")[-1]
				end
				@missingTables=missingTables

				@note.tabconfigure(0, :state =>'normal')
				@note.tabconfigure(1, :state =>'normal')
				@note.tabconfigure(2, :state =>'normal')

				if @missingTables.include?("meta") then
					@versionInfo.value=$versionNumber+ " (Database missing version info)"
				else
					version=$db.execute "select value from meta where tuple='version-date';"
					version.flatten!
					@versionInfo.value=$versionNumber+" - Database based on #{version.join("/")} game data"
				end
			end
		else
			if $db
				return true
			else
				@note.select(3)
				@note.tabconfigure(0, :state =>'disabled')
				@note.tabconfigure(1, :state =>'disabled')
				@note.tabconfigure(2, :state =>'disabled')

				# @page1.itemconfigure("state" => "disabled")

			end

		end
    end

    def fontCheck()
    	font=@fontOption.value
		if font.split(" ")[-1].to_i<1 then
			@fontOption.value=font.strip+" 12"
		end
	end

	def colorPicker()
		highlightColour=Tk::chooseColor :initialcolor => @highlightColour
		if highlightColour.length>1 
			@highlightColour=highlightColour
		end
		@dispoptions.background=@highlightColour
	end

	def font_changed(font)
		@fontOption.value = font
		fontCheck
		@dispoptions['font'] = @fontOption.value
		fontUsers=[@convoArea,@dumpTextBox]
		fontUsers.each do |textarea|
			textarea.tag_configure('markdownbold', :font=>"#{@fontOption} bold")
			textarea.tag_configure('markdownitalic', :font=>"#{@fontOption} italic")
			textarea.tag_configure('markdownblank', :font=>"#{@fontOption}")
		end
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

			# actormatches = $db.execute("Select name,id from actors where name like '%#{@actorStr.value}%'")
			if @actorList.nil?
				@actorList=$db.execute("Select name,id from actors order by talkativeness desc")
			end
			actorstrcase=@actorStr.value.downcase
			actormatches = @actorList.select{|e| e[0].downcase.include?(actorstrcase)}
			if actormatches.length==0 then
				@searchnametextbox.background="red"
				return nil
			else
				@searchnametextbox.background="white"
			end
			if actormatches.length==1 or complete then
				@actorStr.value=actormatches[0][0]
				@searchnametextbox.state="disabled"
				@actorlimit=actormatches[0][1]
				@actorClear.state="normal"
				@actorDump.state="normal"
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

		configFileName="FAYDEconfig.txt"

		confStr="database:#{@dbFname}\nfont:#{@fontOption.value}\nmarkdown:#{@browserMarkdown.value}\nhubsshow:#{@browserHubs.value}\ndetailshow:#{@browserShowMore.value}\naltsshow:#{@browserShowAlts.value}\nhlcolour:#{@highlightColour}\nbrowserbuttons:#{@browserButtons}\n"
		
		File.write(configFileName, confStr) #, mode: "w")
	end

	def loadConfigs()
		@highlightColour='#eefff0'
		@browserMarkdown = TkVariable.new
		@browserMarkdown.value = 1
		@browserHubs = TkVariable.new
		@browserHubs.value = 0
	    @browserShowMore = TkVariable.new
		@browserShowMore.value = 1
	    @browserShowAlts = TkVariable.new
		@browserShowAlts.value = 1
	    @browserHightlightLines = TkVariable.new
		@browserHightlightLines.value = 1
	    @browserButtons = TkVariable.new
		@browserButtons.value = 0
	    @fontOption = TkVariable.new
		@fontOption.value="courier 13"
		@dbFname="test.db"

		configFileName="FAYDEconfig.txt"
		if File.exists?(configFileName)
			configs = File.read(configFileName).split("\n")
			configs.map! { |e| e.split(":",2) }

			configs.each do |config|
				if config[1].length > 0
					case config[0]
					when 'database'
						@dbFname=config[1]
					when 'font'
						@fontOption.value=config[1]
					when 'markdown'
						@browserMarkdown.value=config[1]
					when 'hubsshow'
						@browserHubs.value=config[1]
					when 'detailshow'
						@browserShowMore.value=config[1]
					when 'altsshow'
						@browserShowAlts.value=config[1]
					when 'hlcolour'
						@highlightColour=config[1]
					when 'browserbuttons'
						@browserButtons.value=config[1]
					end
				end
			end
			fontCheck
			if not @dispoptions.nil? then
				@dispoptions.background=@highlightColour
				@dispoptions['font'] = @fontOption.value
			end
		end
	end

	def overwriteTextHighlightNew(areatoprint, texttoprint)
		oldt= areatoprint.get("1.0", 'end')
		printText(areatoprint,texttoprint)
		oldt=oldt.split("\n")
		newt=texttoprint.split("\n")
		additions=newt-oldt
		newt.each_with_index do |line, i|
			if oldt.index(line).nil? then
				areatoprint.tag_add("newLineHighlight", "#{i+1}.0", "#{i+1}.end")
			end
		end
		areatoprint.tag_configure('newLineHighlight', :background=>@highlightColour)
	end

	def printText(areatoprint, texttoprint)
		areatoprint.tag_configure('markdownbold', :font=>"#{@fontOption} bold")
		areatoprint.tag_configure('markdownitalic', :font=>"#{@fontOption} italic")
		areatoprint.tag_configure('markdownblank', :font=>"#{@fontOption}")
		# App.text.tag_configure('highlight', background='yellow' font='helvetica 14 bold', relief='raised')

		if @browserMarkdown>0
			italdelim="*"
			bolddelim="**"
		else
			italdelim=""
			bolddelim=""
		end

		areatoprint.delete(1.0, 'end')

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


	def updateConversation(overridehighlight=false)
		@convoArea['state'] = :normal

		convo=@explorer.outputLineCollectionStr(@browserShowMore>0,@browserHubs<1,@browserMarkdown>0,true,@browserShowAlts>0)

		if @browserHightlightLines>0 and not(overridehighlight) then
			overwriteTextHighlightNew(@convoArea,convo)
		else
			printText(@convoArea,convo)
		end

		if @browserButtons.value.to_i<1 then
			optionsStrs=@explorer.getForwardOptStrs
			@chbuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectForwTraceOpt(i);traceLine;@convoArea.see("end")} }
			optionsStrs.each_with_index do |par, i|
				@convoArea.insert("end","#{i+1}: #{par}\n", "flineoption#{i}")
				@convoArea.tag_bind("flineoption#{i}", '1', @chbuttoncommands[i])
				@convoArea.tag_configure("flineoption#{i}",  :font=>"#{@fontOption}", :underline=>true)
			end
			optionsStrs=@explorer.getBackwardOptStrs
			@pabuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectBackTraceOpt(i);traceLine;@convoArea.see(1.0)} }
			optionsStrs.each_with_index do |par, i|
				@convoArea.insert((1.0+i),"#{i+1}: #{par}\n", "blineoption#{i}")
				@convoArea.tag_bind("blineoption#{i}", '1', @pabuttoncommands[i])
				@convoArea.tag_configure("blineoption#{i}",  :font=>"#{@fontOption}", :underline=>true)
			end
		end
	end

	def dumpLine()
		@note.tabconfigure(2, :state =>'normal')
		@note.select(2)
		@dumpTextBox.delete(1.0, 'end')
		dump= @explorer.dialoguedump(@browserShowMore>0,@browserHubs<1,true)
		@convoDesc.value=@explorer.conversationinfo

		printText(@dumpTextBox,dump)
	end

	def actorDump()
		@note.tabconfigure(2, :state =>'normal')
		@note.select(2)
		@dumpTextBox.delete(1.0, 'end')
		dump= @explorer.actorDump(@actorlimit,@browserShowMore>0,@browserHubs<1,true)

		printText(@dumpTextBox,dump)
	end

	def traceLine()
		# @page2.state="normal"
		@note.tabconfigure(1, :state =>'normal')
		if @browserButtons.value.to_i >0 then
			@backButtonArea.state="normal"
			@forwButtonArea.state="normal"
		end
		@note.select(1)
		numberofbuttonstostack=5
		buttonwidth=250

		if @explorer.collectionStarted
			@explorer.traceBackOrForth(false)
			@explorer.traceBackOrForth(true)
			updateConversation
			optionsStrs=@explorer.getForwardOptStrs

			if @childButtons.nil? or @childButtons.empty? then
				@childButtons=[]
			else
				@childButtons.each do |butter|
					butter.destroy()
				end
				@childButtons=[]
			end
			@chbuttoncommands=[]
			@chbuttoncommands=Array.new(optionsStrs.length) { |i| proc{@explorer.selectForwTraceOpt(i);traceLine;@convoArea.see("end")} }
			optionsStrs.each_with_index do |par, i|
				if @browserButtons.value.to_i >0 then
					@childButtons.push(TkButton.new(@forwButtonArea, "text"=> par, "command" => @chbuttoncommands[i], "wraplength"=>buttonwidth))
					TkTextWindow.new(@forwButtonArea, "end", :window => @childButtons[i])
				# else
				# 	@convoArea.insert("end","#{i+1}: #{par}\n", "flineoption#{i}")
				# 	@convoArea.tag_bind("flineoption#{i}", '1', @chbuttoncommands[i])
				# 	@convoArea.tag_configure("flineoption#{i}",  :font=>"#{@fontOption}", :underline=>true)
				end
			end
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
				if @browserButtons.value.to_i >0 then
					@parentButtons.push(TkButton.new(@backButtonArea, "text"=> par, "command" => @pabuttoncommands[i], "wraplength"=>buttonwidth))
					TkTextWindow.new(@backButtonArea, "end", :window => @parentButtons[i])
				# else
				# 	@convoArea.insert((1.0+i),"#{i+1}: #{par}\n", "blineoption#{i}")
				# 	@convoArea.tag_bind("blineoption#{i}", '1', @pabuttoncommands[i])
				# 	@convoArea.tag_configure("blineoption#{i}",  :font=>"#{@fontOption}", :underline=>true)
				end
			end
			
			if @browserButtons.value.to_i >0 then
				@backButtonArea.state="disabled"
				@forwButtonArea.state="disabled"
			end


		end
	end


	def makeSearchResults()
		@searchlistbox.state="normal"
		searchStr=@searchStr.value
		searchResults=""

		# case @searchstyle
		# when "phrase"
		# 	@searchByPhrase=true
		# 	@searchAnyWord=false
		# when "all"
		# 	@searchByPhrase=false
		# 	@searchAnyWord=false
		# when "any"
		# 	@searchByPhrase=false
		# 	@searchAnyWord=true
		# else
		# 	@searchByPhrase=false
		# 	@searchAnyWord=false
		# end

		@lineSearch=@explorer.searchlines(searchStr,@actorlimit,@searchstyle)
		@resultsCount.value="Found: #{@lineSearch.length} results:"
		itemsinbox=@searchlistbox.size

		if itemsinbox>0 then
			@searchlistbox.delete(0, :end)
		end

		@lineSearch.each{|result| @searchlistbox.insert "end", result}
	end
end


begin
	# # Database opening now covered by gui functions
	# $db = SQLite3::Database.open 'test.db'
	$versionNumber="FAYDE Playback Experiment - Version 0.21.4.20"
    GUIllaume.new()
	
	Tk.mainloop

# #error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    $db.close if $db
end

