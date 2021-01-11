#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
require 'sqlite3'
# require 'tk';


def idConvo(idNumber=1, dialoguefile=dealogues)
	return dialoguefile["conversations"][idNumber-1];
end

def idConvoLine(idNumber, convo)
	return convo["dialogueEntries"][idNumber];
end

def getCLAttribute(convoOrLine, attributeToGrab)
	if (convoOrLine.has_key?(attributeToGrab)) then
		return convoOrLine[attributeToGrab];
	else
		if convoOrLine["fields"].has_key?(attributeToGrab) then
			return convoOrLine["fields"][attributeToGrab];
		else
			return "bad attribute bro";
		end
	end
end


json= File.read('Disco Elysium Cut.json');
dealogues=JSON.parse(json);


puts "conversations dialogueEntries fields 562 fields class" + dealogues["conversations"][562]["dialogueEntries"].class.to_s;
#puts "conversations dialogueEntries fields 562 fields 2 Title; " + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"];
puts "conversations dialogueentries fields title class" + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"].class.to_s;
convoID=563;
lineID=6;
thisConvo=idConvo(convoID, dealogues);
thisLine=idConvoLine(lineID, thisConvo);
#puts "conversation 563, entry 6" + thisLine.to_s;
puts thisLine.to_s;
puts "Convo: " + convoID.to_s + " line ID: " + lineID.to_s;
puts "Title:" + getCLAttribute(thisLine, "Title").to_s;
puts "text:" + getCLAttribute(thisLine, "Dialogue Text").to_s;
puts "convo/line IDs:" + getCLAttribute(thisLine, "conversationID").to_s + " " + getCLAttribute(thisLine, "id").to_s;

begin
	db = SQLite3::Database.open 'test.db'
	db.execute "CREATE TABLE IF NOT EXISTS dialogues(id INT, title TEXT, description TEXT, actor INT, conversant INT)";   
	db.execute "INSERT INTO dialogues (id, title, description, actor, conversant) VALUES (?,?,?,?,?)", getCLAttribute(thisConvo, "id"), getCLAttribute(thisConvo, "Title"), getCLAttribute(thisConvo, "Description"), getCLAttribute(thisConvo, "Actor"), getCLAttribute(thisConvo, "Conversant")

rescue SQLite3::Exception => e 
    puts "there was an error" + e.to_s;
ensure
    # If the whole application is going to exit and you don't
    # need the database at all any more, ensure db is closed.
    # Otherwise database closing might be handled elsewhere.
    db.close if db
end

# root = TkRoot.new { title "Hello, World!" }
# TkLabel.new(root) do
#     #text dealogues["conversations"][562]["fields"].to_s;
# 	text "conversations dialogueEntries fields 562 fields class \n" + dealogues["conversations"][562]["dialogueEntries"].class.to_s;
# 	text "conversations dialogueEntries fields 562 fields 2 Title; \n" + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"];
# 	text "conversations dialogueentries fields title class \n" + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"].class.to_s;
# 	thisConvo=IDConvo(563, dealogues);
# 	text "conversation 563, entry 6 \n" + IDConvoLine(6, thisConvo).to_s;

#     pack { padx 15 ; pady 15; side 'left' }
# end
# Tk.mainloop

