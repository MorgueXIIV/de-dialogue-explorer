#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
require 'sqlite3'
# require 'tk';

#gets a specific conversation from dialogues with the ID
def idConvo(idNumber=1, dialoguefile=dealogues)
	return dialoguefile["conversations"][idNumber-1];
end

#that but then a line from that convo (Passed itself as a hash object NOT by reference value)
def idConvoLine(idNumber, convo)
	return convo["dialogueEntries"][idNumber];
end

#this method gets a speficied attribute from a passed hash. 
#Crucially, ti will get it if it's a direct part of the hash, OR if it's been embedded in the "fields" hash.
def getCLAttribute(convoOrLine, attributeToGrab)
	if (convoOrLine.has_key?(attributeToGrab)) then
		return convoOrLine[attributeToGrab];
	else
		if convoOrLine["fields"].has_key?(attributeToGrab) then
			return convoOrLine["fields"][attributeToGrab];
		else
			return 0;
		end
	end
end

# returns false if line doesn't have a check, returns the check's attributes if if does
def getIsCheckAttributes(lineCheck)
	checkInfo=[getCLAttribute(lineCheck,"conversationID"), getCLAttribute(lineCheck,"id")]
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
	if getCLAttribute(lineCheck,"Forced")
		checkInfo.push(1)
	else
		checkInfo.push(0)
	end
	skillID=getCLAttribute(lineCheck,"SkillType").to_s
	skillName=$articyIDskills[skillID]
	checkInfo.push(skillName)
	return checkInfo
end

def getCheckModifiersArrays(lineCheck)
	modifierList=[]
	lineID=[getCLAttribute(lineCheck,"conversationID"), getCLAttribute(lineCheck, "id")]
	i=1
	for i in 1..10 do
		tooltip=getCLAttribute(lineCheck,"tooltip#{i}")
		if tooltip.length>1 then
			thisMod=[]
			modifier=getCLAttribute(lineCheck,"modifier#{i}")
			variable=getCLAttribute(lineCheck,"variable#{i}")
			thisMod[0]=lineID[0]
			thisMod[1]=lineID[1]
			thisMod.push(variable,modifier,tooltip)
			modifierList.push(thisMod)
		else
			break;
		end
	end
	return modifierList
end


def getArrayForDB(hashToInspect, arrayOfAttributes)
	arrayOfData = []
	arrayOfAttributes.each do |attributeToGrab|
		arrayOfData.push(getCLAttribute(hashToInspect,attributeToGrab));
	end
	return arrayOfData;
end


#reads in and parses the JSON
#TEST NEW ERROR HANDLING PLS
begin
	json= File.read('Disco Elysium Cut.json');
	dealogues=JSON.parse(json);

	$articyIDskills=Hash["0x0100000400000918"=>"Conceptualization",
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


	# opens a DB file, Creates our database tables	
	db = SQLite3::Database.open 'test.db'

	db.execute """CREATE TABLE IF NOT EXISTS dialogues
	(id INT PRIMARY KEY, title TEXT, description TEXT, actor INT, conversant INT)""";

	# to do; add routine to find how many lines the actor has
	db.execute """CREATE TABLE IF NOT EXISTS actors
	(id INT PRIMARY KEY, name TEXT, description LONGTEXT, talkativeness INT DEFAULT 0)""";

	db.execute """CREATE TABLE IF NOT EXISTS dentries
	(id INT, title TEXT, dialoguetext TEXT, 
	actor INT, conversant INT, conversationid INT, difficultypass INT DEFAULT 0,
 	isgroup BOOL, hascheck BOOL DEFAULT false, sequence TEXT,
 	hasalts BOOL DEFAULT false, conditionstring TEXT, userscript TEXT,
  	FOREIGN KEY (conversationid) REFERENCES dialogues(id),
  	FOREIGN KEY (actor) REFERENCES actors(id),
  	FOREIGN KEY (conversant) REFERENCES actors(id),
  	PRIMARY KEY(conversationid,id))""";

  	db.execute """CREATE TABLE IF NOT EXISTS dlinks
	(originconversationid INT, origindialogueid INT,
	destinationconversationid INT, destinationdialogueid INT,
	isConnector BOOL DEFAULT false, priority INT DEFAULT 2,
  	FOREIGN KEY (originconversationid,origindialogueid) REFERENCES dentries(conversationid, id),
  	FOREIGN KEY (destinationconversationid,destinationdialogueid) REFERENCES dentries(conversationid, id))""";
  	# database table for links

  	# Database table for CHECKS
  	db.execute """CREATE TABLE IF NOT EXISTS checks
	(conversationid INT, dialogueid INT, isred BOOL DEFAULT false,
	 difficulty INT, flagname TEXT, forced BOOL, skilltype TEXT, 
  	FOREIGN KEY (conversationid,dialogueid) REFERENCES dentries(conversationid, id),
  	PRIMARY KEY(conversationid,dialogueid))""";

  	# Database Table for MODIFIERS
  	db.execute """CREATE TABLE IF NOT EXISTS modifiers
	(conversationid INT, dialogueid INT,
	variable TEXT, modifier INT, tooltip TEXT,
  	FOREIGN KEY (conversationid,dialogueid) REFERENCES checks(conversationid, dialogueid))""";

	# these strings represent the various keys we need from each hash to fed into the database
	# stored in an ITERABLE array so we can easily use them in a method for a nice DRY grab of data to insert
	listOfLineAtts=["id","Title","Dialogue Text","Sequence","Actor","Conversant","conversationID", "difficultyPass","isGroup","conditionsString","userScript"]
	listOfConvoAtts=["id", "Title", "Description","Actor","Conversant"]
	listOfLinkAtts=["originConversationID","originDialogueID","destinationConversationID","destinationDialogueID","isConnector","priority"]

	# CHANGE THESE VALUES IN THE SCRIPT TO ENABLE/DISABLE
	# POPULATING CERTAIN TABLES
	doActors=true
	doDialogues=true
	doDentries=true
	doDlinks=true
	doChecks=true
	doModifiers=true

	#inistialise counter
	numberOfdbEntriesMade=0;
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries
	db.transaction

	#Loop over the actors array, create a hash of relevant attributes (concatenate descriptions), stick them in the database
	if doActors then
		for thisActor in dealogues["actors"] do
			actorAtts=[getCLAttribute(thisActor,"id"),getCLAttribute(thisActor,"Name")];
			aDescription = getCLAttribute(thisActor,"Description").to_s + ":";
			aDescription.concat(getCLAttribute(thisActor,"short_description").to_s + ":");
			aDescription.concat(getCLAttribute(thisActor,"LongDescription").to_s);
			actorAtts.push(aDescription);
			db.execute "INSERT INTO actors (id, name, description) values (?,?,?)", actorAtts;
			numberOfdbEntriesMade+=1;
		end

		# add the HUB actor
		db.execute "INSERT INTO actors (id, name, description) values (?,?,?)", [0,"HUB", "null actor added to allow inner joins"];
		numberOfdbEntriesMade+=1;
	end


	#loop over the conversations and enter them into the database
	for thisConvo in dealogues["conversations"] do
		if doDialogues then
			conversationAtts=[]
			conversationAtts=getArrayForDB(thisConvo,listOfConvoAtts);

			db.execute "INSERT INTO dialogues (id, title, description, actor, conversant) VALUES (?,?,?,?,?)", conversationAtts;
			numberOfdbEntriesMade+=1;
		end
		
		#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
		for thisLine in thisConvo["dialogueEntries"] do
			checkData=getIsCheckAttributes(thisLine)
			if doDentries then
				lineAtts=[]
				lineAtts=getArrayForDB(thisLine,listOfLineAtts);

				if checkData then
					lineAtts.push(1)
				else
					lineAtts.push(0)
				end

				db.execute "INSERT INTO dentries (id, title, dialoguetext, sequence, actor, conversant, conversationid,difficultypass,isgroup,conditionstring,userscript,hascheck) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", lineAtts;
				numberOfdbEntriesMade+=1;
			end

			# insert checks and modifiers if the line has a check
			if checkData then
				if doChecks
					db.execute "INSERT INTO checks (conversationid, dialogueid, isred, difficulty, flagname, forced, skilltype) VALUES (?,?,?,?,?,?,?)", checkData;
					numberOfdbEntriesMade+=1;
				end
				if doModifiers
					modifiers=getCheckModifiersArrays(thisLine);
					if !(modifiers.nil? or modifiers.empty?) then
						modifiers.each do |mod| 
							db.execute "INSERT INTO modifiers (conversationid, dialogueid, variable,modifier, tooltip) VALUES (?,?,?,?,?)", mod;
							numberOfdbEntriesMade+=1
						end
					end
				end
			end
			#add ANOTHER loop which enters any outgoing links to the links database IF they exist;
			if doDlinks
				if thisLine.has_key?("outgoingLinks") then
					#linksdb loop
					for thisLink in thisLine["outgoingLinks"] do
						linkAtts=[] #create array
						linkAtts=getArrayForDB(thisLink,listOfLinkAtts);
						db.execute "INSERT INTO dlinks (originconversationid, origindialogueid, destinationconversationid, destinationdialogueid, isConnector, priority) VALUES (?,?,?,?,?,?)", linkAtts #SQL insert
						numberOfdbEntriesMade+=1;
					end
				end
			end
		end
	end
	db.commit

	#adds a value to talkativeness in actors table with the number of lines they've said 
	#for every actor in the actors table, counts how many times their id appears in the actor column in the dentries table
	
	talkyArray = Array(0..408)

	db.transaction
	lineArray = talkyArray.map{|i| db.execute "SELECT COUNT(*) FROM dentries WHERE actor = #{i}"}
	db.commit

	lineArray.each_with_index do |value, i|
		db.execute "UPDATE actors SET talkativeness = #{value.flatten.join.to_i} WHERE id = #{i}"
	end

	# 	db.transaction
	# 	for currentActor in Array(0..408)
	# 		lineCount = db.execute "SELECT COUNT(*) FROM dentries WHERE actor = #{currentActor}"
	# 		lineCount = lineCount[0][0]
	# 		talkyArray[currentActor] = lineCount
	# 	end
	# 	db.commit
	# 	for currentActor in Array(0..408)
	# 		db.execute "UPDATE actors SET talkativeness = #{talkyArray[currentActor]} WHERE id = #{currentActor}"
	# 	end

	puts "inserted #{numberOfdbEntriesMade} records into the databases";
rescue SQLite3::Exception => e 
    puts "there was a Database Creation error: " + e.to_s;
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

