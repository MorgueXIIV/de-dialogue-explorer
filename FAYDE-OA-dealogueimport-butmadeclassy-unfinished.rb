#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
require 'sqlite3'
# require 'tk';

def DealogueImporter

	#gets a specific conversation from dialogues with the ID
	def idConvo(idNumber=1, dialoguefile=dealogues)
		return dialoguefile["conversations"][idNumber-1];
	end

	#that but then a line from that convo (Passed itself as a hash object NOT by reference value)
	def idConvoLine(idNumber, convo)
		return convo["dialogueEntries"][idNumber];
	end

	def getUniqID(cid, did)
		uid= (cid*10000) + did
		return uid
	end

	#this method gets a speficied attribute from a passed hash. 
	#Crucially, ti will get it if it's a direct part of the hash, OR if it's been embedded in the "fields" hash, or if htat as is still an array... etc
	def getCLAttribute(convoOrLine, attributeToGrab)
		if (convoOrLine.has_key?(attributeToGrab)) then
			return convoOrLine[attributeToGrab];
		elsif convoOrLine["fields"].is_a?(Hash) then
			if convoOrLine["fields"].has_key?(attributeToGrab) then
				return convoOrLine["fields"][attributeToGrab];
			else
				return "";
			end
		elsif convoOrLine["fields"].is_a?(Array) 
			convoOrLine["fields"].each do |fieldobj|
				if fieldobj.has_key?(attributeToGrab) then
					return fieldobj[attributeToGrab]
				elsif fieldobj["title"]==attributeToGrab then
	                return fieldobj["value"]
				end
			end
		else 
			return ""
		end
		return ""
	end

	# returns false if line doesn't have a check, returns the check's attributes if if does
	def getIsCheckAttributes(lineCheck)
		checkInfo=[]
		whiteDiff=getCLAttribute(lineCheck,"DifficultyWhite")
		if whiteDiff!=0 then
			checkInfo.push(0)
			checkInfo.push(whiteDiff)
		else
			redDiff=getCLAttribute(lineCheck,"DifficultyRed")
			if redDiff!=0
				checkInfo.push(1)
				checkInfo.push(redDiff)
			else
				return false
			end
		end
		checkInfo.push(getCLAttribute(lineCheck,"FlagName"))
		skillID=getCLAttribute(lineCheck,"SkillType").to_s
		skillName=$articyIDskills[skillID]
		checkInfo.push(skillName)
		return checkInfo
	end

	def getCheckModifiersArrays(lineCheck)
		modifierList=[]
		i=1
		for i in 1..10 do
			tooltip=getCLAttribute(lineCheck,"tooltip#{i}")
			if tooltip.length>1 then
				modifier=getCLAttribute(lineCheck,"modifier#{i}")
				variable=getCLAttribute(lineCheck,"variable#{i}")
				thisMod=[variable,modifier,tooltip]
				modifierList.push(thisMod)
			else
				break;
			end
		end
		return modifierList
	end

	def getLineAlternatesArrays(lineCheck)
		altList=[]
		i=1
		for i in 1..10 do
			alternate=getCLAttribute(lineCheck,"Alternate#{i}")
			if (alternate.length>1) then
				condition=getCLAttribute(lineCheck,"Condition#{i}")
				thisAlt=[condition,alternate]
				altList.push(thisAlt)
			else
				break;
			end
		end
		return altList
	end


	def getArrayForDB(hashToInspect, arrayOfAttributes)
		arrayOfData = []
		arrayOfAttributes.each do |attributeToGrab|
			arrayOfData.push(getCLAttribute(hashToInspect,attributeToGrab));
		end
		return arrayOfData;
	end

		$articyIDskills=Hash[
			"0x0100000400000918"=>"Conceptualization",
			"0x0100000400000767"=>"Logic",
			"0x010000040000076B"=>"Encyclopedia",
			"0x0100000A00000016"=>"Rhetoric",
			"0x0100000A0000001A"=>"Drama",
			"0x0100000A0000001E"=>"Visual Calculus",
			"0x0100000400000773"=>"Empathy",
			"0x010000040000076F"=>"Inland Empire",
			"0x0100000A0000003E"=>"Volition",
			"0x0100000A00000042"=>"Authority",
			"0x0100000A00000046"=>"Suggestion",
			"0x0100000A0000004A"=>"Esprit de Corps",
			"0x01000004000009A7"=>"Endurance",
			"0x0100000400000B11"=>"Physical Instrument",
			"0x0100000400000BC7"=>"Shivers",
			"0x0100000A00000022"=>"Pain Threshold",
			"0x0100000A00000026"=>"Electrochemistry",
			"0x01000011000010D8"=>"Half Light",
			"0x0100000A0000002A"=>"Hand/Eye Coordination",
			"0x0100000A0000002E"=>"Reaction Speed",
			"0x0100000A00000032"=>"Savoir Faire",
			"0x0100000A00000036"=>"Interfacing",
			"0x0100000A0000003A"=>"Composure",
			"0x0100000400000BC3"=>"Perception",
			"0x0100000800000BAC"=>"Perception (Smell)",
			"0x0100000800000BB0"=>"Perception (Hearing)",
			"0x0100000800000BB8"=>"Perception (Taste)",
			"0x0100000800000BBC"=>"Perception (Sight)",
			"0x0100005200000001"=>"Psyche",
			"0x0100005200000005"=>"Motorics",
			"0x0100005200000009"=>"Intellect",
			"0x010000520000000D"=>"Fysique",]

	def execOrWrite(statement, atts=[])
		if @outputSQLonly
			if atts.length>0
				statement = statement.sub(/\( ?\?[? ,]*\)/, "(#{atts.join(",")})")
			end
			@sqlStatements.push(statement)
		else
			@db.execute(statement)
		end
	end

	def import
		#reads in and parses the JSON
		starttime=Time.now()
		outputSQLonly=true

		creategoodnamedDB=false
		# useJSON='Disco Elysium Cut.json'
		useJSON='Disco Elysium Text Dump Game Version 1.0 (10_15_19) cut.json'
	    useJSON='Disco Elysium Final Cut-Cut.json'

		json= File.read(useJSON);
		dealogues=JSON.parse(json);

		if creategoodnamedDB then
		  	version = dealogues['version']
			# opens a DB file, Creates our database tables
			versioname=version.gsub(/[\/ :]/,"-")
			dbfilename= "discobase#{versioname}.db"
		else
			dbfilename= "development.sqlite3"
		end

		if outputSQLonly then
			sqlfilen = "discoData.sql"
			sqlStatements=[]
		else
			puts "Opening #{dbfilename}"
			db = SQLite3::Database.open dbfilename
		end


		# CHANGE THESE VALUES IN THE SCRIPT TO ENABLE/DISABLE
		# POPULATING CERTAIN TABLES
		doActors=true
		doDialogues=true
		doConversations=true
		doDialoguelinks=true
		doChecks=true
		doModifiers=true
		doAlternateLines=true
		doVariables=false

		# these strings represent the various keys we need from each hash to fed into the database
		# stored in an ITERABLE array so we can easily use them in a method for a nice DRY grab of data to insert
		listOfLineAtts=["id", "conversationID","Title","Dialogue Text","Sequence","Actor", "DifficultyPass","conditionsString","userScript"]
		listOfConvoAtts=["id", "Title", "Description"]
		listOfLinkAtts=["originConversationID","originDialogueID","destinationConversationID","destinationDialogueID", "priority"]


		#inistialise counter
		numberOfdbEntriesMade=0;
		#using transactions means the database is written to all at once making all these entries
		#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries
		db.transaction if not outputSQLonly

		#Loop over the actors array, create a hash of relevant attributes (concatenate descriptions), stick them in the database
		if doActors then
			puts "Doing that 'Actors' table:"
			# add the HUB actor
			execOrWrite "INSERT INTO actors (id, name) values (?,?)", [0,"HUB"];
			numberOfdbEntriesMade+=1;
			# add actors from json
			for thisActor in dealogues["actors"] do
				actorAtts=[getCLAttribute(thisActor,"id"),getCLAttribute(thisActor,"Name")];
				# db.execute "INSERT INTO actors (id, name) values (?,?)", actorAtts;
				execOrWrite "INSERT INTO actors (id, name) values (?,?)", actorAtts;
				numberOfdbEntriesMade+=1;
			end
			puts "actors complete with #{numberOfdbEntriesMade} records so far"
		end
		if doVariables then
			puts "Doing that 'variables' table:"
			for thisVar in dealogues["variables"] do
				varAtts=[getCLAttribute(thisVar,"id"), getCLAttribute(thisVar,"Name"),getCLAttribute(thisVar,"Description"), getCLAttribute(thisVar,"Initial Value")]
				execOrWrite "INSERT INTO variables (id, name, description, initialvalue) values (?,?,?,?)", varAtts;
				numberOfdbEntriesMade+=1;
			end
			puts "variables complete with #{numberOfdbEntriesMade} records so far"
		end

		if (doConversations or doAlternateLines or doChecks or doDialogues or doDialoguelinks) then
			# shockingly complex routine to tell terminal what we're doing
			listofthingstodothisloop= Hash["dialogues" => doDialogues, "conversations" => doConversations, "dialogue links" => doDialoguelinks, "dialogue active checks" =>doChecks, "alternate dialogue lines" => doAlternateLines]
			listofthingstodothisloop.select!{|k,v| v }
			if listofthingstodothisloop.empty? then
				listofthingstodothisloop= "THIS SHOULD NEVER RUN ACTUALLY"
			else 
				listofthingstodothisloop=listofthingstodothisloop.keys.join(", ")
				listofthingstodothisloop += "(this is the BIG DATASET, pls be patient)"
			end

			puts "adding #{listofthingstodothisloop} to the database "
			#loop over the conversations and enter them into the database
			for thisConvo in dealogues["conversations"] do
				if doConversations then
					conversationAtts=[]
					conversationAtts=getArrayForDB(thisConvo,listOfConvoAtts);

					execOrWrite "INSERT INTO conversations (id, title, description) VALUES (?,?,?)", conversationAtts;
					numberOfdbEntriesMade+=1;
				end
				
				#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
				for thisLine in thisConvo["dialogueEntries"] do
					checkData=getIsCheckAttributes(thisLine)
					altData=getLineAlternatesArrays(thisLine)
					if doDialogues then
						lineAtts=[]
						lineAtts=getArrayForDB(thisLine,listOfLineAtts);
						did=lineAtts[0]
						cid=lineAtts[1]
						#reassurance dot every 1000 records
						print '.' if ((cid % 1000) == 0) 
						uid=getUniqID(cid,did)
						lineAtts.unshift(uid)

						execOrWrite "INSERT INTO dialogues (id, incid, conversation_id, title, dialoguetext, sequence, actor_id,difficultypass,conditionstring,userscript) VALUES (?,?,?,?,?,?,?,?,?,?)", lineAtts;
						numberOfdbEntriesMade+=1;
					end

					# insert checks and modifiers if the line has a check
					if checkData then
						if doChecks
							checkData.unshift(uid)
							checkData.unshift(nil)
							execOrWrite "INSERT INTO checks (id,dialogue_id, isred, difficulty, flagname, skilltype) VALUES (?,?,?,?,?,?)", checkData;
							numberOfdbEntriesMade+=1;
						end
						if doModifiers
							modifiers=getCheckModifiersArrays(thisLine);
							if !(modifiers.nil? or modifiers.empty?) then
								modifiers.each do |mod|
									mod.unshift(uid)
									execOrWrite "INSERT INTO modifiers (dialogue_id, variable, modification, tooltip) VALUES (?,?,?,?)", mod;
									numberOfdbEntriesMade+=1
								end
							end
						end
					end


					if doAlternateLines
						if !(altData.nil? or altData.empty?) then
							altData.each do |alt|
								alt.unshift(uid)
								alt.unshift(nil)
								execOrWrite "INSERT INTO alternates (id,dialogue_id, conditionstring, alternateline) VALUES (?,?,?,?)", alt;
								numberOfdbEntriesMade+=1;
							end
						end
					end

					#add ANOTHER loop which enters any outgoing links to the links database IF they exist;
					if doDialoguelinks
						if thisLine.has_key?("outgoingLinks") then
							#linksdb loop
							for thisLink in thisLine["outgoingLinks"] do
								linkAtt0s=[] #create array
								linkAtts=[] #create array
								linkAtt0s=getArrayForDB(thisLink,listOfLinkAtts);
								linkAtts=[nil, getUniqID(linkAtt0s[0],linkAtt0s[1]), getUniqID(linkAtt0s[2],linkAtt0s[3]),linkAtt0s[4]]
								execOrWrite "INSERT INTO dialogue_links (id, origin_id, destination_id, priority) VALUES (?,?,?,?)", linkAtts #SQL insert
								numberOfdbEntriesMade+=1;
							end
						end
					end
				end
			end
		end

		if outputSQLonly then
			File.write(sqlfilen,sqlStatements.join("\n"))
		else
			db.commit
		end

		puts "inserted #{numberOfdbEntriesMade} records into the databases";

		endtime=Time.now()
		timetaken=endtime - starttime
		puts "Database creation/updates took #{timetaken} seconds"
		end

begin
	this=DealogueImporter.new
	DealogueImporter.import()

rescue SQLite3::Exception => e 
    puts "there was a Database Creation error: " + e.to_s;
    puts e.backtrace;
    #Rollback prevents partially complete data sets being inserted
    #minimising re-run errors after an exception is raised mid records
    # puts e.trace;
    db.rollback

rescue JSON::UnparserError => e 
    puts "there was a JSON Parse error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end

