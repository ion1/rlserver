require "date"
require "config"
require "fileutils"

module Games
  def self.socket; @socket end;def self.games; @games end; def self.by_user; @by_user end

  def self.cmd_safe(cmd, *args)
    (%W{sh -c #{cmd} --} + args)
  end
  
  def self.exec_or_die *args
    begin
      exec *args
    ensure
      exit 1
    end
  end 
  
  class Game
    attr_reader :idle, :player, :game, :time, :cols, :rows, :attached, :socket, :screen_pid
    def initialize(data)
      @screen_pid = data[0].to_i
      @socket = data[1,4].join "."
      @attached = File.executable? "/var/run/screen/S-#{Config.config["server"]["user"]}/#{@screen_pid}.#{@socket}"
      @player = data[1]
      @game = data[2]
      cols, rows = data[3].split "x"
      @cols = cols.to_i
      @rows = rows.to_i
      @time = data[4]
      if File.exists? "#{@game}/ttyrec/#{@player}/#{@socket}.ttyrec" then
        @idle = (Time.now - File.stat("#{@game}/ttyrec/#{@player}/#{@socket}.ttyrec").mtime).to_i
      end
    end
  end

  def self.populate
    @games = []
    @by_user = {}
    @by_socket = {}
    if File.exists? "/var/run/screen/S-#{Config.config["server"]["user"]}" then
      Dir.foreach "/var/run/screen/S-#{Config.config["server"]["user"]}" do |f|
        if f.match /(\d+)\.(.+)\.(\w+)\.(\d+x\d+)\.(\d+-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d)/ then
          @games += [game = Game.new($~[1,6])]
          if @by_user[game.player] then @by_user[game.player][game.game] = game
          else @by_user[game.player] = {}; @by_user[game.player][game.game] = game end
          @by_socket[game.socket] = game
        end
      end
    end
  end

  def self.launchgame(cols, rows, user, game)
    populate
    if @by_user.key? user and @by_user[user].key? game then
      @socket = @by_user[user][game].socket
      puts "\033[8;#{@by_user[user][game].rows};#{@by_user[user][game].cols}t"
      pid = fork do
        system "screen", "-D", @socket
        exec_or_die "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-D", "-r", @socket
      end
    else
      @socket = "#{user}.#{game}.#{cols}x#{rows}.#{DateTime.now}"
      if Config.config["games"][game].key? "env" then
        Config.config["games"][game]["env"].split(" ").each do |env|
          env.gsub! /%path%/, Config.config["server"]["path"]
          env.gsub! /%user%/, user
          env.gsub! /%game%/, game
          var, set = env.split "="
          ENV[var.strip] = set.strip
        end
      end
      options = []
      if Config.config["games"][game].key? "parameters" then
        Config.config["games"][game]["parameters"].split(" ").each do |arg|
          arg.gsub! /%path%/, Config.config["server"]["path"]
          arg.gsub! /%user%/, user
          arg.gsub! /%game%/, game
          options += [arg.strip]
        end
      end
      pid = fork do
        exec_or_die "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-S", @socket, "-c", "screenrc", "termrec", "#{game}/ttyrec/#{user}/#{@socket}.ttyrec", "-e", "#{Config.config["games"][game]["binary"]} #{options.join " "}" #cmd_safe("#{Config.config["games"][game]["binary"]}", options)
      end
    end
    Process.wait pid
    populate
    unless @by_user.key? user and @by_user[user].key? game then
      pid = fork do
        exec_or_die "bzip2", "#{game}/ttyrec/#{user}/#{@socket}.ttyrec.bz2", "#{game}/ttyrec/#{user}/#{@socket}.ttyrec"
      end
    end
    Process.detach pid
  end

  def self.watchgame(socket)
    pid = fork do
      exec_or_die "dtach", "-a", "socket/#{socket}", "-R", "-e", "\q", "-r", "screen", "-C", "^\\", "-z", "-s"
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      exec_or_die "nano", "-R", "#{game}/rcfiles/#{user}"
    end
    Process.wait pid
  end
end
