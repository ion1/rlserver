require "ncurses"
require "users"
require "games"
require "fileutils"
require "scores"
require "config"

module Menu
  def self.ncurses;@ncurses end; def self.user;@user end

  def self.initncurses
    unless @ncurses then
      Signal.trap "WINCH" do
        resize
      end
      Ncurses.nonl
      Ncurses.stdscr.intrflush false
      Ncurses.noecho
      Ncurses.clear
      Ncurses.start_color
      #colors should be in the config
      Ncurses.init_pair 1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE
      Ncurses.init_pair 2, Ncurses::COLOR_YELLOW, Ncurses::COLOR_BLACK
      Ncurses.init_pair 3, Ncurses::COLOR_CYAN, Ncurses::COLOR_BLACK
      Ncurses.curs_set 0
      Ncurses.halfdelay 100
      @ncurses = true
    end
  end

  def self.initialize
    Ncurses.initscr
    initncurses
    initwindows
    @user = nil
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

  #stuff is beginning to weep through to places it shouldn't be
  #refactoring ensues in the future
  ATTRIB = {"b" => Ncurses::A_BOLD, "r" => Ncurses::A_REVERSE, "n" => Ncurses::A_NORMAL, "s" => Ncurses::A_STANDOUT}
  def self.aputs(win, s)
    control = false
    attrs = ""
    line_count = s.each_line.collect.size
    #win.printw "#{line_count}"
    line_num = 0
    s.each_line do |line|
      word_num = 0
      line.split(" ").each do |word|
        if win.getcurx > 0 and word_num > 0 then
          if win.getcurx + word.length >= win.getmaxx then
            win.printw "\n"
          else
            win.printw " "
          end
        end
        word.each_char do |c|
          if control then
            control = false
            if ATTRIB.key? c then
              if attrs.include? c
                win.attroff ATTRIB[c]
                attrs.delete! c
              else
                win.attron ATTRIB[c]
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
            else
              win.addch c[0]
            end
          else
            (control = (c == "$")) ? () : (win.addch c[0])
          end
        end
        word_num += 1
      end
      line_num += 1
      #win.printw "#{line_num}"
      if line_num < line_count then
        win.printw "\n"
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

  def self.login
    Ncurses.cbreak
    title "Login"
    loggedin = nil
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
      loggedin = Users.login(name, pass)
      unless loggedin == name then
        sleep 3
        win.printw "\nLogin incorrect.\n\n"
        Ncurses.flushinp
      end
    end
    Ncurses.curs_set 0
    Ncurses.halfdelay 100
    loggedin
  end

  def self.newuser
    Ncurses.cbreak
    title "New player"
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    created = false
    Ncurses.curs_set 1
    name = nil
    Ncurses.echo
    until Users.checkname name do
      win.printw "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
      win.printw "Name: "
      getname = ""
      win.getstr getname
      name = getname
      if Users.exists? name then
        win.printw "The player already exists.\n"
        name = nil
      end
    end
    if name then
      until created do
        Ncurses.noecho
        win.printw "Password: "
        pass = ""
        win.getstr pass
        if pass == "" then
          name = nil
          break
        end
        win.printw "Retype password: "
        pass2 = ""
        win.getstr pass2
        if pass2 == "" then
          name = nil
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
    Ncurses.curs_set 0
    Ncurses.halfdelay 100
    name
  end

  def self.change_password
    Ncurses.cbreak
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
    Ncurses.halfdelay 100
    Ncurses.curs_set 0
  end
  
  def self.menu(choices)
    Ncurses.noecho
    Ncurses.halfdelay 100
    win = Ncurses::Panel.panel_window @menu_panel
    row = win.getcury
    keys = {}
    choices.each do |key, choice, block|
      key.each_byte do |k|
        keys[k] = block
      end
      win.move row, 0
      aputs win, "$b#{key ? "#{key[0,1]}$b - " : "    "}#{choice}"
      row += 1
    end
    Ncurses::Panel.update_panels
    Ncurses.doupdate
    key = win.getch
    Ncurses.cbreak
    if keys.key? key then
      keys[key].call
    end
  end
  
  #crawl-specific, fix this and scores.rb
  def self.crawlscores
    win = Ncurses::Panel.panel_window @menu_panel
    win.clear
    scores = Scores::CrawlScores.new Config.config["games"]["crawl"]["scores"]
    quit = false
    pretty = []
    i = 1
    scores.data.each do |score|
      str = "%4u. %8s %-10s %s-%02u %7s %s" % [i, score["sc"], score["name"], score["char"], score["xl"], "(#{score["place"]})", score["tmsg"].chomp]
      str.sub! /\$/, "$$"
      pretty += [str]
      i += 1
    end
    offset = 0
    while !quit do
      title "Crawl scores"
      status "$bPage Up$b / $bPage Down$b - scroll, $bq$b - back"
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

  def self.gen_status
    @count = 0
    if @user then
      Games.populate
      if Games.by_user.key? @user then
        @count = Games.by_user[@user].length
      end
      "Logged in as $b#{@user}$b#{(@count > 0) ? " - You have #{(@count == 1) ? "one" : @count} game#{@count > 1 ? "s" : ""} running" : ""}"
    else
      "Not logged in" 
    end
  end

  def self.mktime(s)
    h = s / 3600
    m = s % 3600 / 60
    s = s % 60
    "%02d:%02d:%02d" % [h, m, s]
  end

  def self.watch
    win = Ncurses::Panel.panel_window @menu_panel
    quit = false
    offset = 0
    sel = 0
    chars = "abcdefghijklmnop"
    while !quit do
      pagesize = win.getmaxy - 4
      if pagesize > 16 then pagesize = 16 end
      title "Watch games"
      status "$bPage Up$b / $bPage Down$b - scroll, $bq$b - back"
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
        a = game.attached ? "$b$3" : "$3"
        pretty += ["%s%-14s%-14s%-14s(idle %s)%s" % [a, game.player, Config.config["games"][game.game]["name"], "(%3ux%3u)" % [game.cols, game.rows], mktime(game.idle), a]]
      end
      win.clear
      aputs win,
        "Use $buppercase$b to try to resize the terminal (recommended).\n" +
        "While watching, press $bq$b to return to the menu.\n"
      if total.length > 0 then
        aputs win, "Showing games #{offset+1}-#{(((offset+pagesize) > total.length) ? total.length : offset+pagesize)} of #{total.length} ("
        if active > 0 then
          aputs win, "$b$3#{active} active$b$3#{(detached > 0 ? ", " : "")}"
        end
        if detached > 0 then
          aputs win, "$3#{detached} detached$3"
        end
        aputs win, ")."
        offset.upto(offset + pagesize - 1) do |i|
          if i < total.length then
            socketmenu += [[total[i].attached ? "$b#{chars[i % pagesize, 1]}$b" : nil, pretty[i]]]
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
  end

  #keeping these here just for the parameters

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

  def self.gamemenu(game)
    quit = false
    win = Ncurses::Panel.panel_window @menu_panel
    launch = lambda do
      Ncurses.def_prog_mode
      destroy
      Games.launchgame @cols, @rows, @user, game
      initncurses
      Ncurses.reset_prog_mode
      resize
      false
    end
    edit = lambda do
      Ncurses.def_prog_mode
      destroy
      Games.editrc @user, game
      initncurses
      Ncurses.reset_prog_mode
      resize
      false
    end
    while !quit do
      win.clear
      status gen_status
      title "#{Config.config["games"][game]["name"]} #{Config.config["games"][game]["version"]}#{(@count > 0) ? ((Games.by_user[@user].key? game) ? " (running)" : "") : ""} "
      aputs win, Config.config["games"][game]["description"] + "\n\n\n"
      quit = menu([["pP", "Play #{Config.config["games"][game]["name"]}", launch],
                  ["eE", "Edit configuration file", edit],
                  ["qQ", "Back", lambda {true}]])
    end
  end

  def self.games
    quit = false
    win = Ncurses::Panel.panel_window @menu_panel
    while !quit do
      title "Games"
      status gen_status
      win.clear
      choices = []
      Config.config["games"].each_pair do |game, config|
        choices += [["#{config["key"]}", "#{config["name"]} #{config["version"]}#{(@count > 0) ? ((Games.by_user[@user].key? game) ? " (running)" : "") : ""}", lambda {gamemenu game; false}]]
      end
      quit = menu(choices + [["qQ", "Back", lambda {true}]])
    end
  end

  def self.mainmenu
    quit = false
    win = Ncurses::Panel.panel_window @menu_panel
    while !quit do
      title "Main menu"
      status gen_status
      win.clear
      aputs win, Config.config["server"]["banner"] + "\n\n\n"
      quit =
        if @user then
          menu([["pP", "Change password", lambda {change_password; false}],
               ["gG", "Games", lambda {games; false}],
               ["wW", "Watch", lambda {watch; false}],
               ["qQ", "Quit", lambda {true}]])
        else
          menu([["lL", "Login", lambda {@user = login; false}],
               ["nN", "New player", lambda {@user = newuser; false}],
               ["wW", "Watch games", lambda {watch; false}],
               ["qQ", "Quit", lambda {true}]])
        end
    end
  end

  def self.destroy
    Signal.trap "WINCH" do end
    if @ncurses then
      Ncurses.echo
      Ncurses.nocbreak
      Ncurses.nl
      Ncurses.endwin
      @ncurses = false
    end
  end
end
