#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
# require 'tk';


def IDConvo(idNumber=1, dialoguefile=dealogues)
	return dialoguefile["conversations"][idNumber-1];
end

def IDConvoLine(idNumber, convo)
	return convo["dialogueEntries"][idNumber];
end

json= File.read('Disco Elysium Cut.json');
dealogues=JSON.parse(json);
# puts dealogues.size;
puts dealogues["conversations"][562]["fields"];

puts "conversations dialogueEntries fields 562 fields class" + dealogues["conversations"][562]["dialogueEntries"].class.to_s;
puts "conversations dialogueEntries fields 562 fields 2 Title; " + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"];
puts "conversations dialogueentries fields title class" + dealogues["conversations"][562]["dialogueEntries"][2]["fields"]["Title"].class.to_s;
thisConvo=IDConvo(563, dealogues);
puts "conversation 563, entry 6" + IDConvoLine(6, thisConvo).to_s;





# root = TkRoot.new { title "Hello, World!" }
# TkLabel.new(root) do
#    text 'Hello, World!'
#    pack { padx 15 ; pady 15; side 'left' }
# end
# Tk.mainloop