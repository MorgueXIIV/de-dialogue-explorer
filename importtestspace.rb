
require 'json';
require 'sqlite3'

filenames=['Disco Elysium Cut.json','Disco Elysium Text Dump Game Version 1.0 (10_15_19) cut.json', '../discoelysium/Disco Elysium.json']
filenames=['Disco Elysium Text Dump Game Version 1.0 (10_15_19) cut.json']

def getCLAttribute(convoOrLine, attributeToGrab)
	if (convoOrLine.has_key?(attributeToGrab)) then
		return convoOrLine[attributeToGrab];
	elsif convoOrLine["fields"].is_a?(Hash) then
		if convoOrLine["fields"].has_key?(attributeToGrab) then
			return convoOrLine["fields"][attributeToGrab];
		else
			return "fieldshashnokey";
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
		return "fieldsnothashorarray"
	end
	return ""
end

def getsomeattributes(parsedobj,numberstocheck,attributes)
	numofattrsgot=0
	numberstocheck.each do |convoelem|
		dentriesarray=parsedobj["conversations"][convoelem]["dialogueEntries"]
		puts "numberofentries:#{dentriesarray.length} "
		numberstocheck.each do |lineelm|
			if lineelm<dentriesarray.length then
				linearray=dentriesarray[lineelm]
				attributes.each do |attr|
					# dentriesarray
					thing=getAttribute(linearray,attr)
					numofattrsgot+=1
					if thing.is_a?(String)
						print "#{attr}: #{thing[0,5]} "
					elsif thing.is_a?(Integer)
						print thing
					end
				end
			end
		end
	end
	return numofattrsgot
end


def getArrayForDB(hashToInspect, arrayOfAttributes)
	arrayOfData = []
	arrayOfAttributes.each do |attributeToGrab|
		arrayOfData.push(getCLAttribute(hashToInspect,attributeToGrab));
	end
	return arrayOfData;
end


def readfilescomparetimes(filename)
	attributes=['Title','Dialogue Text', 'Actor', 'outgoingLinks']
	numberstocheck=[1275,4,12,19,33,47,80,122,230,437]

	starttime=Time.now()
	json= File.read(filename);
	timeread = Time.now()
	readduration=timeread - starttime
	puts "Filename: #{filename}"
	dealogues=JSON.parse(json)
	endtime=Time.now()
	parseduration=endtime - timeread
	timetaken=endtime - starttime
	puts "total duration for #{filename}:#{timetaken}"
	puts "  (parse time: #{parseduration} read time; #{readduration})"
	starttimeforgrabs=Time.now()
	numbergot=getsomeattributes(dealogues,numberstocheck,attributes)
	grabbedtime=Time.now()-starttimeforgrabs
	puts "It took #{grabbedtime} seconds to get #{numbergot} (#{numberstocheck.length} sets of #{attributes.length}) attributes"
end

def stringMyArray(e,ds="")

	if e.length==2 then
		if e[0].nil?
			if e[1].nil?
				return "**NO RECORD**"
			else
				e[0]=""
			end
		end
		nom=e[0].split(":")[0]
		string=" **#{nom}:** #{e[1]} "
		return string
	end


	cid=e[0].to_s
	while cid.length<4
		cid="0"+cid
	end
	# id=e[1].to_s
	# while id.length<4
	# 	id="0"+id
	# end
	id="?" 
	# hackymethod to prevent different line numbers conflicting	...
	string="[id:#{cid}:#{id}][#{ds}] "
	if e[3].length<3 then
		string+= " #{e[2]}(#{e[3]}) "
	else
		nom=e[2].split(":")[0]
		string+=" **#{nom}:** #{e[3]} "
	end
	string+="(#{e[4]}to#{e[5]})"
	return string
end

def compareDBs()
	begin
		timey=Time.now()
		filename1="discobase10-15-2019-12-33-27-PM.db"
		# opens a DB file to search
		db2 = SQLite3::Database.open 'test.db'
		db1 = SQLite3::Database.open filename1
		query="SELECT conversationid,id,title, dialoguetext, actor, conversant FROM dentries"
		timey2=Time.now()-timey
		timey=Time.now()
		puts "executing query (#{timey2})"

		db1Dentries= db1.execute query;

		db2Dentries= db2.execute query;
		timey2=Time.now()-timey
		timey=Time.now()
		puts "q1 executed (#{timey2}) #{db1Dentries.length} results and #{db2Dentries.length} results"

		db1Dentries.reject!{|e| e[3].length<3 }
		db2Dentries.reject!{|e| e[3].length<3 }
		timey2=Time.now()-timey
		timey=Time.now()
		puts "hubs Rejected (#{timey2})  #{db1Dentries.length} results and #{db2Dentries.length} results"

		db1Dentries.map! { |e| stringMyArray(e, "TOK") }
		db2Dentries.map! { |e| stringMyArray(e, "TOK") }
		timey2=Time.now()-timey
		timey=Time.now()
		puts "arrays stringed (#{timey2})"

		difOld=db1Dentries - db2Dentries
		difNew=db2Dentries - db1Dentries
		difOld.map! { |e| e.gsub("TOK", "OLD") }
		difNew.map! { |e| e.gsub("TOK", "NEW") }
		difs=difOld+difNew
		timey2=Time.now()-timey
		timey=Time.now()
		puts "array difs found (#{timey2}) : #{difOld.length} old and #{difNew.length} new"

		difs.sort!
		timey2=Time.now()-timey
		timey=Time.now()
		puts "array sorted  (#{timey2})"

		# difs.map { |e| "id:#{e[0]}:#{e[1]} (#{e[2].split(":")[0]}) #{e[3]} (#{e[4]}to#{e[5]})" }

		 # isgroup, hascheck,sequence, hasalts,conditionstring, userscript, difficultypass
		datastr= difs.join("\n")
		timey2=Time.now()-timey
		timey=Time.now()
		puts "array #{difs.length} long Joined (#{timey2})"

		File.write("difs.md",datastr, mode: "w")
		timey2=Time.now()-timey
		timey=Time.now()
		puts "file written (#{timey2})"

	# #error handling.
	rescue SQLite3::Exception => e 
	    puts "there was a Database error: " + e.to_s;
	ensure
	    # close DB, success or fail
	    $db.close if $db
	end
end

def createArtTables(dealogues,prefix,doActors=true)
	db = SQLite3::Database.open 'ArtCompare.db'
	listOfLineAtts=["Articy Id","id","Title","Dialogue Text","Sequence","Actor","Conversant","conversationID", "DifficultyPass","isGroup","conditionsString","userScript"]
	listOfConvoAtts=["Articy Id","id", "Title", "Description","Actor","Conversant"]
	listOfLinkAtts=["originConversationID","originDialogueID","destinationConversationID","destinationDialogueID","isConnector","priority"]


	# to do; add routine to find how many lines the actor has
	db.execute "CREATE TABLE IF NOT EXISTS #{prefix}actors
	(id INT PRIMARY KEY, articyID TEXT, name TEXT, description LONGTEXT, talkativeness INT DEFAULT 0)";

	db.execute "CREATE TABLE IF NOT EXISTS #{prefix}dialogues
	(id INT PRIMARY KEY, articyID TEXT, title TEXT, description TEXT, actor INT, conversant INT);"

	db.execute "CREATE TABLE IF NOT EXISTS #{prefix}dentries
	(id INT,  articyID TEXT, title TEXT, dialoguetext TEXT, 
	actor INT, conversant INT, conversationid INT, difficultypass INT DEFAULT 0, 
		isgroup BOOL, hascheck BOOL DEFAULT false, sequence TEXT,
		hasalts BOOL DEFAULT false, conditionstring TEXT, userscript TEXT,
		FOREIGN KEY (conversationid) REFERENCES #{prefix}dialogues(id),
		FOREIGN KEY (actor) REFERENCES #{prefix}actors(id),
		FOREIGN KEY (conversant) REFERENCES #{prefix}actors(id),
		PRIMARY KEY(conversationid, id))";

		db.execute "CREATE TABLE IF NOT EXISTS #{prefix}dlinks
	(originconversationid INT, origindialogueid INT,
	destinationconversationid INT, destinationdialogueid INT,
	isConnector BOOL DEFAULT false, priority INT DEFAULT 2,
		FOREIGN KEY (originconversationid,origindialogueid) REFERENCES #{prefix}dentries(conversationid, id), 
		FOREIGN KEY (destinationconversationid,destinationdialogueid) REFERENCES #{prefix}dentries(conversationid, id))";
		# database table for links

		doDialogues=true
		doDentries=true
		doDlinks=true

	#inistialise counter
	numberOfdbEntriesMade=0;
	numberOfdbEntriesUpdated=0
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries
	db.transaction

		#Loop over the actors array, create a hash of relevant attributes (concatenate descriptions), stick them in the database
	if doActors then
		for thisActor in dealogues["actors"] do
			actorAtts=[getCLAttribute(thisActor,"id"),getCLAttribute(thisActor,"Articy Id"),getCLAttribute(thisActor,"Name")];
			aDescription = getCLAttribute(thisActor,"Description").to_s + ":";
			aDescription.concat(getCLAttribute(thisActor,"short_description").to_s + ":");
			aDescription.concat(getCLAttribute(thisActor,"LongDescription").to_s);
			actorAtts.push(aDescription);
			db.execute "INSERT INTO #{prefix}actors (id, articyID, name, description) values (?,?,?,?)", actorAtts;
			numberOfdbEntriesMade+=1;
		end

		# add the HUB actor
		db.execute "INSERT INTO #{prefix}actors (id, name, description) values (?,?,?)", [0,"HUB", "null actor added to allow inner joins"];
		numberOfdbEntriesMade+=1;
	end



	#loop over the conversations and enter them into the database
	for thisConvo in dealogues["conversations"] do
		if doDialogues then
			conversationAtts=[]
			conversationAtts=getArrayForDB(thisConvo,listOfConvoAtts);

			db.execute "INSERT INTO #{prefix}dialogues (articyID, id, title, description, actor, conversant) VALUES (?,?,?,?,?,?)", conversationAtts;
			numberOfdbEntriesMade+=1;
		end
		
		#SUB LOOP; for every conversation we also need to enter the many sub-lines of that conversation
		for thisLine in thisConvo["dialogueEntries"] do
			if doDentries then
				lineAtts=[]
				lineAtts=getArrayForDB(thisLine,listOfLineAtts);

				db.execute "INSERT INTO #{prefix}dentries (articyID, id, title, dialoguetext, sequence, actor, conversant, conversationid,difficultypass,isgroup,conditionstring,userscript) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", lineAtts;
				numberOfdbEntriesMade+=1;
			end
	

			#add ANOTHER loop which enters any outgoing links to the links database IF they exist;
			if doDlinks
				if thisLine.has_key?("outgoingLinks") then
					#linksdb loop
					for thisLink in thisLine["outgoingLinks"] do
						linkAtts=[] #create array
						linkAtts=getArrayForDB(thisLink,listOfLinkAtts);
						db.execute "INSERT INTO #{prefix}dlinks (originconversationid, origindialogueid, destinationconversationid, destinationdialogueid, isConnector, priority) VALUES (?,?,?,?,?,?)", linkAtts #SQL insert
						numberOfdbEntriesMade+=1;
					end
				end
			end
		end
	end
	db.commit
	return numberOfdbEntriesMade
end

def createArtComparisonDBs()
		# json= File.read('Disco Elysium Cut.json');
	json= File.read('DEJamaisVu.json');
	dealogues=JSON.parse(json);
	puts "json parsed"

	numberofenters = createArtTables(dealogues,"JV",true)
	puts "old database tables made: #{numberofenters}"
	
#	json= File.read('Disco Elysium4-20-cut.json');
#	dealogues=JSON.parse(json);
#	puts "json parsed"
#
#	numberofenters = createArtTables(dealogues,"NEW",false)
#	puts "new database tables made: #{numberofenters}"

end

def findBarksDumpResults()
	timey=Time.now()
		# filename1="discobase10-15-2019-12-33-27-PM.db"
		# opens a DB file to search
		db = SQLite3::Database.open 'test.db'
		# db1 = SQLite3::Database.open filename1
		# query="SELECT conversationid,id,title, dialoguetext, actor, conversant FROM dentries"
		query="select dentries.title, dentries.dialoguetext from dentries inner join dialogues on dentries.conversationid=dialogues.id where (dialogues.title like '%bark%') and (length(dentries.dialoguetext)>1);"

		puts "executing query" 
		puts "(#{query})"

		db1Dentries= db.execute query;

		timey2=Time.now()-timey
		timey=Time.now()
		puts "q1 executed (#{timey2}) #{db1Dentries.length} results"

		db1Dentries.map! { |e| stringMyArray(e) }
		timey2=Time.now()-timey
		timey=Time.now()
		difs=db1Dentries
		puts "arrays stringed (#{timey2})"
		difs.sort!
		timey2=Time.now()-timey
		timey=Time.now()
		puts "array sorted  (#{timey2})"

		datastr= difs.join("\n")
		timey2=Time.now()-timey
		timey=Time.now()
		puts "array #{difs.length} long Joined (#{timey2})"

		File.write("barks.md",datastr, mode: "w")
		timey2=Time.now()-timey
		timey=Time.now()
		puts "file written (#{timey2})"

end

def bidifarr(arr1, arr2)
	left=arr1-arr2
	right=arr2-arr1
	both=left+right
	return both
end

def comparestrings(str1,str2)
	if str1.nil?
		str1=""
	end
	if str2.nil?
		str2=""
	end
	str1.strip!
	str2.strip!
	wodif=bidifarr(str1.split(" "), str2.split(" ")).length
	chdif=bidifarr(str1.split(""), str2.split("")).length
	difs=wodif+(chdif/10)
	return difs
end

def createArticComparisonFromDB()
	query="select newdentries.title, newdentries.dialoguetext,olddentries.title, olddentries.dialoguetext from olddentries left join newdentries on newdentries.articyid=olddentries.articyid union select newdentries.title, newdentries.dialoguetext,olddentries.title, olddentries.dialoguetext from newdentries left join olddentries on newdentries.articyid=olddentries.articyid"

		db = SQLite3::Database.open 'ArtCompare.db'
		resultset=db.execute query
		puts "number; #{resultset.length}"
		resultset.reject!{|res| (res[1]==res[3]) or (res[1].to_s.length<2 and res[3].to_s.length<2)}
		resultset.sort_by!{|res| comparestrings(res[1],res[3]) }
		resultset.map!{|res| "*NEW:* #{stringMyArray(res[0,2])} \n*OLD:* #{stringMyArray(res[2,2])}" }
		resultset.reverse!
		datastr=resultset.join("\n\n")

		File.write("difsort.md",datastr, mode: "w")
end

begin
createArtComparisonDBs
	
# #error handling.
rescue SQLite3::Exception => e 
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    $db.close if $db
end

