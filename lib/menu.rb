require "ui"
require "users"
require "games"
require "fileutils"

module Menu
  def self.initialize
    UI::initialize
    Games::initialize
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
      @menuwindow.clear
      @menuwindow.puts "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
      name = getstring "Name: "
    end
    unless name == "" or Users::exists name then
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
      #@menuwindow.puts "Player exists!\n"
      #@menuwindow.getc
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
    offset = 0
    sel = 0
    #pagesize = @menuwindow.rows - 4 # we're limited to 16 lines for now
    pagesize = 16
    chars = "abcdefghijklmnop"
    while !quit do
      Games::populate
      ttyrecmenu = []
      unless Games::games == [] then
        for i in offset..offset + pagesize - 1 do
          if i < Games::games.length then
            ttyrecmenu += [chars[i % 16,1] + " - " + Games::games[i].ttyrec]
          end
        end
      end
      sel = menu ttyrecmenu + ["", "> - Next page", "< - Previous page", "q - Quit", "Any key refreshes. Use uppercase to try to change size."]
      case sel
      when "<"[0]: 
        offset -= pagesize
        if offset < 0 then offset = 0 end
      when ">"[0]:
        offset += pagesize
        if offset > Games::games.length-1 then offset = Games::games.length-1 end
      when "A"[0].."P"[0]:
        if offset+sel-65 < Games::games.length then
          Games::ttyplay "inprogress/" + Games::games[offset+sel-65].ttyrec
        end
      when "a"[0].."p"[0]:
        if offset+sel-97 < Games::games.length then
          Games::ttyplay "inprogress/" + Games::games[offset+sel-97].ttyrec
        end
      when "q"[0], "Q"[0]: quit = true
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
      when "p"[0], "P"[0]:
        UI::endwin
        Games::play @user, "angband", "-mgcu -u\"" + @user + "\"", []
        #UI::initialize
      when "e"[0], "E"[0]:
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.nethackmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "p - Play NetHack", "e - Edit rc file", "q - Quit"]
      when "p"[0], "P"[0]:
        UI::endwin
        Games::play @user, "nethack", "-u \"" + @user + "\"", [["NETHACKOPTIONS", File.expand_path("rcfiles/" + @user + ".nethack")]]
        #UI::initialize
      when "e"[0], "E"[0]: Games::editrc @user, "nethack"
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.crawlmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "p - Play Crawl", "e - Edit rc file", "q - Quit"]
      when "p"[0], "P"[0]:
        UI::endwin
        Games::play @user, "crawl", "-name \"" + @user + "\" -rc \"rcfiles/" + @user + ".crawl\" -dir crawl", []
        #UI::initialize
      when "e"[0], "E"[0]: Games::editrc @user, "crawl"
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.gamesmenu
    quit = false
    while !quit do
      case menu ["Logged in as " + @user, "a - Angband", "c - Crawl", "n - NetHack", "q - Quit"]
      when "c"[0], "C"[0]: crawlmenu
      when "a"[0], "A"[0]: angbandmenu
      when "n"[0], "N"[0]: nethackmenu
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.mainmenu
    quit = false
    @menuwindow.clear
    while !quit do
      if @user == "" then
        case menu ["Welcome to rlserver!", "l - Login", "n - New player", "w - Watch", "q - Quit"]
        when "l"[0], "L"[0]: @user = login
        when "n"[0], "N"[0]: @user = newuser
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      else
        case menu ["Logged in as " + @user, "p - Change password", "g - Games", "w - Watch", "q - Quit"]
        when "p"[0], "P"[0]: change_password
        when "g"[0], "G"[0]: gamesmenu
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      end
    end
  end
    
  def self.destroy
    UI::destroy
  end
end
