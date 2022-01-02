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
	if whiteDiff!="" then
		checkInfo.push(0)
		checkInfo.push(whiteDiff)
	else
		redDiff=getCLAttribute(lineCheck,"DifficultyRed")
		if redDiff!=""
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

#reads in and parses the JSON
#TEST NEW ERROR HANDLING PLS
begin
	starttime=Time.now()
	outputSQLonly=false

	creategoodnamedDB=false

	# CHANGE THESE VALUES IN THE SCRIPT TO ENABLE/DISABLE
	# POPULATING CERTAIN TABLES OVERRIDDEN AT CL:
	doActors=true
	doDialogues=true
	doConversations=true
	doDialoguelinks=true
	doChecks=true
	doModifiers=true
	doAlternateLines=true
	doVariables=true
	# useJSON='Disco Elysium Cut.json'
	useJSON='Disco Elysium Text Dump Game Version 1.0 (10_15_19) cut.json'
	useJSON='Disco Elysium Final Cut-Cut.json'
	useJSON='DEJamaisVu.json'


	puts "press enter to read JSON: #{useJSON} (kinda time consuming)"
	gets
	json= File.read(useJSON);
	dealogues=JSON.parse(json);
	puts """Type the following characters before pressing enter to SKIP these tables: \n
	(a)ctors, \n varia(b)les, \n (c)onversations, \n (d)ialogues, \n alternat(e) lines, \n
	modi(f)iers,  \n c(h)ecks, \n dialogue l(i)nks\n
	\n Or enable these options: \n (s) don't put direct to DB, output sql file \n use generic (p)roduction.sql name not named w/ date info
	\n (enter nothing to do whatever's set in the script itself.) """

	opts = gets
	opts = opts.chomp.downcase

	if opts.length > 0 then
		doActors = ( opts.index("a").nil?)
		doDialogues = ( opts.index("d").nil?)
		doConversations = (opts.index("c").nil?)
		doDialoguelinks = (opts.index("i").nil?)
		doChecks = (opts.index("h").nil?)
		doModifiers = (opts.index("f").nil?)
		doAlternateLines = (opts.index("e").nil?)
		doVariables = (opts.index("b").nil?)
		outputSQLonly = (not opts.index("s").nil?)
		creategoodnamedDB = (opts.index("p").nil?)
	end
	doVariables=false #I just didn't rly implement it yet



	if creategoodnamedDB then
		version = dealogues['version']
		# opens a DB file, Creates our database tables
		versioname=version.gsub(/[\/ :]/,"-")
		dbfilename= "discobase#{versioname}.db"
		sqlfilen = "discoData#{versioname}.sql"
	else
		dbfilename= "development.sqlite3"
		sqlfilen = "discoData.sql"
	end

	# these strings represent the various keys we need from each hash to fed into the database
	# stored in an ITERABLE array so we can easily use them in a method for a nice DRY grab of data to insert
	listOfLineAtts=["id", "conversationID","Title","Dialogue Text","Sequence","Actor", "DifficultyPass","conditionsString","userScript"]
	listOfConvoAtts=["id", "Title", "Description"]
	listOfLinkAtts=["originConversationID","originDialogueID","destinationConversationID","destinationDialogueID", "priority"]

	if outputSQLonly then
		sqlfilen = "discoData.sql"
		sqlStatements=[]
	else
		puts "Opening #{dbfilename}"
		db = SQLite3::Database.open dbfilename
	end

 	# SORRY! Fucking PROCS... why? BECAUSE of scope headaches, and my own laziness. Have fun!
	execOrWrite = Proc.new do | statement, atts=[] |
		if outputSQLonly
			if atts.length>0 then
				statement = statement.sub(/\( ?\?[? ,]*\)/, "(\"#{atts.join("\",\"")})\"")
			end
			sqlStatements.push(statement)
		else
			db.execute(statement,atts)
		end
	end

	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries
	db.transaction if not outputSQLonly

	execOrWrite.call ('CREATE TABLE IF NOT EXISTS "actors" ("id" integer NOT NULL PRIMARY KEY, "name" varchar DEFAULT NULL, "dialogues_count" integer)')

	execOrWrite.call ('CREATE TABLE IF NOT EXISTS "alternates" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "alternateline" varchar, "conditionstring" varchar, "dialogue_id" integer, CONSTRAINT "fk_rails_989622cdad" FOREIGN KEY ("dialogue_id") REFERENCES "dialogues" ("id"))')

		execOrWrite.call ('CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime NOT NULL, "updated_at" datetime NOT NULL)')

		execOrWrite.call ('CREATE TABLE  IF NOT EXISTS "checks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "isred" varchar, "difficulty" varchar, "flagname" varchar, "skilltype" varchar, "dialogue_id" integer, CONSTRAINT "fk_rails_4e5056ee06" FOREIGN KEY ("dialogue_id")  REFERENCES "dialogues" ("id"))')

		execOrWrite.call ('CREATE TABLE  IF NOT EXISTS "conversations" ("id" integer NOT NULL PRIMARY KEY, "title" varchar DEFAULT NULL, "description" text DEFAULT NULL, "dialogues_count" integer)')

		execOrWrite.call ('CREATE TABLE  IF NOT EXISTS "dialogue_links" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "origin_id" integer, "destination_id" integer, "priority" integer)')

		execOrWrite.call ('CREATE TABLE  IF NOT EXISTS "dialogues" ("id" integer NOT NULL PRIMARY KEY, "conversation_id" integer DEFAULT NULL, "dialoguetext" text DEFAULT NULL, "incid" integer DEFAULT NULL, "actor_id" integer DEFAULT NULL, "title" varchar DEFAULT NULL, "difficultypass" integer DEFAULT NULL, "sequence" text DEFAULT NULL, "conditionstring" text DEFAULT NULL, "userscript" text DEFAULT NULL, "origins_count" integer, "destinations_count" integer, "alternates_count" integer, "checks_count" integer)')

		execOrWrite.call ('CREATE TABLE  IF NOT EXISTS "modifiers" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "variable" varchar, "modification" varchar, "tooltip" varchar, "dialogue_id" integer, CONSTRAINT "fk_rails_cda90a9c98" FOREIGN KEY ("dialogue_id")  REFERENCES "dialogues" ("id"))')



			#inistialise counter
			numberOfdbEntriesMade=8;




	#Loop over the actors array, create a hash of relevant attributes (concatenate descriptions), stick them in the database
	if doActors then
		puts "Doing that 'Actors' table:"
		# add the HUB actor
		execOrWrite.call "INSERT INTO actors (id, name) values (?,?)", [0,"HUB"];
		numberOfdbEntriesMade+=1;
		# add actors from json
		for thisActor in dealogues["actors"] do
			actorAtts=[getCLAttribute(thisActor,"id"),getCLAttribute(thisActor,"Name")];
			# db.execute "INSERT INTO actors (id, name) values (?,?)", actorAtts;
			execOrWrite.call "INSERT INTO actors (id, name) values (?,?)", actorAtts;
			numberOfdbEntriesMade+=1;
		end
		puts "actors complete with #{numberOfdbEntriesMade} records so far"
	end
	if doVariables then
		puts "Doing that 'variables' table:"
		for thisVar in dealogues["variables"] do
			varAtts=[getCLAttribute(thisVar,"id"), getCLAttribute(thisVar,"Name"),getCLAttribute(thisVar,"Description"), getCLAttribute(thisVar,"Initial Value")]
			execOrWrite.call "INSERT INTO variables (id, name, description, initialvalue) values (?,?,?,?)", varAtts;
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

				execOrWrite.call "INSERT INTO conversations (id, title, description) VALUES (?,?,?)", conversationAtts;
				numberOfdbEntriesMade+=1;
			end

			#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
			if thisConvo.has_key?("dialogueEntries") then
				for thisLine in thisConvo["dialogueEntries"] do
					checkData=getIsCheckAttributes(thisLine)
					altData=getLineAlternatesArrays(thisLine)
					modData=getCheckModifiersArrays(thisLine);
					numberOfOutLinks=0
					if thisLine.has_key?("outgoingLinks") then
						numberOfOutLinks=thisLine["outgoingLinks"].length
					end
					if doDialogues then
						lineAtts=[]
						lineAtts=getArrayForDB(thisLine,listOfLineAtts);
						did=lineAtts[0]
						cid=lineAtts[1]
						#reassurance dot every 1000 records
						print '.' if ((cid % 1000) == 0)
						uid=getUniqID(cid,did)
						lineAtts.unshift(uid)
						lineAtts.push(numberOfOutLinks)
						if checkData then
							lineAtts.push(checkData.length)
						else
							lineAtts.push(0)
						end
						if altData then
							lineAtts.push(altData.length)
						else
							lineAtts.push(0)
						end

						execOrWrite.call "INSERT INTO dialogues (id, incid, conversation_id, title, dialoguetext, sequence, actor_id,difficultypass,conditionstring,userscript,origins_count, checks_count,alternates_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", lineAtts;
						numberOfdbEntriesMade+=1;
					end

					# insert checks and modifiers if the line has a check
					if checkData then
						if doChecks
							checkData.unshift(uid)
							checkData.unshift(nil)
							execOrWrite.call "INSERT INTO checks (id,dialogue_id, isred, difficulty, flagname, skilltype) VALUES (?,?,?,?,?,?)", checkData;
							numberOfdbEntriesMade+=1;

						end
						if doModifiers
							if !(modData.nil? or modData.empty?) then
								modData.each do |mod|
									mod.unshift(uid)
									execOrWrite.call "INSERT INTO modifiers (dialogue_id, variable, modification, tooltip) VALUES (?,?,?,?)", mod;
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
								execOrWrite.call "INSERT INTO alternates (id,dialogue_id, conditionstring, alternateline) VALUES (?,?,?,?)", alt;
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
								execOrWrite.call "INSERT INTO dialogue_links (id, origin_id, destination_id, priority) VALUES (?,?,?,?)", linkAtts #SQL insert
								numberOfdbEntriesMade+=1;
							end
						end
					end
				end
			end
		end
	end

	if outputSQLonly then
		puts "writing file"
		sqlText= 'BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" (
	"key"	varchar NOT NULL,
	"value"	varchar,
	"created_at"	datetime NOT NULL,
	"updated_at"	datetime NOT NULL,
	PRIMARY KEY("key")
);
CREATE TABLE IF NOT EXISTS "schema_migrations" (
	"version"	varchar NOT NULL,
	PRIMARY KEY("version")
);
INSERT INTO "ar_internal_metadata" VALUES ("environment","development","2021-04-26 11:13:37.141205","2021-05-07 22:53:46.315088");
INSERT INTO "schema_migrations" VALUES ("20210407205704");
INSERT INTO "schema_migrations" VALUES ("20210324025322");
INSERT INTO "schema_migrations" VALUES ("20210324033936");
INSERT INTO "schema_migrations" VALUES ("20210323222149");
INSERT INTO "schema_migrations" VALUES ("20210426100757");
INSERT INTO "schema_migrations" VALUES ("20210426100843");
INSERT INTO "schema_migrations" VALUES ("20210426100853");
INSERT INTO "schema_migrations" VALUES ("20210426105433");
INSERT INTO "schema_migrations" VALUES ("20210426110413");
INSERT INTO "schema_migrations" VALUES ("20210426112058");
INSERT INTO "schema_migrations" VALUES ("20210426122500");
INSERT INTO "schema_migrations" VALUES ("20210430001146");
INSERT INTO "schema_migrations" VALUES ("20210430001611");
INSERT INTO "schema_migrations" VALUES ("20210501110821");
INSERT INTO "schema_migrations" VALUES ("20210503124114");
INSERT INTO "schema_migrations" VALUES ("20210507221939");'
+sqlStatements.join("\n")+ "\nCOMMIT;"
		File.write(sqlfilen, sqlText)
	else
		puts "committing DB records"
		db.commit
	end

	puts "inserted #{numberOfdbEntriesMade} records into the #{ outputSQLonly ? "statements file" : "database" }";

	endtime=Time.now()
	timetaken=endtime - starttime
	puts outputSQLonly ? "statements file" : "database" + " creation took #{timetaken} seconds"


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
