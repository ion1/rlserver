$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'date'
require 'fileutils'
require 'mischacks'
require 'digest'
require 'ncurses'

# TODO: Simple tmux wrapper; lots of duplicated shit
require 'tmux-ruby/lib/tmux'
require 'config'
require 'log'

module RLServer
  module Games
    PLAY_SERVER = 'rlserver'
    WATCH_SERVER = 'rlwatch'
    @play = Tmux::Server.new PLAY_SERVER
    @watch = Tmux::Server.new WATCH_SERVER

    def self.sessions(search = {})
      sessions = []
      @play.sessions.each do |ses|
        user, game, size, date = ses.name.split('.')
        if user && game && size && date then
          ttyrec = "#{Config.config['server']['path']}/#{game}/stuff/#{user}/#{ses.name}.ttyrec"
          sessions << {
            :name => ses.name,
            :user => user,
            :game => game,
            :shortname => "#{Config.config['games'][game]['name']} #{Config.config["games"][game]["version"]}",
            :longname => "#{Config.config['games'][game]['longname']} #{Config.config["games"][game]["version"]}",
            :width => ses.width,
            :height => ses.height,
            :date => DateTime.parse(date),
            :attached => ses.attached,
            :ttyrec => ttyrec,
            :idle => File.exists?(ttyrec) ? Time.now - File.stat(ttyrec).mtime : 0,
          }
        end
      end
      sessions.select do |ses|
        ses.all? do |key, value|
          !search.has_key?(key) || value == search[key]
        end
      end
    end

    def self.launchgame(user, game)
      if Config.config['games'][game].key? 'chdir' then
        pushd = Dir.pwd
        Dir.chdir(Config.config['games'][game]['chdir'])
      end
      height = Ncurses.getmaxy Ncurses.stdscr
      width = Ncurses.getmaxx Ncurses.stdscr
      @session = Games.sessions({:user => user, :game => game}).first
      if @session then
        ENV['TMUX'] = ''
        print "\033[8;#{@session[:height]};#{@session[:width]}t"
        MiscHacks.sh('stty rows "$1"; stty cols "$2"', @session[:height], @session[:width])
        MiscHacks.sh(
          %{exec "$tmux_bin" -f "$config" -L "$server" attach -t "$session"},
          :tmux_bin => Tmux.binary,
          :config => "#{Config.config['server']['path']}/play.conf",
          :server => PLAY_SERVER,
          :session => @session[:name],
        )
      else
        date = DateTime.now
        name = "#{user}.#{game}.#{width}x#{height}.#{date}"
        @session = {
          :name => name,
          :user => user,
          :game => game,
          :shortname => "#{Config.config['games'][game]['name']} #{Config.config["games"][game]["version"]}",
          :longname => "#{Config.config['games'][game]['longname']} #{Config.config["games"][game]["version"]}",
          :width => width,
          :height => height,
          :date => date,
          :ttyrec => "#{Config.config['server']['path']}/#{game}/stuff/#{user}/#{name}.ttyrec",
        }
        if Config.config['games'][game].key? 'env' then
          Config.config['games'][game]['env'].split(' ').each do |env|
            env.gsub! /%path%/, Config.config['server']['path']
            env.gsub! /%user%/, user
            env.gsub! /%game%/, game
            var, set = env.split '='
            ENV[var.strip] = set.strip
          end
        end
        options = []
        if Config.config['games'][game].key? 'parameters' then
          Config.config['games'][game]['parameters'].split(' ').each do |arg|
            arg.gsub! /%path%/, Config.config['server']['path']
            arg.gsub! /%user%/, user
            arg.gsub! /%game%/, game
            options << %{'#{arg.strip}'}
          end
        end
        ENV['TMUX'] = ''
        MiscHacks.sh(
          %{exec "$tmux_bin" -f "$config" -L "$server" new -s "$session" "exec $ttyrec_bin $ttyrec -e '$game_bin $options'"},
          :tmux_bin => Tmux.binary,
          :config => "#{Config.config['server']['path']}/play.conf",
          :ttyrec => @session[:ttyrec],
          :ttyrec_bin => "#{Config.config['server']['path']}/termrec",
          :server => PLAY_SERVER,
          :session => @session[:name],
          :game_bin => Config.config['games'][game]['binary'],
          :options => options.join(' '),
          :width => width,
          :height => height,
        )
      end
      if Config.config['games'][game].key? 'chdir' then
        Dir.chdir(pushd)
      end
      has_session = Games.sessions({:user => user, :game => game}).first
      unless has_session then
        bzip2 = fork do
          MiscHacks.sh('exec bzip2 "$1"', @session[:ttyrec])
        end
      end
      if bzip2 then Process.detach bzip2 end
      print "\033[8;#{height};#{width}t"
      MiscHacks.sh('stty rows "$1"; stty cols "$2"', height, width)
    end

    def self.watchgame(session)
      width = Ncurses.getmaxx Ncurses.stdscr
      height = Ncurses.getmaxy Ncurses.stdscr
      @session = Games.sessions({:name => session}).first
      if @session then
        print "\033[8;#{@session[:height]};#{@session[:width]}t"
        ENV['TMUX'] = ''
        watch_session = Digest::SHA1.hexdigest("#{ENV['SSH_CLIENT']}")
        unless @play.sessions({:name => watch_session}).first then
          MiscHacks.sh(
            %{stty rows "$height"; stty cols "$width"; exec "$tmux_bin" -f "$config" -L "$server" new -d -s "$watch_session" -t "$session"},
            :config => "#{Config.config['server']['path']}/play.conf",
            :watch_config => "#{Config.config['server']['path']}/watch.conf",
            :watch_session => watch_session,
            :session => @session[:name],
            :tmux_bin => Tmux.binary,
            :server => PLAY_SERVER,
            :height => @session[:height],
            :width => @session[:width],
          )
          MiscHacks.sh(
            %{"$dtach_bin" -n "/tmp/$watch_session" -E sh -c 'stty rows "$height"; stty cols "$width"; "$tmux_bin" -L "$server" attach -r -d -t "$watch_session"'},
            :dtach_bin => "#{Config.config['server']['path']}/dtach",
            :watch_session => watch_session,
            :tmux_bin => Tmux.binary,
            :server => PLAY_SERVER,
            :height => @session[:height],
            :width => @session[:width],
          )
        end
        MiscHacks.sh(
          %{stty rows "$height"; stty cols "$width"; exec "$dtach_bin" -a "/tmp/$session" -e \q -R -z},
          :dtach_bin => "#{Config.config['server']['path']}/dtach",
          :session => watch_session,
          :height => @session[:height],
          :width => @session[:width],
        )
        if @play.sessions({:name => watch_session}).first then
          MiscHacks.sh(
            %{exec "$tmux_bin" -L "$server" kill-session -t "$session"},
            :tmux_bin => Tmux.binary,
            :server => PLAY_SERVER,
            :session => watch_session,
          )
        end
        print "\033[8;#{height};#{width}t"
        MiscHacks.sh('stty rows "$1"; stty cols "$2"', height, width)
      end
    end

    def self.editrc(user, game)
      MiscHacks.sh('exec nano -R "$1"', "#{Config.config['server']['path']}/#{game}/init/#{user}.txt")
    end
  end
end
