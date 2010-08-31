$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'date'
require 'fileutils'
require 'mischacks'

# TODO: Simple tmux wrapper
require 'tmux-ruby/lib/tmux'
require 'config'
require 'log'

module RLServer
  module Games
    PLAY_SERVER = 'rlserver'
    WATCH_SERVER = 'rlwatch'
    @play = Tmux::Server.new PLAY_SERVER
    @watch = Tmux::Server.new WATCH_SERVER
    @ttyrec_binary = `which ttyrec`.chomp
    @verbosity = ENV['TMUX_VERBOSITY'] ? ENV['TMUX_VERBOSITY'][/-v+/] : ''

    def self.sessions(search = {})
      sessions = []
      @play.sessions.each do |ses|
        user, game, size, date = ses.name.split('.')
        if user && game && size && date then
          width, height = size.split('x')
          ttyrec = "#{Config.config['server']['path']}/#{game}/stuff/#{user}/#{ses.name}.ttyrec"
          sessions << {
            :name => ses.name,
            :user => user,
            :game => game,
            :shortname => "#{Config.config['games'][game]['name']} #{Config.config["games"][game]["version"]}",
            :longname => "#{Config.config['games'][game]['longname']} #{Config.config["games"][game]["version"]}",
            :width => width,
            :height => height,
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

    def self.launchgame(user, game, width, height)
      @config = Config.config['server']['path']+'/play.conf'
      if Config.config['games'][game].key? 'chdir' then
        pushd = Dir.pwd
        Dir.chdir(Config.config['games'][game]['chdir'])
      end
      @session = Games.sessions({:user => user, :game => game}).first
      if @session then
        print "\033[8;#{@session[:height]};#{@session[:width]}t"
        ENV['TMUX'] = ''
        MiscHacks.sh(
          %{exec "$binary" #{@verbosity} -f "$config" -L "$server" attach -t "$session"},
          :binary => Tmux.binary,
          :config => @config,
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
            options += [arg.strip]
          end
        end
        command = %{"#{@ttyrec_binary}" "#{@session[:ttyrec]}" -e \"#{Config.config['games'][game]['binary']} #{options.join ' '}\"}
        ENV['TMUX'] = ''
        MiscHacks.sh(
          %{exec "$binary" #{@verbosity} -f "$config" -L "$server" new -s "$session" "$command"},
          :binary => Tmux.binary,
          :config => @config,
          :server => PLAY_SERVER,
          :session => @session[:name],
          :command => command,
          :height => @session[:height],
          :width => @session[:width],
        )
      end
      if Config.config['games'][game].key? 'chdir' then
        Dir.chdir(pushd)
      end
      list = Games.sessions({:user => user, :game => game}).first
      unless list then
        bzip2 = fork do
          RLServer.log.debug MiscHacks.sh('exec bzip2 "$1"', @session[:ttyrec])
        end
      end
      if bzip2 then Process.detach bzip2 end
    end

    def self.watchgame(session)
      @config = Config.config['server']['path']+'/play.conf'
      @watch_config = Config.config['server']['path']+'/watch.conf'
      @session = Games.sessions({:name => session}).first
      if @session then
        print "\033[8;#{@session[:height]};#{@session[:width]}t"
        ENV['TMUX'] = ''
        command = %{exec "#{Tmux.binary}" #{@verbosity} -f "#{@config}" -L "#{PLAY_SERVER}" attach -r -t "#{@session[:name]}"}
        MiscHacks.sh(
          %{exec "$binary" #{@verbosity} -f "$watch_config" -L "$watch" new \"#{@ttyrec_binary} /dev/null -e '$command'\"},
          :binary => Tmux.binary,
          :config => @config,
          :watch_config => @watch_config,
          :play => PLAY_SERVER,
          :watch => WATCH_SERVER,
          :session => @session[:name],
          :width => @session[:width],
          :height => @session[:height],
          :command => command
        )
      end
    end

    def self.editrc(user, game)
      MiscHacks.sh('exec nano -R "$1"', "#{Config.config['server']['path']}/#{game}/init/#{user}.txt")
    end
  end
end
