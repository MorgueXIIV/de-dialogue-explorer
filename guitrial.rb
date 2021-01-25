# require 'gtk3'

# class RubyApp < Gtk::Window
# 		def initialize
# 			super
# 			set_title "GTK Ruby Demo"
# 			signal_connect "destroy" do
# 				Gtk.main_quit
# 		end
		
# 		set_default_size
# 		set_window_position Gtk::Window::Position::CENTER

# 		show
# 	end
# end

# Gtk.init
# 	window = RubyApp.new
# Gtk.main

require 'tk'

class Gui
	root = TkRoot.new {title "My first Ruby GUI"}
	root['geometry'] = '400x200'
	label = TkLabel.new {text 'This is my first label'}
end

Gui.new
Tk.mainloop