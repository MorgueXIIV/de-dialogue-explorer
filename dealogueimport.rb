#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
# require 'tk';

json= File.read('Disco Elysium Cut.json');
dealogues=JSON.parse(json);
# puts dealogues.size;
puts dealogues["conversations"][1]["fields"];

puts "conversations 1 fields class" + dealogues["conversations"][1]["fields"].class.to_s;
puts "conversations 1 fields Title class" + dealogues["conversations"][1]["fields"]["Title"].class.to_s;
puts "conversations 1 ID class" + dealogues["conversations"][1]["id"].class.to_s;


# root = TkRoot.new { title "Hello, World!" }
# TkLabel.new(root) do
#    text 'Hello, World!'
#    pack { padx 15 ; pady 15; side 'left' }
# end
# Tk.mainloop
