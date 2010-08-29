require 'date'
require 'lib/config'
require 'fileutils'
require 'tmux-ruby/lib/tmux'
require 'mischacks'

module Games
  TMUX_SERVER = 'rlserver'
  @tmux = Tmux::Server.new TMUX_SERVER

  def self.sessions(search = {})
    sessions = {}
    @tmux.sessions.each do |ses|
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
        MiscHacks.sh('exec "$1" -f "$2" -L "$3" attach-session -d -t "$4"', Tmux.binary, RlConfig.config['server']['path']+'/tmux.conf', TMUX_SERVER, @session
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
        MiscHacks.sh('exec "$1" -f "$2" -L "$3" new-session -s "$4" "$5"', Tmux.binary, RlConfig.config['server']['path']+'/tmux.conf', TMUX_SERVER, @session, command)
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
    info = Games.sessions({:name => session})
    puts "\033[8;#{info.first[:height]};#{info.first[:width]}t"
    pid = fork do
      MiscHacks.sh('exec "$1" -L "$2" bind -n q detach-client; attach-session -r -t "$3"', Tmux.binary, TMUX_SERVER, session)
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      MiscHacks.sh('exec nano -R "$1"', "#{RlConfig.config['server']['path']}/#{game}/init/#{user}.txt"
    end
    Process.wait pid
  end
end
