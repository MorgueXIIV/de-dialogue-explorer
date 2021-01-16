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


	# opens a DB file, Creates our database tables	
	db = SQLite3::Database.open 'test.db'

	db.execute """CREATE TABLE IF NOT EXISTS dialogues
	(id INT PRIMARY KEY, title TEXT, description TEXT, actor INT, conversant INT)""";

	db.execute """CREATE TABLE IF NOT EXISTS actors
	(id INT PRIMARY KEY, name TEXT, description LONGTEXT)""";

	db.execute """CREATE TABLE IF NOT EXISTS dentries
	(id INT, title TEXT, dialoguetext TEXT, 
	actor INT, conversant INT, conversationid INT,
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

# these strings represent the various keys we need from each hash to fed into the database
# stored in an ITERABLE array so we can easily use them in a method for a nice DRY grab of data to insert
	listOfLineAtts=["id","Title","Dialogue Text","Sequence","Actor","Conversant","conversationID","isGroup","conditionsString","userScript"]
	listOfConvoAtts=["id", "Title", "Description","Actor","Conversant"]
	listOfLinkAtts=["originConversationID","originDialogueID","destinationConversationID","destinationDialogueID","isConnector","priority"]

#inistialise counter
	numberOfdbEntriesMade=0;
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a comitted transation for each othe 10,000 + entries
	db.transaction

	#Loop over the actors array, create a hash of relevant attributes (concatenate descriptions), stick them in the database
	for thisActor in dealogues["actors"] do
		actorAtts=[getCLAttribute(thisActor,"id"),getCLAttribute(thisActor,"Name")];
		aDescription = getCLAttribute(thisActor,"Description").to_s + ":";
		aDescription.concat(getCLAttribute(thisActor,"short_description").to_s + ":");
		aDescription.concat(getCLAttribute(thisActor,"LongDescription").to_s);
		actorAtts.push(aDescription);
		db.execute "INSERT INTO actors (id, name, description) values (?,?,?)", actorAtts;
		numberOfdbEntriesMade+=1;
	end

	#loop over the conversations and enter them into the database
	for thisConvo in dealogues["conversations"] do

		conversationAtts=[]
		conversationAtts=getArrayForDB(thisConvo,listOfConvoAtts);

		db.execute "INSERT INTO dialogues (id, title, description, actor, conversant) VALUES (?,?,?,?,?)", conversationAtts;
		numberOfdbEntriesMade+=1;
		#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
		for thisLine in thisConvo["dialogueEntries"] do

			lineAtts=[]
			lineAtts=getArrayForDB(thisLine,listOfLineAtts);

			db.execute "INSERT INTO dentries (id, title, dialoguetext, sequence, actor, conversant, conversationid,isgroup,conditionstring,userscript) VALUES (?,?,?,?,?,?,?,?,?,?)", lineAtts;
			numberOfdbEntriesMade+=1;

			#add ANOTHER loop which enters any outgoing links to the links database IF they exist;
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
	db.commit
	puts "inserted #{numberOfdbEntriesMade} records into the databases";
rescue SQLite3::Exception => e 
    puts "there was a Database Creation error: " + e.to_s;
    #Rollback prevents partially complete data sets being inserted
    #minimising re-run errors after an exception is raised mid records
    db.rollback

rescue JSON::UnparserError => e 
    puts "there was a JSON Parse error: " + e.to_s;
ensure
    # close DB, success or fail
    db.close if db
end

