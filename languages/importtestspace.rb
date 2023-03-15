
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

def evenMoreTables(dealogues,prefix,doActors=true)
	db = SQLite3::Database.open "JVArticy-#{prefix}.db"
	db.execute "create TABLE IF NOT EXISTS languageTest
		(articyID TEXT, type TEXT, type2 TEXT, language TEXT, string TEXT)"

	doStrings=true

	#inistialise counter
	numberOfdbEntriesMade=0;
	numberOfdbEntriesUpdated=0
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries
		dealogues = dealogues["mSource"]["mTerms"]
 	db.transaction

	if doStrings then
		for thisString in dealogues
			term=getCLAttribute(thisString, "Term")
			string = getCLAttribute(thisString, "Languages")[0]
			term=term.split("/")
			if term.length > 1 then
				type = term.shift
				type2 = term.pop
				articyID = term.join
			else
				type, type2, articyID = term.join()
			end
			stringAtts= [articyID,type,type2,prefix,string]
			# puts stringAtts.to_s
			db.execute "INSERT INTO languageTest (articyID, type, type2, language, string) values (?,?,?,?,?)", stringAtts;
			numberOfdbEntriesMade+=1;
		end

	end
	db.commit
	return numberOfdbEntriesMade
end

def createLangTables(dealogues,prefix,doActors=true)
	db = SQLite3::Database.open "JVArticy-#{prefix}.db"



	db.execute "create TABLE IF NOT EXISTS languageStrings
		(articyID TEXT, type TEXT, language TEXT, string TEXT)"

	doStrings=true

	#inistialise counter
	numberOfdbEntriesMade=0;
	numberOfdbEntriesUpdated=0
	#using transactions means the database is written to all at once making all these entries
	#which is MUCH much faster in SQLite than making a committed transation for each of the 10,000 + entries

		dealogues = dealogues["mSource"]["mTerms"]
 	db.transaction

	if doStrings then
		for thisString in dealogues
			term=getCLAttribute(thisString, "Term")
			string = getCLAttribute(thisString, "Languages")[0]
			term=term.split("/")
			type=term[0]
			articyID=term[1]
			stringAtts= [articyID,type,prefix,string]
			db.execute "INSERT INTO languageStrings (articyID, type, language, string) values (?,?,?,?)", stringAtts;
			numberOfdbEntriesMade+=1;
		end

	end
	db.commit
	return numberOfdbEntriesMade
end

def createLangStringDBs()
		# json= File.read('Disco Elysium Cut.json');

		filenames = ['DialoguesLockit',"GeneralLockit"]
		languages = [ ["ZH-sg", "Chinese"],["FR","French"] ,["DE","German"],["KO","Korean"] ,["PL","Polish"],["PT-br","Portuguese (Brazil)"],["RU","Russian"],["ES","Spanish"], ["JA","Japanese"],["TR","Turkish"],["ZH-hk","Traditional Chinese"]
]
	languages.each do | tuple |
		langname=tuple[1]
		langcode = tuple[0]
		filename=filenames[0] +langname+ ".json"
		json = File.read(filename);
		dealogues = JSON.parse(json);
		puts "json #{filename} parsed"

		numberofenters = createLangTables(dealogues,langcode,false)
		puts "database add: #{numberofenters}"


		filename=filenames[1] +langname+ ".json"
		dealogues = JSON.parse(json);
		puts "json #{filename} parsed"
		numberofenters = evenMoreTables(dealogues,langcode,false)
		puts "database add: #{numberofenters}"
	end

end


def getUniqID(cid, did)
	uid= (cid*10000) + did
	return uid
end

def createtranslationDBs()

		db = SQLite3::Database.open 'JVArticy.db'

			db.execute "create TABLE IF NOT EXISTS dialogue_translations
				(id integer primary key, dialogue_id int, language TEXT, string TEXT)"

			db.execute "create TABLE IF NOT EXISTS alternate_translations
						(id integer primary key, dialogue_id int, language TEXT, string TEXT)"

			db.execute "create TABLE IF NOT EXISTS modifier_translations
								(id integer primary key, dialogue_id int, language TEXT, string TEXT)"


		query="select JVdentries.id, JVdentries.conversationid,languageStrings.type, languageStrings.language, languageStrings.string from LanguageStrings inner join JVdentries on JVdentries.articyid=languageStrings.articyID"
		resultset=db.execute query
		db.transaction

		puts "number; #{resultset.length}"
		resultsperc = resultset.length / 30
		puts ".............................."

		dautoID = 0
		aautoID = 0
		mautoID = 0

		recordscount=0

		resultset.each do | result |
			resultID=getUniqID(result[1], result[0])
			# choose a database based on the type, but prefix by 4 because of the "tooltip3" syntax
			case result[2][0..3]
			when "Dial"
				execOrWrite "insert into dialogue_translations (id,dialogue_id,language,string) values (?,?,?,?)", [dautoID, resultID, result[3], result[4]]
				dautoID+=1
				recordscount+=1
			when "Alte"
				execOrWrite "insert into alternate_translations (id,dialogue_id,language,string) values (?,?,?,?)", [aautoID, resultID, result[3], result[4]]
				aautoID+=1
				recordscount+=1
			when "tool"
				execOrWrite "insert into modifier_translations (id,dialogue_id,language,string) values (?,?,?,?)", [mautoID, resultID, result[3], result[4]]
				mautoID+=1
				recordscount+=1
			else
				print "x"
				# puts "discarded #{result[2]} from #{result[3]} set"
			end
			#reassurance dot
			if recordscount % resultsperc == 0
				print "|"
			end
		end


		if @outputSQLonly then
			File.write(@sqlfilen, @sqlStatements.join("\n"))
			puts "\n #{recordscount} lines of SQL written to #{@sqlfilen}."
		else
			db.commit
			puts "\n #{recordscount} records added to  JVArticy.db."
		end

end

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


begin
	@sqlStatements=[]
	@outputSQLonly = true
	@sqlfilen = "sql.txt"
	# createLangStringDBs
	createtranslationDBs

# #error handling.
rescue SQLite3::Exception => e
    puts "there was a Database error: " + e.to_s;
ensure
    # close DB, success or fail
    $db.close if $db
end
