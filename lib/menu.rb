require "ncurses"
require "users"
require "games"
require "fileutils"
require "scores"

module Menu
  def self.initncurses
    Signal.trap "WINCH" do
      resize
    end
    Ncurses.nonl
    Ncurses.cbreak
    Ncurses.stdscr.intrflush false
    Ncurses.noecho
    Ncurses.clear
    Ncurses.start_color
    Ncurses.init_pair 1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE
    Ncurses.init_pair 2, Ncurses::COLOR_YELLOW, Ncurses::COLOR_BLACK
    Ncurses.curs_set 0
  end

  def self.initialize
    Ncurses.initscr
    initncurses
    initwindows
    Users.load
    @user = ""
  end

  def self.initwindows
    @rows = Ncurses.getmaxy Ncurses.stdscr
    @cols = Ncurses.getmaxx Ncurses.stdscr
    header = Ncurses::WINDOW.new 1, 0, 0, 0
    menu = Ncurses::WINDOW.new @rows-4, @cols-2, 2, 1
    menu.keypad true
    footer = Ncurses::WINDOW.new 1, 0, @rows-1, 0
    header.attrset Ncurses.COLOR_PAIR(1) | Ncurses::A_BOLD
    footer.attrset Ncurses.COLOR_PAIR(1)
    Ncurses.scrollok menu, true
    @header_panel = Ncurses::Panel.new_panel header
    @footer_panel = Ncurses::Panel.new_panel footer
    @menu_panel = Ncurses::Panel.new_panel menu
  end

  def self.resize
    Ncurses.endwin
    Ncurses.refresh
    @rows = Ncurses.getmaxy Ncurses.stdscr
    @cols = Ncurses.getmaxx Ncurses.stdscr
    Ncurses.resizeterm @rows, @cols
    win = Ncurses::Panel.panel_window @header_panel
    Ncurses.wresize win, 1, @cols
    win.chgat -1, 0, 1, nil
    Ncurses::Panel.move_panel @footer_panel, @rows-1, 0
    win = Ncurses::Panel.panel_window @footer_panel
    Ncurses.wresize win, 1, @cols
    win.chgat -1, 0, 1, nil
    win = Ncurses::Panel.panel_window @menu_panel
    Ncurses.wresize win, @rows-4, @cols-2
    Ncurses::Panel.update_panels
    Ncurses.doupdate
  end

  def self.title(s)
    win = Ncurses::Panel.panel_window @header_panel
    win.clear
    win.printw " " + s
    win.chgat -1, 0, 1, nil
  end

  def self.status(s)
    win = Ncurses::Panel.panel_window @footer_panel
    win.clear
    win.printw " " + s
    win.chgat -1, 0, 1, nil
  end

  def self.user
    @user
  end

  def self.login
    title "Login"
    loggedin = false
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    Ncurses.curs_set 1
    until loggedin do
      Ncurses.echo
      win.printw "Name: "
      name = ""
      win.getstr name
      if name == "" then break end
      Ncurses.noecho
      win.printw "Password: "
      pass = ""
      win.getstr pass
      loggedin = Users.login(name, pass) == name
      unless loggedin then
        name = ""
        sleep 3
        win.printw "Login incorrect.\n"
        Ncurses.flushinp
      end
    end
    if loggedin then status "Logged in as " + name end
    Ncurses.curs_set 0
    name
  end

  def self.newuser
    title "New player"
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    created = false
    Ncurses.curs_set 1
    name = "????"
    Ncurses.echo
    until Users.checkname name do
      win.printw "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
      win.printw "Name: "
      getname = ""
      win.getstr getname
      name = getname
    end
    unless name == "" then
      until created do
        unless Users.exists? name then
          Ncurses.noecho
          win.printw "Password: "
          pass = ""
          win.getstr pass
          if pass == "" then
            name = ""
            break
          end
          win.printw "Retype password: "
          pass2 = ""
          win.getstr pass2
          if pass2 == "" then
            name = ""
            break
          end
          if pass == pass2
            Users.adduser name, pass
            Users.login name, pass
            created = true
          else
            name = ""
            win.printw "Sorry, passwords do not match.\n"
            Ncurses.flushinp
          end
        else
          win.printw "The player already exists.\n"
        end
      end
    end
    if created then status "Logged in as " + name end
    Ncurses.curs_set 0
    name
  end

  def self.change_password
    title "Change password"
    win = Ncurses::Panel.panel_window @menu_panel
    Ncurses.noecho
    win.clear
    changed = false
    Ncurses.curs_set 1
    until changed do
      win.printw "Blank entry aborts.\n"
      win.printw "Current password: "
      curpass = ""
      win.getstr curpass
      if curpass == "" then break end
      if Users.login(@user, curpass) == @user then
        win.printw "New password: "
        pass = ""
        win.getstr pass
        unless pass == "" then
          win.printw "Retype new password: "
          pass2 = ""
          win.getstr pass2
          if pass2 == "" then break end
          if pass == pass2
            changed = true
            Users.adduser @user, pass
          else
            win.printw "Sorry, passwords do not match.\n"
            Ncurses.flushinp
          end
        else
          break
        end
      else
        sleep 3
        win.printw "Password incorrect.\n"
        Ncurses.flushinp
      end
    end
    if changed then status "Password updated successfully" end
    Ncurses.curs_set 0
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
    #pagesize = @menu.rows - 4 # we're limited to 16 lines for now
    pagesize = 16
    chars = "abcdefghijklmnop"
    while !quit do
      Ncurses.halfdelay 50
      title "Watch games"
      count_games
      total = Games.games.length
      parsed = []
      active_games = []
      Games.games.each do |game|
        if game.attached then
          active_games += [game]
          parsed += [game.player.ljust(15) + game.game.ljust(15) + "(#{game.cols}x#{game.rows})".ljust(15) + "(idle " + mktime(game.idle.round) + ")"]
        end
      end
      active = parsed.length
      detached = total - active
      socketmenu = []
      if parsed.length > 0 then
        for i in offset..offset + pagesize - 1 do
          if i < active then
            socketmenu += [chars[i % pagesize,1] + " - " + parsed[i]]
          end
        end
      else
        socketmenu = ["There are no active games."]
      end
      sel = menu *(socketmenu + [
      "",
      ((active > 0) ? "Showing games #{offset+1}-#{(((offset+pagesize+1) > active) ? active : offset+pagesize+1)} of #{active} " : "") + ((detached > 0) ? "(#{detached} game#{detached > 1 ? "s" : ""} currently detached)" : ""),
      "Use uppercase to try to resize the terminal (recommended).",
      "Press any key to refresh. Auto refresh every five seconds.",
      "While watching, press q to return to the menu."])
      case sel
      when "<"[0], Ncurses::KEY_PPAGE: 
        offset -= pagesize
        if offset < 0 then offset = 0 end
      when ">"[0], Ncurses::KEY_NPAGE:
        if active > pagesize and offset+pagesize < active then
          offset += pagesize
          if offset > active-1 then offset -= pagesize end
        end
      when "A"[0].."P"[0]:
        if offset+sel-65 < active then
          Ncurses.def_prog_mode
          destroy
          puts "\033[8;#{active_games[offset+sel-65].rows};#{active_games[offset+sel-65].cols}t"
          Games.watchgame active_games[offset+sel-65].socket
          Ncurses.reset_prog_mode
          initncurses
          resize
        end
      when "a"[0].."p"[0]:
        if offset+sel-97 < active then
          Ncurses.def_prog_mode
          destroy
          Games.watchgame active_games[offset+sel-97].socket
          Ncurses.reset_prog_mode
          initncurses
        end
      when "q"[0], "Q"[0]: quit = true
      end
    end
    Ncurses.cbreak
  end

  def self.menu(*lines)
    Ncurses.noecho
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    lines.each do |option|
      win.printw option + "\n"
    end
    Ncurses::Panel.update_panels
    Ncurses.doupdate
    win.getch
  end

  def self.angbandmenu
    quit = false
    while !quit do
      case menu(
      "p - Play Angband",
      "e - Edit configuration file",
      "q - Quit")
      when "p"[0], "P"[0]:
        Games.populate
        Games.launchgame @user, "/usr/games/angband", "Angband", "-mgcu -u\"" + @user + "\"", [["SHELL", "/bin/sh"]]
      when "e"[0], "E"[0]:
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.nethackmenu
    quit = false
    while !quit do
      case menu(
      "p - Play NetHack",
      "e - Edit configuration file",
      "q - Quit")
      when "p"[0], "P"[0]:
        Games.populate
        Games.launchgame @user, "/usr/games/nethack", "NetHack", "-u \"" + @user + "\"", [["NETHACKOPTIONS", File.expand_path("rcfiles/" + @user + ".nethack")],["SHELL", "/bin/sh"]]
      when "e"[0], "E"[0]: Games.editrc @user, "nethack"
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.crawlmenu
    quit = false
    while !quit do
      count_games
      title "Crawl#{(@count > 0) ? ((Games.by_user[@user].key? "Crawl") ? " (running)" : "") : ""} "
      case menu(
      "p - Play Crawl",
      "e - Edit configuration file",
      "s - View scores",
      "q - Quit")
      when "p"[0], "P"[0]:
        #Ncurses.def_prog_mode
        destroy
        Games.launchgame @cols, @rows, @user, "/usr/games/crawl", "Crawl", [["SHELL", "/bin/sh"]], "-name", @user , "-rc", "rcfiles/" + @user + ".crawl", "-morgue", "crawl/morgue/#{@user}", "-macro", "crawl/macro/#{@user}/macro.txt"
        #Ncurses.reset_prog_mode
        initncurses
        resize
        Thread.new do
          Scores.updatecrawl
        end
      when "e"[0], "E"[0]:
        destroy
        Games.editrc @user, "crawl"
        initncurses
        resize
      when "s"[0], "S"[0]: crawlscores
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.crawlscores
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    scores = Scores::CrawlScores.new Scores::CRAWL_FILENAME
    quit = false
    parsed = []
    i = 1
    scores.data.each do |score|
      #parsed += ["#{(i).to_s.rjust(4)}. #{score["sc"].rjust(8)} #{score["name"].ljust(10)} #{score["char"]}-#{score["xl"].rjust(2, "0")} #{(score.has_key?("vmsg") ? score["vmsg"].chomp : score["tmsg"].chomp)} (#{score["place"]})"]
      parsed += ["#{(i).to_s.rjust(4)}. #{score["sc"].rjust(8)} #{score["name"].ljust(10)} #{score["char"]}-#{score["xl"].rjust(2, "0")} #{"(#{score["place"]})".ljust(9)} #{score["tmsg"].chomp}"]
      i += 1
    end
    offset = 0
    while !quit do
      title "Crawl scores"
      win.clear
      row = 0
      for i in offset..offset + win.getmaxy - 1 do
        if i < parsed.length then
          win.move row, 0
          if scores.data[i]["name"] == @user then
            win.attron Ncurses.COLOR_PAIR(2) | Ncurses::A_BOLD
          end
          win.printw parsed[i] + (row < win.getmaxy - 1 ? "\n" : "")
          win.attroff Ncurses.COLOR_PAIR(2) | Ncurses::A_BOLD
          row += 1
        end
      end
      Ncurses::Panel.update_panels
      Ncurses.doupdate
      case win.getch
      when "<"[0], Ncurses::KEY_PPAGE:
        offset -= win.getmaxy
        if offset < 0 then offset = 0 end
      when ">"[0], Ncurses::KEY_NPAGE:
        offset += win.getmaxy
        if offset > parsed.length - win.getmaxy - 1 then offset -= win.getmaxy end
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.gamesmenu
    quit = false
    while !quit do
      title "Games"
      count_games
      case menu(
      "a - Angband (coming soon)#{(@count > 0) ? ((Games.by_user[@user].key? "Angband") ? " (running)" : "") : ""} ",
      "c - Crawl Stone Soup 0.5.0#{(@count > 0) ? ((Games.by_user[@user].key? "Crawl") ? " (running)" : "") : ""} ", 
      "n - NetHack (coming soon)#{(@count > 0) ? ((Games.by_user[@user].key? "NetHack") ? " (running)" : "") : ""} ",
      "q - Quit")
      when "c"[0], "C"[0]: crawlmenu
      when "a"[0], "A"[0]: #angbandmenu
      when "n"[0], "N"[0]: #nethackmenu
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.count_games
    Games.populate
    unless @user == "" then
      if Games.by_user.key? @user then
        @count = Games.by_user[@user].length
      else
        @count = 0
      end
      status "Logged in as #{@user}#{(@count > 0) ? " - You have #{(@count == 1) ? "one" : @count} game#{@count > 1 ? "s" : ""} running" : ""}"
    end
  end

  def self.mainmenu
    quit = false
    while !quit do
      title "rlserver main menu"
      if @user == "" then
        status "Not logged in"
        case menu(
        "l - Login",
        "n - New player",
        "w - Watch",
        "q - Quit")
        when "l"[0], "L"[0]: @user = login
        when "n"[0], "N"[0]: @user = newuser
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      else
        count_games
        case menu(
        "g - Games",
        "w - Watch",
        "p - Change password",
        "q - Quit")
        when "p"[0], "P"[0]: change_password
        when "g"[0], "G"[0]: gamesmenu
        when "w"[0], "W"[0]: watchmenu
        when "q"[0], "Q"[0]: quit = true
        end
      end
    end
  end
    
  def self.destroy
    Signal.trap "WINCH" do end
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
  end
end
