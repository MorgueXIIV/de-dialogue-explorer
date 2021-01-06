#!/usr/bin/ruby -w
require 'rubygems';
require 'json';
# require 'tk';

json= File.read('Disco Elysium Cut.json');
dealogues=JSON.parse(json);
puts dealogues.size;
puts dealogues["conversations"][1]["fields"];
# dealogues.conversations[1];


# root = TkRoot.new { title "Hello, World!" }
# TkLabel.new(root) do
#    text 'Hello, World!'
#    pack { padx 15 ; pady 15; side 'left' }
# end
# Tk.mainloop
