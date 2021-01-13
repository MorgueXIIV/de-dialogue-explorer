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

#reads in and parses the JSON
#THIS NEEDS ERROR HANDLING?
json= File.read('Disco Elysium Cut.json');
dealogues=JSON.parse(json);

begin
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
  	PRIMARY KEY(id, conversationid))";
  	# TODO: database table for links

# these keys represent the various attributes we need from each hash to fed into the database
	listOfLineAtts=["id","Title","Dialogue Text","Sequence","Actor","Conversant","conversationID","isGroup","conditionsString","userScript"]
	listOfConvoAtts=["id", "Title", "Description","Actor","Conversant"]

#inistialise counter
	numberOfdbEntriesMade=0;
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite
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
		#REFACTOR POTENTIAL CODE 001
		listOfConvoAtts.each do |attributeToGrab|
				conversationAtts.push(getCLAttribute(thisConvo,attributeToGrab));
			end
		db.execute "INSERT INTO dialogues (id, title, description, actor, conversant) VALUES (?,?,?,?,?)", conversationAtts;
		numberOfdbEntriesMade+=1;
		#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
		for thisLine in thisConvo["dialogueEntries"] do
			lineAtts=[]
			# REFACTOR POTENTIAL CODE 001
			listOfLineAtts.each do |attributeToGrab|
				lineAtts.push(getCLAttribute(thisLine,attributeToGrab));
			end
			db.execute "INSERT INTO dentries (id, title, dialoguetext, sequence, actor, conversant, conversationid,isgroup,conditionstring,userscript) VALUES (?,?,?,?,?,?,?,?,?,?)", lineAtts;
			numberOfdbEntriesMade+=1;
			#TODO: add ANOTHER loop which enters any outgoing links to the links database.
			if thisLine.has_key("outgoingLinks") then
				#linksdb loop
				for thisLink in thisLine["outgoingLinks"] do
					linkAttArray=[] #TODO create array
					db.execute "", linkAttArray #TODO SQL insert
					numberOfdbEntriesMade+=1;
			end
		end
	end
	db.commit
	puts "inserted #{numberOfdbEntriesMade} records into the databases";
rescue SQLite3::Exception => e 
    puts "there was an error: " + e.to_s;
    db.rollback
ensure
    # If the whole application is going to exit and you don't
    # need the database at all any more, ensure db is closed.
    # Otherwise database closing might be handled elsewhere.
    db.close if db
end

