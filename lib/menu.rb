require "ui"
require "users"
require "games"
require "fileutils"

module Menu
  def self.initialize
    UI::initialize
    Users::load
    @menuwindow = UI::Window.new 0, 0, 0, 0
    @user = ""
  end

  def self.login
    @menuwindow.clear
    UI::echo
    name = getstring "Name: "
    UI::noecho
    pass = getstring "Password: "
    Users::login name, pass
  end

  def self.getstring(query)
    @menuwindow.puts query
    @menuwindow.gets
  end

  def self.newuser
    name = "#this#is#invalid#"
    pass = ""
    pass2 = ""
    UI::echo
    until Users::checkname name do
      #@menuwindow.clear
      @menuwindow.puts "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
      name = getstring "Name: "
    end
    unless name == "" then
      unless Users::exists name then
        UI::noecho
        pass = getstring "Password: "
        unless pass == "" then
          pass2 = getstring "Retype password: "
          Users::adduser name, pass, pass2
          Users::login name, pass
        else
          name = ""
        end
      else
        @menuwindow.puts "Player exists!\n"
        #@menuwindow.getc
        name = ""
      end
    else
      name = ""
    end
  end

  def self.change_password
    UI::noecho
    @menuwindow.clear
    @menuwindow.puts "Changing password. Blank entry aborts.\n"
    pass = getstring "Current password: "
    if Users::login(@user, pass) == @user then
      pass = getstring "New password: "
      unless pass == "" then
        pass2 = getstring "Retype password: "
        Users::changepass name, pass, pass2
        #if Users::changepass name, pass, pass2 then
        #  @menuwindow.puts "Password updated successfully."
        #else
        #  @menuwindow.puts "The passwords do not match!"
        #end
        #Users::login name, pass
      end
    end
  end

  def self.watchmenu
    quit = false
    start = 0
    sel = 0
    chars = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p"]
    while !quit do
      ttyrecs = []
      Dir.foreach("inprogress") do |f|
        unless f == "." or f == ".." then
          ttyrecs += [f]
        end
      end
      ttyrecmenu = []
      unless ttyrecs == [] then
        for i in start..start+15 do
          if i < ttyrecs.length then
            ttyrecmenu += [chars[i % 16] + " - " + ttyrecs[i]]
          end
        end
      end
      sel = menu ttyrecmenu + ["", "> - Next page", "< - Previous page", "Any key refreshes", "q - Quit"]

      case sel
      when 81, 113: quit = true
      when 60: 
        start -= 16
        if start < 0 then start = 0 end
      when 62:
        start += 16
        if start > ttyrecs.length-1 then start = ttyrecs.length-1 end
      when 65..84:
        if start+sel-65 < ttyrecs.length then
          Games::ttyplay "inprogress/" + ttyrecs[start+sel-65]
        end
      when 97..116:
        if start+sel-97 < ttyrecs.length then
          Games::ttyplay "inprogress/" + ttyrecs[start+sel-97]
        end
      end
    end
  end

  def self.menu(lines)
    UI::noecho
    @menuwindow.clear
    lines.each do |option|
      @menuwindow.puts option + "\n"
    end
    @menuwindow.getc
  end

  def self.angbandmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "p - Play Angband", "e - Edit rc file", "q - Quit"]
      when 80, 112:
        UI::endwin
        Games::play @user, "angband", "-mgcu -u\"" + @user + "\"", []
      when 69, 101:
      when 81, 113: quit = true
      end
    end
  end

  def self.nethackmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "p - Play NetHack", "e - Edit rc file", "q - Quit"]
      when 80, 112:
        UI::endwin
        Games::play @user, "nethack", "-u \"" + @user + "\"", [["NETHACKOPTIONS", File.expand_path("rcfiles/" + @user + ".nethack")]]
      when 69, 101: Games::editrc @user, "nethack"
      when 81, 113: quit = true
      end
    end
  end

  def self.crawlmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "p - Play Crawl", "e - Edit rc file", "q - Quit"]
      when 80, 112:
        UI::endwin
        Games::play @user, "crawl", "-name \"" + @user + "\" -rc \"rcfiles/" + @user + ".crawl\" -dir crawl", []
      when 69, 101: Games::editrc @user, "crawl"
      when 81, 113: quit = true
      end
    end
  end

  def self.gamesmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "a - Angband", "c - Crawl", "n - NetHack", "q - Quit"]
      when 81, 113: quit = true
      when 67, 99: crawlmenu
      when 65, 97: angbandmenu
      when 78, 110: nethackmenu
      end
    end
  end

  def self.mainmenu
    quit = false
    @menuwindow.clear
    while !quit do
      if @user == "" then
        case menu ["Welcome to rlserver!", "l - Login", "n - New player", "w - Watch", "q - Quit"]
        when 76, 108: @user = login
        when 78, 110: @user = newuser
        when 87, 119: watchmenu
        when 81, 113: quit = true
        end
      else
        case menu ["Logged in as " + @user, "p - Change password", "g - Games", "w - Watch", "q - Quit"]
        when 80, 112: change_password
        when 71, 103: gamesmenu
        when 87, 119: watchmenu
        when 81, 113: quit = true
        end
      end
    end
  end
    
  def self.destroy
    UI::destroy
  end
end
