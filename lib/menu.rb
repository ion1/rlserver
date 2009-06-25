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
    Ncurses.init_pair 3, Ncurses::COLOR_BLACK, Ncurses::COLOR_BLACK
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
    Ncurses.stdscr.clear
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

  def self.aputs(win, s)
    codes = {
      "b" => Ncurses::A_BOLD,
      "r" => Ncurses::A_REVERSE,
      "n" => Ncurses::A_NORMAL,
      "s" => Ncurses::A_STANDOUT}
      control = false
      attrs = ""
      s.each_char do |c|
        if control then
          control = false
          if codes.key? c then
            if attrs.include? c
              win.attroff codes[c]
              attrs.delete! c
            else
              win.attron codes[c]
              attrs += c
            end
          elsif
            case c when "0".."9":
              if attrs.include? c
                win.attroff Ncurses.COLOR_PAIR c.to_i
                attrs.delete! c
              else
                win.attron Ncurses.COLOR_PAIR c.to_i
                attrs += c
              end
            end
          end
      else
        (control = (c == "$")) ? () : (win.addch c[0])
      end
    end
  end

  def self.title(s)
    win = Ncurses::Panel.panel_window @header_panel
    win.clear
    win.chgat -1, 0, 1, nil
    aputs win, " " + s
  end

  def self.status(s)
    win = Ncurses::Panel.panel_window @footer_panel
    win.clear
    win.chgat -1, 0, 1, nil
    aputs win, " " + s
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
    win.printw "Alphanumerics, spaces, dashes and underscores only.\n"
    win.printw "Blank entry aborts.\n"
    until Users.checkname name do
      win.printw "Name: "
      getname = ""
      win.getstr getname
      name = getname
      if Users.exists? name then
        win.printw "The player already exists.\n"
        name = "????"
      elsif !Users.checkname name
        win.printw "Alphanumerics, spaces, dashes and underscores only.\n"
      end
    end
    unless name == "" then
      until created do
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
          win.printw "Sorry, passwords do not match.\n"
          Ncurses.flushinp
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
  
  def self.menu(clear, *choices)
    Ncurses.noecho
    win = Ncurses::Panel.panel_window @menu_panel
    if clear then win.clear end
    row = win.getcury
    choices.each do |s|
      win.move row, 0
      if s[0] == nil then
        aputs win, "    "
      else
        aputs win, "#{s[0][0, 1]} - "
      end
      aputs win, s[1]
      row += 1
    end
    Ncurses::Panel.update_panels
    Ncurses.doupdate
    ch = win.getch
    case ch when 0..255 then
      ch.chr
    else
      ch
    end
  end

  def self.crawlscores
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    scores = Scores::CrawlScores.new Scores::CRAWL_FILENAME
    quit = false
    pretty = []
    i = 1
    scores.data.each do |score|
      pretty += ["%4u. %8s %-10s %s-%02u %-7s %s" % [i, score["sc"], score["name"], score["char"], score["xl"], "(#{score["place"]})", score["tmsg"].chomp]]
      i += 1
    end
    offset = 0
    while !quit do
      title "Crawl scores"
      status "Press $bPage Up$b and $bPage Down$b to scroll, $bq$b to go back"
      win.clear
      row = 0
      offset.upto(offset + win.getmaxy - 1) do |i|
        if i < pretty.length then
          win.move row, 0
          a = (scores.data[i]["name"] == @user) ? "$b$2" : ""
          aputs win, a + pretty[i] + a
          row += 1
        end
      end
      Ncurses::Panel.update_panels
      Ncurses.doupdate
      case win.getch
      when Ncurses::KEY_PPAGE:
        offset -= win.getmaxy
        if offset < 0 then offset = 0 end
      when Ncurses::KEY_NPAGE:
        offset += win.getmaxy
        if offset >= pretty.length then offset -= win.getmaxy end
      when "q"[0], "Q"[0]: quit = true
      end
    end
  end

  def self.count_games
    @count = 0
    unless @user == "" then
      Games.populate
      if Games.by_user.key? @user then
        @count = Games.by_user[@user].length
      end
      "Logged in as $b#{@user}$b#{(@count > 0) ? " - You have #{(@count == 1) ? "one" : @count} game#{@count > 1 ? "s" : ""} running" : ""}"
    else
      "Not logged in" 
    end
  end

  def self.mktime(time)
    hour = time / 3600
    min = time % 3600 / 60
    sec = time % 60
    "%02d:%02d:%02d" % [hour, min, sec]
  end

  def self.watchmenu
    win = Ncurses::Panel.panel_window @menu_panel
    quit = false
    offset = 0
    sel = 0
    chars = "abcdefghijklmnop"
    while !quit do
      pagesize = win.getmaxy - 6
      if pagesize > 16 then pagesize = 16 end
      Ncurses.halfdelay 100
      title "Watch games"
      status "Press $bPage Up$b and $bPage Down$b to scroll, $bq$b to go back"
      Games.populate
      pretty = []
      active_games = []
      detached_games = []
      socketmenu = []
      Games.games.each do |game|
        if game.attached then
          active_games += [game]
        else
          detached_games += [game]
        end
      end
      active = active_games.length
      detached = detached_games.length
      total = active_games + detached_games
      total.each do |game|
        pretty += ["#{game.attached ? "" : "$b$3"}%-14s%-14s%-14s(idle %s)#{game.attached ? "" : "$b$3"}" % [game.player, game.game, "#{game.cols}x#{game.rows}", mktime(game.idle.round)]]
      end
      win.clear
      aputs win,
        "Use uppercase to try to resize the terminal (recommended).\n" +
        "Press any key to refresh. Auto refresh every ten seconds.\n" +
        "While watching, press q to return to the menu.\n\n"
      if total.length > 0 then
        aputs win, "Showing games #{offset+1}-#{(((offset+pagesize) > total.length) ? total.length : offset+pagesize)} of #{total.length} ("
        if active > 0 then
          aputs win, "#{active} active#{(detached > 0 ? ", " : "")}"
        end
        if detached > 0 then
          aputs win, "$b$3#{detached} detached$3$b"
        end
        aputs win, ")."
        offset.upto(offset + pagesize - 1) do |i|
          if i < total.length then
            socketmenu += [[total[i].attached ? chars[i % pagesize, 1] : nil, pretty[i]]]
          end
        end
        items = socketmenu.length
      else
        aputs win, "There are no games running."
      end
      win.printw "\n\n"
      sel = menu false, *socketmenu
      case sel
      when Ncurses::KEY_PPAGE: 
        offset -= pagesize
        if offset < 0 then offset = 0 end
      when Ncurses::KEY_NPAGE:
        offset += pagesize
        if offset >= total.length then offset -= pagesize end
      when "a".."p":
        sel = offset + sel[0]-97
        if sel < active then
          Ncurses.def_prog_mode
          destroy
          Games.watchgame active_games[sel].socket
          initncurses
          Ncurses.reset_prog_mode
          resize
        end
      when "A".."P":
        sel = offset + sel[0] - 65
        if sel < active then
          Ncurses.def_prog_mode
          destroy
          puts "\033[8;#{active_games[sel].rows};#{active_games[sel].cols}t"
          Games.watchgame active_games[sel].socket
          initncurses
          Ncurses.reset_prog_mode
          resize
        end
      when "q", "Q": quit = true
      end
    end
    Ncurses.cbreak
  end

#  def self.angbandmenu
#    quit = false
#    while !quit do
#      case menu(
#      "p - Play Angband",
#      "e - Edit configuration file",
#      "q - Quit")
#      when "p"[0], "P"[0]:
#        Games.populate
#        Games.launchgame @user, "/usr/games/angband", "Angband", "-mgcu -u\"" + @user + "\"", [["SHELL", "/bin/sh"]]
#      when "e"[0], "E"[0]:
#      when "q"[0], "Q"[0]: quit = true
#      end
#    end
#  end
#
#  def self.nethackmenu
#    quit = false
#    while !quit do
#      case menu(
#      "p - Play NetHack",
#      "e - Edit configuration file",
#      "q - Quit")
#      when "p"[0], "P"[0]:
#        Games.populate
#        Games.launchgame @user, "/usr/games/nethack", "NetHack", "-u \"" + @user + "\"", [["NETHACKOPTIONS", File.expand_path("rcfiles/" + @user + ".nethack")],["SHELL", "/bin/sh"]]
#      when "e"[0], "E"[0]: Games.editrc @user, "nethack"
#      when "q"[0], "Q"[0]: quit = true
#      end
#    end
#  end

  def self.crawlmenu
    quit = false
    while !quit do
      status count_games
      title "Crawl#{(@count > 0) ? ((Games.by_user[@user].key? "Crawl") ? " (running)" : "") : ""} "
      unless @user == "" then
        choices = [
          ["p", "Play Crawl"],
          ["e", "Edit configuration file"]]
      else
        choices = [
          [nil, "$b$3Please login to play!$3$b"]]
      end
      choices +=[
        ["s", "View scores"],
        ["q", "Back"]]
      case menu(true, *choices)
      when "P", "p":
        unless @user == "" then
          Ncurses.def_prog_mode
          destroy
          Games.launchgame @cols, @rows, @user, "/usr/games/crawl", "Crawl", [["SHELL", "/bin/sh"]], "-name", @user , "-rc", "rcfiles/" + @user + ".crawl", "-morgue", "crawl/morgue/#{@user}", "-macro", "crawl/macro/#{@user}/macro.txt"
          initncurses
          Ncurses.reset_prog_mode
          resize
          Thread.new do
            Scores.updatecrawl
          end
        end
      when "E", "e":
        unless @user == "" then
          Ncurses.def_prog_mode
          destroy
          Games.editrc @user, "crawl"
          initncurses
          Ncurses.reset_prog_mode
          resize
        end
      when "S", "s": crawlscores
      when "Q", "q": quit = true
      end
    end
  end

  def self.gamesmenu
    quit = false
    while !quit do
      title "Games"
      status count_games
      case menu(true,
                ["a", "Angband (coming soon)#{(@count > 0) ? ((Games.by_user[@user].key? "Angband") ? " (running)" : "") : ""}"],
                ["c", "Crawl Stone Soup 0.5.0#{(@count > 0) ? ((Games.by_user[@user].key? "Crawl") ? " (running)" : "") : ""}"], 
                ["n", "NetHack (coming soon)#{(@count > 0) ? ((Games.by_user[@user].key? "NetHack") ? " (running)" : "") : ""}"],
                ["q", "Back"])
      when "A", "a": #angbandmenu
      when "C", "c": crawlmenu
      when "N", "n": #nethackmenu
      when "Q", "q": quit = true
      end
    end
  end

  def self.mainmenu
    quit = false
    while !quit do
      title "rlserver main menu"
      status count_games
      if @user == "" then
        case menu(true,
                  ["l", "Login"],
                  ["n", "New player"],
                  ["g", "Games"],
                  ["w", "Watch"],
                  ["q", "Quit"])
        when "L", "l": @user = login
        when "N", "n": @user = newuser
        when "G", "g": gamesmenu
        when "W", "w": watchmenu
        when "Q", "q": quit = true
        end
      else
        case menu(true,
                  ["p", "Change password"],
                  ["g", "Games"],
                  ["w", "Watch"],
                  ["q", "Quit"])
        when "G", "g": gamesmenu
        when "P", "p": change_password
        when "W", "w": watchmenu
        when "Q", "q": quit = true
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
