require 'date'
require 'lib/config'
require 'fileutils'
require 'tmux-ruby/lib/tmux.rb'

module Games

  def self.by_user user
      sessions = []
  end

  def self.by_game game
      sessions = []
  end
  def self.launchgame(cols, rows, user, game)
    gamepid = fork do
      if by_user[user].key? game then
        @session = @by_user[user][game].session
        puts "\033[8;#{@by_user[user][game].rows};#{@by_user[user][game].cols}t"
        exec_or_die 'tmux', '-S', 'session', 'a', '-d'
      else
        @session = "#{user}.#{game}.#{cols}x#{rows}.#{DateTime.now}"
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
        if Config.config['games'][game].key? 'chdir' then
          pushd = Dir.pwd
          Dir.chdir(Config.config['games'][game]['chdir'])
        end
        exec 'tmux', '-c', "termrec -r #{Config.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec -e \'#{Config.config['games'][game]['binary']} #{options.join ' '}\'", 'a'
      end
    end
    Process.wait gamepid
    if Config.config['games'][game].key? 'chdir' then
      Dir.chdir(pushd)
    end
    populate
    unless @by_user.key? user and @by_user[user].key? game then
      pid = fork do
          exec_or_die 'bzip2', '#{Config.config['server']['path']}/#{game}/stuff/#{user}/#{@session}.ttyrec'
      end
    end
    if pid then Process.detach pid end
  end

  def self.watchgame(session)
    pid = fork do
      exec_or_die 'tmux', '-S', 'tmux/#{session}', 'a'
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      exec_or_die 'nano', '-R', '#{Config.config['server']['path']}/#{game}/init/#{user}.txt'
    end
    Process.wait pid
  end
end
