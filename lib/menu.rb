$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require "ncurses" #should get rid of this poop and make a wrapper, especially user input is retarded
require "fileutils"
require "mongo"

require "config"
require "users"
require "games"

module RLServer
  module Menu
    def self.ncurses
      @ncurses
    end

    def self.user= info
      @userinfo = info
    end

    def self.initncurses
      unless @ncurses then
        print "\033[8;#{@rows};#{@cols}t"
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
        Ncurses.raw
        @ncurses = true
      end
    end

    def self.initialize
      Ncurses.initscr
      @cols = Ncurses.stdscr.getmaxx
      @rows = Ncurses.stdscr.getmaxy
      initncurses
      initwindows
    end

    def self.initwindows
      @rows = Ncurses.getmaxy Ncurses.stdscr
      @cols = Ncurses.getmaxx Ncurses.stdscr
      header = Ncurses::WINDOW.new 1, @cols, 0, 0
      menu = Ncurses::WINDOW.new @rows-4, @cols-2, 2, 1
      menu.keypad true
      footer = Ncurses::WINDOW.new 1, @cols, @rows-1, 0
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
      title "Login"
      win = Ncurses::Panel.panel_window @menu_panel
      win.clear
      Ncurses.curs_set 1
      until @userinfo do
        Ncurses.echo
        win.printw "Blank entry aborts.\n"
        win.printw "User name: "
        user = ""
        win.getstr user
        if user == "" then break end
        Ncurses.noecho
        win.printw "Password: "
        pass = ""
        win.getstr pass
        if pass == "" then break end
        @userinfo = Users.login(user, pass)
        unless @userinfo then
          sleep 3
          win.printw "\nLogin incorrect.\n\n"
          Ncurses.flushinp
        end
      end
      Ncurses.curs_set 0
    end

    def self.newuser
      title "New user"
      win = Ncurses::Panel.panel_window @menu_panel
      win.clear
      created = false
      Ncurses.curs_set 1
      user = nil
      Ncurses.echo
      until Users.check_name user do
        win.printw "Alphanumerics, spaces, dashes and underscores only. Blank entry aborts.\n"
        win.printw "Name: "
        user = ""
        win.getstr user
        if user == "" then
          user = nil
          break
        end
        if Users.exists? user then
          win.printw "The user already exists.\n"
          user = nil
        end
      end
      if user then
        until created do
          Ncurses.noecho
          win.printw "Password: "
          pass = ""
          win.getstr pass
          if pass == "" then
            user = nil
            break
          end
          win.printw "Retype password: "
          pass2 = ""
          win.getstr pass2
          if pass2 == "" then
            user = nil
            break
          end
          if pass == pass2
            Users.add(user, pass)
            @userinfo = Users.login user, pass
            created = true
          else
            win.printw "Sorry, passwords do not match.\n"
            Ncurses.flushinp
          end
        end
      end
      Ncurses.curs_set 0
      user
    end

    def self.change_key
      title "Add/remove ssh keys"
      win = Ncurses::Panel.panel_window @menu_panel
      Ncurses.echo
      Ncurses.curs_set 1

      Ncurses.curs_set 0
      Ncurses.noecho
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
        if Users.login(@userinfo['user'], curpass) then
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
              Users.add @userinfo['user'], pass
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
      Ncurses.curs_set 0
    end

    def self.menu(choices)
      Ncurses.noecho
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
      Ncurses.halfdelay 100
      key = win.getch
      Ncurses.cbreak
      if keys.key? key then
        keys[key].call key
      end
    end

    def self.gen_status
      @count = 0
      running = []
      if @userinfo then
        games = Games.sessions({:user => @userinfo['user']})
        @count = games.size
        #"Logged in as $b#{@userinfo['user']}$b#{((@count > 0) ? " - sessions" : "")}"
        "Logged in as $b#{@userinfo['user']}$b"
      else
        "Not logged in" 
      end
    end

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
        aputs win, "While watching, press $bq$b to return here. Scroll with $bPage Up$b and $bPage Down$b. Arrow keys change sorting.\n"
        pretty = []
        socketmenu = []
        sessions = Games.sessions.sort do |a, b|
          case sort
          when 0
            x = a[:user].downcase
            y = b[:user].downcase
          when 1
            x = a[:game].downcase
            y = b[:game].downcase
          when 2
            x = a[:idle]
            y = b[:idle]
          end
          case order
          when 1
            x <=> y
          when -1
            y <=> x
          end
        end
        sessions.each do |hash|
          pretty << ("%-20s%-26s%-14s%02d:%02d:%02d" % [hash[:user], hash[:shortname], "#{hash[:width]}x#{hash[:height]}", hash[:idle] / 3600, hash[:idle] % 3600 / 60 , hash[:idle] % 60])
        end
        if sessions.length > 0 then
          aputs win, "Currently running games"
          pagesize = win.getmaxy - win.getcury - 3
          if pagesize > 25 then pagesize = 25 end
          offset.upto(offset + pagesize - 1) do |i|
            if i < sessions.length then
              launch = lambda do |key|
                case key
                when "a"[0].."p"[0], "r"[0].."z"[0]
                  sel = key - 97
                end
                Ncurses.def_prog_mode
                destroy
                Games.watchgame sessions[sel][:name]
                initncurses
                Ncurses.reset_prog_mode
                resize
                false
              end
              socketmenu += [["#{chars[i % pagesize, 1]}" , pretty[i], launch]]
            end
          end
          items = socketmenu.length
        else
          aputs win, "There are no games running."
        end
        win.printw "\n"
        win.move win.getcury, 4
        if sort == 0 then
          aputs win, '$bUser '
          aputs win, order == 1 ? '>$b' : '<$b'
        else
          win.printw 'User'
        end
        win.move win.getcury, 24
        if sort == 1 then
          aputs win, '$bGame '
          aputs win, order == 1 ? '>$b' : '<$b'
        else
          win.printw 'Game'
        end
        win.move win.getcury, 50
        win.printw 'Size'
        win.move win.getcury, 64
        if sort == 2 then
          aputs win, '$bIdle '
          aputs win, order == 1 ? '>$b' : '<$b'
        else
          win.printw 'Idle'
        end
        win.printw "\n"
        socketmenu << [Ncurses::KEY_PPAGE, nil, lambda {|k|offset -= pagesize; if offset < 0 then offset = 0 end; false}]
        socketmenu << [Ncurses::KEY_NPAGE, nil, lambda {|k|offset += pagesize; if offset >= sessions.length then offset -= pagesize end; false}]
        socketmenu << [Ncurses::KEY_UP, nil, lambda {|k|order = -1; false}]
        socketmenu << [Ncurses::KEY_DOWN, nil, lambda {|k|order = 1; false}]
        socketmenu << [Ncurses::KEY_LEFT, nil, lambda {|k|sort -= 1; if sort < 0 then sort = 2 end; false}]
        socketmenu << [Ncurses::KEY_RIGHT, nil, lambda {|k|sort += 1; if sort > 2 then sort = 0 end; false}]
        socketmenu << ["qQ", "back", lambda {|k|true}]
        quit = menu(socketmenu)
      end
    end

    def self.gamemenu(game)
      quit = false
      win = Ncurses::Panel.panel_window @menu_panel
      launch = lambda do |k|
        Ncurses.def_prog_mode
        destroy
        Games.launchgame @userinfo['user'], game, @cols, @rows
        initncurses
        Ncurses.reset_prog_mode
        resize
        false
      end
      edit = lambda do |k|
        Ncurses.def_prog_mode
        destroy
        Games.editrc @userinfo['user'], game
        initncurses
        Ncurses.reset_prog_mode
        resize
        false
      end
      while !quit do
        win.clear
        status gen_status
        title "#{Config.config["games"][game]["longname"]} #{Config.config["games"][game]["version"]}"
        aputs win, Config.config["games"][game]["description"] + "\n\n"
        quit = menu([["pP", "Play #{Config.config["games"][game]["name"]}", launch],
                    ["eE", "Edit configuration file", edit],
                    ["qQ", "Back", lambda {|k|true}]])
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
          choices += [["#{config["key"]}", "#{config["longname"]} #{config["version"]}", lambda {|k|gamemenu game; false}]]
        end
        choices.sort! do |a, b|
          a[1] <=> b[1]
        end
        quit = menu(choices + [["qQ", "Back", lambda {|k|true}]])
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
        quit = if @userinfo then
                 menu([["pP", "Change password", lambda {|k|change_password; false}],
                      ["kK", "Add/remove ssh keys (coming soon)", lambda {|k|change_key; false}],
                      ["gG", "Games", lambda {|k|games; false}],
                      ["wW", "Watch", lambda {|k|watch; false}],
                      ["qQ", "Quit", lambda {|k|true}]])
               else
                 menu([["lL", "Login", lambda {|k|login; false}],
                      ["nN", "New user", lambda {|k|newuser; false}],
                      ["wW", "Watch games", lambda {|k|watch; false}],
                      ["qQ", "Quit", lambda {|k|true}]])
               end
      end
    end

    def self.destroy
      Signal.trap "WINCH" do end
      if @ncurses then
        @cols = Ncurses.stdscr.getmaxx
        @rows = Ncurses.stdscr.getmaxy
        Ncurses.echo
        Ncurses.nl
        Ncurses.endwin
        @ncurses = false
      end
    end
  end
end
