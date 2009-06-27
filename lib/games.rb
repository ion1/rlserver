require "date"
require "config"
require "fileutils"

module Games
  def self.socket; @socket end;def self.games; @games end; def self.by_user; @by_user end

  def self.cmd_safe(cmd, *args)
    (%W{sh -c #{cmd} --} + args)
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
      if File.exists? "#{@game}/ttyrec/#{@player}/#{@socket}.ttyrec.bz2" then
        @idle = (Time.now - File.stat("#{@game}/ttyrec/#{@player}/#{@socket}.ttyrec.bz2").mtime).to_i
      elsif File.exists? "inprogress/#{@socket}.ttyrec.bz2" then
        @idle = (Time.now - File.stat("inprogress/#{@socket}.ttyrec.bz2").mtime).to_i
      end
    end
  end

  def self.populate
    @games = []
    @by_user = {}
    @by_socket = {}
    if File.exists? "/var/run/screen/S-#{Config.config["server"]["user"]}" then
      Dir.foreach "/var/run/screen/S-#{Config.config["server"]["user"]}" do |f|
        if f.match /(\d+)\.([\w\d\s\-_ ]+)\.(\w+)\.(\d+x\d+)\.(\d+-\d\d-\d\dT\d\d:\d\d:\d\d\+\d\d:\d\d)/ then
          @games += [game = Game.new($~[1,6])]
          @by_user[game.player] = {game.game => game}
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
        exec "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-D", "-r", @socket
      end
    else
      @socket = "#{user}.#{game}.#{cols}x#{rows}.#{DateTime.now}"
      if Config.config["games"][game].key? "env" then
        envs = Config.config["games"][game]["env"].split " "
        envs.each do |env|
          var, set = env.split "="
          var.gsub! /%user%/, user
          var.gsub! /%game%/, game
          ENV[var.strip] = set.strip
        end
      end
      options = []
      if Config.config["games"][game].key? "parameters" then
        Config.config["games"][game]["parameters"].split(" ").each do |arg|
          arg.gsub! /%user%/, user
          arg.gsub! /%game%/, game
          options += [arg.strip]
        end
      end
      pid = fork do
        exec "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-S", @socket, "-c", "screenrc", "termrec", "#{game}/ttyrec/#{user}/#{@socket}.ttyrec.bz2", "-e", "#{Config.config["games"][game]["binary"]} #{options.join " "}" #cmd_safe("#{Config.config["games"][game]["binary"]}", options)
      end
    end
    Process.wait pid
  end

  def self.watchgame(socket)
    pid = fork do
      exec "dtach", "-a", "socket/#{socket}", "-R", "-e", "\q", "-r", "screen", "-C", "^\\", "-z", "-s"
    end
    Process.wait pid
  end

  def self.editrc(user, game)
    pid = fork do
      exec "nano", "-R", "#{game}/rcfiles/#{user}"
    end
    Process.wait pid
    pid = fork do
      #tmp = %[mktemp]
      #system "diff -EbBu #{game}/rcfiles/#{Config.config["games"][game]["defaultrc"]} \"#{game}/rcfiles/#{user}\" > #{tmp}"
      #system "vim-highlight/vim-highlight", "--title", "#{user}.diff", tmp, "#{game}/rcfiles/diff/#{user}.diff.html"
      #FileUtils.rm tmp
      system *cmd_safe('diff -EbBu "$1" "$2" | vim-highlight/vim-highlight --title "$3" - "$4"', "#{game}/rcfiles/#{Config.config["games"][game]["defaultrc"]}", "#{game}/rcfiles/#{user}", "#{user}.diff", "#{game}/rcfiles/diff/#{user}.diff.html")
    end
    Process.detach pid
  end
end
