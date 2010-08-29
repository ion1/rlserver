require 'date'
require 'lib/config'
require 'fileutils'
require 'tmux-ruby/lib/tmux'
require 'mischacks'
require 'digest'
require 'base64'

module Games
  PLAY_SERVER = 'rlserver'
  WATCH_SERVER = 'rlwatch'
  @play = Tmux::Server.new PLAY_SERVER
  @watch = Tmux::Server.new WATCH_SERVER

  def self.sessions(search = {})
    sessions = {}
    @play.sessions.each do |ses|
      user, game, size, date = ses.name.split('.')
      if user && game && size && date then
        width, height = size.split('x')
        sessions[ses.name] = {
          :name => ses.name,
          :user => user,
          :game => game,
          :width => width,
          :height => height,
          :date => DateTime.parse(date),
          :attached => ses.attached,
          :idle => Time.now - File.stat("#{RlConfig.config['server']['path']}/#{game}/stuff/#{user}/#{ses.name}.ttyrec").mtime,
        }
      end
    end
    sessions.select do |k, v|
      v.all? do |vk, vv|
        !search.has_key?(vk) || vv == search[vk]
      end
    end.values
  end

  def self.launchgame(user, game, width, height)
  @config = RlConfig.config['server']['path']+'/play.conf'
    if RlConfig.config['games'][game].key? 'chdir' then
      pushd = Dir.pwd
      Dir.chdir(RlConfig.config['games'][game]['chdir'])
    end
    user_session = Games.sessions({:user => user, :game => game})
    if user_session.size > 0 then
      @session = user_session.first[:name]
      puts "\033[8;#{user_session.first[:height]};#{user_session.first[:width]}t"
      @ttyrec = "#{RlConfig.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec"
      pid = fork do
        MiscHacks.sh(
          'exec "$binary" -f "$config" -L "$server" attach -d -t "$session"',
          :binary => Tmux.binary,
          :config => @config,
          :server => PLAY_SERVER,
          :session => @session,
        )
      end
    else
      if RlConfig.config['games'][game].key? 'env' then
        RlConfig.config['games'][game]['env'].split(' ').each do |env|
          env.gsub! /%path%/, RlConfig.config['server']['path']
          env.gsub! /%user%/, user
          env.gsub! /%game%/, game
          var, set = env.split '='
          ENV[var.strip] = set.strip
        end
      end
      options = []
      if RlConfig.config['games'][game].key? 'parameters' then
        RlConfig.config['games'][game]['parameters'].split(' ').each do |arg|
          arg.gsub! /%path%/, RlConfig.config['server']['path']
          arg.gsub! /%user%/, user
          arg.gsub! /%game%/, game
          options += [arg.strip]
        end
      end
      @session = "#{user}.#{game}.#{width}x#{height}.#{DateTime.now}"
      @ttyrec = "#{RlConfig.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec"
      command = "exec ttyrec #{@ttyrec} -e '#{RlConfig.config['games'][game]['binary']} #{options.join ' '}'"
      @game = "#{RlConfig.config['games'][game]['name']}"
      pid = fork do
        MiscHacks.sh(
          'exec "$binary" -q -f "$config" -L "$server" new -s "$session" "$command"',
          :binary => Tmux.binary,
          :config => @config,
          :server => PLAY_SERVER,
          :session => @session,
          :command => command,
        )
      end
    end
    Process.wait pid
    if RlConfig.config['games'][game].key? 'chdir' then
      Dir.chdir(pushd)
    end
    user_session = Games.sessions({:user => user, :game => game})
    if user_session.size == 0 then
      bzip2 = fork do
        MiscHacks.sh('exec bzip2 "$1"', @ttyrec)
      end
    end
    if bzip2 then Process.detach bzip2 end
  end

  def self.watchgame(session)
    @config = RlConfig.config['server']['path']+'/play.conf'
    @watch_config = RlConfig.config['server']['path']+'/watch.conf'
    info = Games.sessions({:name => session})
    puts "\033[8;#{info.first[:height]};#{info.first[:width]}t"
    ENV['TMUX'] = ''
    pid = fork do
      MiscHacks.sh(
        %{exec "$binary" -q -f "$watch_config" -L "$watch" new \"exec "$binary" -f "$config" -L "$play" attach -r -t "$session"\"},
        :binary => Tmux.binary,
        :config => @config,
        :watch_config => @watch_config,
        :play => PLAY_SERVER,
        :watch => WATCH_SERVER,
        :session => session,
      )
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      MiscHacks.sh('exec nano -R "$1"', "#{RlConfig.config['server']['path']}/#{game}/init/#{user}.txt")
    end
    Process.wait pid
  end
end
