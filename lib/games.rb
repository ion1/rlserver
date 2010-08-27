require 'date'
require 'lib/config'
require 'fileutils'
require 'tmux-ruby/lib/tmux'

module Games
  @tmux = Tmux::Server.new 'rlserver'

  class Session
    attr_reader :info, :name, :idle
    def initialize(info)
      @info = info
      @name = "#{@info[:user]}.#{@info[:game]}.#{@info[:width]}x#{@info[:height]}.#{@info[:date]}"
      @idle = Time.now - File.stat("#{RlConfig.config["server"]["path"]}/#{@info[:game]}/stuff/#{@info[:user]}/#{@name}.ttyrec").mtime
    end
  end

  def self.sessions(search = {})
    sessions = []
    @tmux.sessions.each do |ses|
      user, game, size, date = ses.name.split('.')
      width, height = size.split('x')
      sessions << Games::Session.new({
        :user => user,
        :game => game,
        :width => width,
        :height => height,
        :date => DateTime.parse(date),
      })
    end
    sessions
  end

  def self.launchgame(user, game, width, height)
    pid = fork do
      if Games.sessions({:user => user, :game => game}) then
      else
        session = Session.new({
          :user => user,
          :game => game,
          :width => width,
          :height => height,
          :date => DateTime.now
        })
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
        if RlConfig.config['games'][game].key? 'chdir' then
          pushd = Dir.pwd
          Dir.chdir(RlConfig.config['games'][game]['chdir'])
        end
        @tmux.create_session
        ({
          :name => session.info[:name],
          :attach => 'attach',
          :command => "exec termrec -r #{RlConfig.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec -e \'#{RlConfig.config['games'][game]['binary']} #{options.join ' '}\'"
        })
      end
    end
    Process.wait pid
    if RlConfig.config['games'][game].key? 'chdir' then
      Dir.chdir(pushd)
    end
    unless Games.sessions({:user => user, :game => game}) then
      pid = fork do
        MiscHacks.sh 'exec', 'bzip2', "#{RlConfig.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec"
      end
    end
    if pid then Process.detach pid end
  end

  def self.watchgame(session)
    pid = fork do
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      MiscHacks.sh 'exec', 'nano', '-R', "#{RlConfig.config['server']['path']}/#{game}/init/#{user}.txt"
    end
    Process.wait pid
  end
end
