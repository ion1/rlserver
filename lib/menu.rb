require "ncurses" #should get rid of this poop and make a wrapper, especially user input is retarded
require "users"
require "games"
require "fileutils"
require "config"

module Menu
  def self.ncurses;@ncurses end; def self.user;@user end

  def self.initncurses
    unless @ncurses then
      puts "\033[8;#{@rows};#{@cols}t"
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
    @cols = Ncurses.stdscr.getmaxx
    @rows = Ncurses.stdscr.getmaxy
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

  ATTRIB = {
    "b" => lambda { Ncurses::A_BOLD },
    "r" => lambda { Ncurses::A_REVERSE },
    "n" => lambda { Ncurses::A_NORMAL },
    "s" => lambda { Ncurses::A_STANDOUT },
    "1" => lambda { Ncurses.COLOR_PAIR(1) },
    "2" => lambda { Ncurses.COLOR_PAIR(2) },
    "3" => lambda { Ncurses.COLOR_PAIR(3) }
  }
  ATTRONOFF = {
    false => lambda { |win, a| win.attroff(ATTRIB[a].call) },
    true => lambda { |win, a| win.attron(ATTRIB[a].call) }
  }

  def self.wrap_text(txt, width = 80, tag = /(?:\$[0-9a-z])/)
    if txt.gsub(/#{tag}|\n/, "").length > width then
      txt.gsub(/((?:#{tag}+.|.){1,#{width}})(?: |(\n+))/) do
        "#$1#{$2 ? $2 : "\n"}"
      end
    else txt end
  end

  @atton = {}
  ATTRIB.each_key do |k|
    @atton[k] = false
  end

  def self.aputs(win, s)
    tag = false
    col = 0 #win.getcurx
    wrap_text(s, win.getmaxx).each_char do |char|
      oldrow = win.getcury
      if char == "$" then
        tag = true
      elsif tag then
        if ATTRIB.key? char then ATTRONOFF[@atton[char] = !@atton[char]].call win, char end
        tag = false
      else
        if char == "\n" then
          if col < win.getmaxx then
            win.move win.getcury.succ, 0
          end
          col = 0 #win.getcurx
        else
          win.printw char
          col += 1
        end
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
      if name == "" then
        name = nil
        break
      end
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
      if key.class == Fixnum then
        keys[key] = block
      elsif key.class == String then
        key.each_byte do |k|
          keys[k] = block
        end
      end
      win.move row, 0
      if choice then
        aputs win, "#{key ? "$b#{key[0,1]}$b - " : "    "}#{choice}"
        row += 1
      end
    end
    Ncurses::Panel.update_panels
    Ncurses.doupdate
    key = win.getch
    Ncurses.cbreak
    if keys.key? key then
      keys[key].call key
    end
  end
  
  # Deprecated
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
    running = []
    if @user then
      Games.populate
      if Games.by_user.key? @user then
        @count = Games.by_user[@user].size
        Games.by_user[@user].each_key do |game|
          running += ["$b#{Config.config["games"][game]["name"]}$b"]
        end
      end
      "Logged in as $b#{@user}$b#{(@count > 0) ? " - You have #{running.join " and "} running" : ""}"
    else
      "Not logged in" 
    end
  end

  def self.mktime(s)
    if s then
      h = s / 3600
      m = s % 3600 / 60
      s = s % 60
      "%02d:%02d:%02d" % [h, m, s]
    else
      "unknown"
    end
  end

  GAME_COLOR = { true => "$b$3", false => "$3" }
  def self.watch
    win = Ncurses::Panel.panel_window @menu_panel
    quit = false
    offset = 0
    sel = 0
    chars = "abcdefghijklmnoprstuvwxyz"
    order = 1
    sort = 0
    while !quit do
      title "Watch games"
      #status "$bPage Up$b / $bPage Down$b - scroll, $bq$b - back"
      win.clear
      aputs win, "While watching, press $bq$b to return here. Arrow keys change sorting.\n"
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
      active_games.sort! do |a, b|
        case sort
        when 0
          x = a.player
          y = b.player
        when 1
          x = a.game
          y = b.game
        when 2
          x = a.idle
          y = b.idle
        end
        case order
        when 1
          x <=> y
        when -1
          y <=> x
        end
      end
      detached_games.sort! do |a, b|
        case sort
        when 0
          a.player <=> b.player
        when 1
          a.game <=> b.game
        when 2
          a.idle <=> b.idle
        end
      end
      total = active_games + detached_games
      total.each do |game|
        pretty += ["%s%-20s%-20s%-20s%s%s" % [GAME_COLOR[game.attached], game.player, "#{Config.config["games"][game.game]["name"]} #{Config.config["games"][game.game]["version"]}", "%3ux%3u" % [game.cols, game.rows], mktime(game.idle), GAME_COLOR[game.attached]]]
      end
      if total.length > 0 then
        aputs win, "Currently running games ("
        if active > 0 then
          aputs win, "$b$3#{active} active$b$3#{detached > 0 ? ", " :  ""}"
        end
        if detached > 0 then
          aputs win, "$3#{detached} detached$3"
        end
        aputs win, "):"
        pagesize = win.getmaxy - win.getcury - 2
        if pagesize > 25 then pagesize = 25 end
        offset.upto(offset + pagesize - 1) do |i|
          if i < total.length then
            launch = lambda do |key|
              case key
              when "a"[0].."p"[0], "r"[0].."z"[0]: sel = key - 97
              end
              if sel < active then
                Ncurses.def_prog_mode
                destroy
                puts "\033[8;#{active_games[sel].rows};#{active_games[sel].cols}t"
                Games.watchgame active_games[sel].socket
                initncurses
                Ncurses.reset_prog_mode
                resize
              end
              false
            end
            socketmenu += [[total[i].attached ? "#{chars[i % pagesize, 1]}" : nil , pretty[i], launch]]
          end
        end
        items = socketmenu.length
      else
        aputs win, "There are no games running."
      end
      win.printw "\n"
      win.move win.getcury, 4
      if sort == 0 then
        aputs win, '$bPlayer '
        aputs win, order == 1 ? '>$b' : '<$b'
      else
        win.printw 'Player'
      end
      win.move win.getcury, 24
      if sort == 1 then
        aputs win, '$bGame '
        aputs win, order == 1 ? '>$b' : '<$b'
      else
        win.printw 'Game'
      end
      win.move win.getcury, 44
      win.printw 'Size'
      win.move win.getcury, 64
      if sort == 2 then
        aputs win, '$bIdle '
        aputs win, order == 1 ? '>$b' : '<$b'
      else
        win.printw 'Idle'
      end
      win.printw "\n"
      socketmenu += [
        [Ncurses::KEY_PPAGE, nil, lambda {offset -= pagesize; if offset < 0 then offset = 0 end; false}],
        [Ncurses::KEY_NPAGE, nil, lambda {offset += pagesize; if offset >= total.length then offset -= pagesize end; false}],
        [Ncurses::KEY_UP, nil, lambda {order = -1; false}],
        [Ncurses::KEY_DOWN, nil, lambda {order = 1; false}],
        [Ncurses::KEY_LEFT, nil, lambda {sort -= 1; if sort < 0 then sort = 2 end; false}],
        [Ncurses::KEY_RIGHT, nil, lambda {sort += 1; if sort > 2 then sort = 0 end; false}],
        ["qQ", "back", lambda {true}]]
      quit = menu socketmenu
    end
  end

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
      aputs win, Config.config["games"][game]["description"] + "\n\n"
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
      choices.sort! do |a, b|
        a[1] <=> b[1]
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
      aputs win, Config.config["server"]["banner"] + "\n\n"
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
      @cols = Ncurses.stdscr.getmaxx
      @rows = Ncurses.stdscr.getmaxy
      Ncurses.echo
      Ncurses.nocbreak
      Ncurses.nl
      Ncurses.endwin
      @ncurses = false
    end
  end
end
