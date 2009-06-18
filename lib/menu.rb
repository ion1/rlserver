require "ui"
require "users"
require "games"
require "fileutils"
require "scores"

module Menu
  def self.initialize
    UI.initialize
    Games.initialize
    Users.load
    @menuwindow = UI::Window.new 0, 0, 0, 0
    @user = ""
  end

  def self.login
    @menuwindow.clear
    UI.echo
    name = getstring "Name: "
    UI.noecho
    pass = getstring "Password: "
    Users.login name, pass
  end

  def self.getstring(query)
    @menuwindow.puts query
    @menuwindow.gets
  end

  def self.newuser
    name = "#this#is#invalid#"
    pass = ""
    pass2 = ""
    UI.echo
    until Users.checkname name do
      @menuwindow.clear
      @menuwindow.puts "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
      name = getstring "Name: "
    end
    unless name == "" or Users.exists name then
      UI.noecho
      pass = getstring "Password: "
      unless pass == "" then
        pass2 = getstring "Retype password: "
        Users.adduser name, pass, pass2
        Users.login name, pass
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
    UI.noecho
    @menuwindow.clear
    @menuwindow.puts "Changing password. Blank entry aborts.\n"
    pass = getstring "Current password: "
    if Users.login(@user, pass) == @user then
      pass = getstring "New password: "
      unless pass == "" then
        pass2 = getstring "Retype password: "
        Users.changepass name, pass, pass2
        #if Users.changepass name, pass, pass2 then
        #  @menuwindow.puts "Password updated successfully."
        #else
        #  @menuwindow.puts "The passwords do not match!"
        #end
        #Users.login name, pass
      end
    end
  end

  def self.mktime(time)
    hour = time / 3600
    min = time % 3600 / 60
    sec = time % 60
    hour.to_s.rjust(2,"0") + ":" + min.to_s.rjust(2,"0") + ":" + sec.to_s.rjust(2,"0")
  end

  def self.watchmenu
    quit = false
    offset = 0
    sel = 0
    #pagesize = @menuwindow.rows - 4 # we're limited to 16 lines for now
    pagesize = 16
    chars = "abcdefghijklmnop"
    while !quit do
      Games.populate
      ttyrecmenu = []
      unless Games.games == [] then
        for i in offset..offset + pagesize - 1 do
          if i < Games.games.length then
            ttyrecmenu += [chars[i % pagesize,1] + " - " + Games.games[i].player.ljust(15) + Games.games[i].game.ljust(15) + "(idle " + mktime(Games.games[i].idle.round) + ")"]
          end
        end
      end
      sel = menu ttyrecmenu + [
      "",
      "> - Next page",
      "< - Previous page",
      "q - Quit",
      "Press any key to refresh. Use uppercase to try to change size
(defaults to 80x24 at the moment)."]
      case sel
      when "<"[0]: 
        offset -= pagesize
        if offset < 0 then offset = 0 end
      when ">"[0]:
        if Games.games.length > pagesize and offset+pagesize < Games.games.length then
          offset += pagesize
          if offset > Games.games.length-1 then offset = Games.games.length-1 end
        end
      when "A"[0].."P"[0]:
        if offset+sel-65 < Games.games.length then
          puts "\033[8;#{Games.games[offset+sel-65].rows};#{Games.games[offset+sel-65].cols}t"
          Games.ttyplay "inprogress/" + Games.games[offset+sel-65].ttyrec
        end
      when "a"[0].."p"[0]:
        if offset+sel-97 < Games.games.length then
          Games.ttyplay "inprogress/" + Games.games[offset+sel-97].ttyrec
        end
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.menu(lines)
    UI.noecho
    @menuwindow.clear
    lines.each do |option|
      @menuwindow.puts option + "\n"
    end
    @menuwindow.getc
  end

  def self.angbandmenu
    quit = false
    while !quit do
      case menu [
      "Logged in as " + @user,
      "p - Play Angband",
      "e - Edit rc file",
      "q - Quit"]
      when "p"[0], "P"[0]:
        Games.populate
        if Games.index(@user, "Angband") >= 0 then
          Process.kill("HUP", Games.games[Games.index(@user, "Angband")].pid)
        end
        UI.endwin
        Games.ttyrec @user, "/usr/games/angband", "Angband", "-mgcu -u\"" + @user + "\"", []
        #UI.initialize
      when "e"[0], "E"[0]:
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.nethackmenu
    quit = false
    while !quit do
      case menu [
      "Logged in as " + @user,
      "p - Play NetHack",
      "e - Edit rc file",
      "q - Quit"]
      when "p"[0], "P"[0]:
        Games.populate
        if Games.index(@user, "NetHack") >= 0 then
          Process.kill("HUP", Games.games[Games.index(@user, "Nethack")].pid)
        end
        UI.endwin
        Games.ttyrec @user, "/usr/games/nethack", "NetHack", "-u \"" + @user + "\"", [["NETHACKOPTIONS", File.expand_path("rcfiles/" + @user + ".nethack")]]
        #UI.initialize
      when "e"[0], "E"[0]: Games.editrc @user, "nethack"
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.crawlmenu
    quit = false
    while !quit do
      case menu [
      "Logged in as " + @user,
      "p - Play Crawl",
      "e - Edit rc file",
      "q - Quit"]
      when "p"[0], "P"[0]:
        Games.populate
        if Games.index(@user, "Crawl") >= 0 then
          Process.kill("HUP", Games.games[Games.index(@user, "Crawl")].pid)
        end
        UI.endwin
        Games.ttyrec @user, "/usr/games/crawl/crawl", "Crawl", "-name \"" + @user + "\" -rc \"rcfiles/" + @user + ".crawl\" -dir crawl", []
        Thread.new do
          Scores.updatecrawl
        end
        #UI.initialize
      when "e"[0], "E"[0]: Games.editrc @user, "crawl"
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.gamesmenu
    quit = false
    while !quit do
      case menu [
      "Logged in as " + @user, 
      "a - Angband (coming soon)", 
      "c - Crawl SS 0.5", 
#      "C - Crawl SS 0.3.3", 
      "n - NetHack (coming soon)", "q - Quit"]
      when "c"[0], "C"[0]: crawlmenu
      when "a"[0], "A"[0]: #angbandmenu
      when "n"[0], "N"[0]: #nethackmenu
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.mainmenu
    quit = false
    @menuwindow.clear
    while !quit do
      if @user == "" then
        case menu [
        "Welcome to rlserver!",
        "l - Login",
        "n - New player",
        "w - Watch",
        "q - Quit"]
        when "l"[0], "L"[0]: @user = login
        when "n"[0], "N"[0]: @user = newuser
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      else
        case menu [
        "Logged in as " + @user,
        "g - Games",
        "w - Watch",
        "p - Change password",
        "q - Quit"]
        when "p"[0], "P"[0]: change_password
        when "g"[0], "G"[0]: gamesmenu
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      end
    end
  end
    
  def self.destroy
    UI.destroy
  end
end
