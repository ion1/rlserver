require "date"
require "server"
require "fileutils"

module Games
  def self.initialize
    @games = []
  end

  def self.games=(games)
    @games = games
  end

  def self.games
    @games
  end

  def self.socket
    @socket
  end

  class Game
    attr_reader :socket, :idle, :player, :game, :time, :cols, :rows, :attached
    def initialize(name)
      pidremoved = name.sub /\A\d*\./, ""
      @socket = pidremoved
      now = Time.new
      @idle = now - File.stat("inprogress/" + pidremoved + ".ttyrec.bz2").mtime
      @attached = File.executable? "/var/run/screen/S-" + Server::SERVER_USER + "/" + name
      split = pidremoved.split(".")
      @player = split[0]
      @game = split[1]
      @cols = split[2].split("x")[0].to_i
      @rows = split[2].split("x")[1].to_i
      @time = split[3]
    end
  end

  def self.populate
    @games = []
    if File.exists? "/var/run/screen/S-" + Server::SERVER_USER then
      Dir.foreach("/var/run/screen/S-" + Server::SERVER_USER) do |f|
        unless f == "." or f == ".." then
          pidremoved = f.sub /\A\d*\./, ""
          if File.exists? "inprogress/" + pidremoved + ".ttyrec.bz2" then
            @games += [Game.new(f)]
          end
        end
      end
    end
  end

  def self.index(player, game)
    index = -1
    for i in 0..@games.length-1 do 
      if @games[i].player == player and @games[i].game == game then
        index = i
        break
      end
    end
    index
  end
  
  def self.launchgame(cols, rows, user, executable, gamename, env, *options)
    populate
    i = index user, gamename
    if i >= 0 then
      @socket = @games[i].socket
      puts "\033[8;#{Games.games[i].rows};#{Games.games[i].cols}t"
      @pid = fork do
        exec "dtach", "-A", "socket/" + @socket, "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-D", "-r", @socket
        #exec "screen", "-D", "-r", @socket
      end
    else
      #size = Termsize.new(Menu.menuwindow.columns, Menu.menuwindow.rows)
      @socket = user + "." + gamename + "." + cols.to_s + "x" + rows.to_s + "." + DateTime.now.to_s
      env.each do |e|
        ENV[e[0]] = e[1]
      end
      @pid = fork do
        exec "dtach", "-A", "socket/" + @socket, "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-S", @socket, "-c", "player.screenrc", "termrec", "inprogress/" + @socket + ".ttyrec.bz2", "-e", executable + " " + options.join(" ")
        #exec "screen", "-S", @socket, "-c", "player.screenrc", "termrec", "inprogress/" + @socket + ".ttyrec.bz2" , "-e", executable + " " + options.join(" ")
      end
    end
    Process.wait @pid
    pid.fork do
      populate
      i = index user, gamename
      if i < 0 then
        FileUtils.mv "inprogress/" + @socket + ".ttyrec.bz2", "ttyrec/"
      end
    end
  end

  def self.watchgame(socket)
    @pid = fork do
      #dtach -A socket -R -s -e q -z -r screen screen -x socket
      #exec "dtach", "-A", "socket/" + socket, "-R", "-e", "\q", "-r", "screen", "-C", "^\\", "-z", "screen", "-x", socket
      exec "dtach", "-a", "socket/" + socket, "-R", "-e", "\q", "-r", "screen", "-C", "^\\", "-z", "-s"
    end
    Process.wait @pid
  end

  def self.editrc(user, game)
    @pid = fork do
      exec "nano", "-R", "rcfiles/" + user + "." + game
    end
    Process.wait @pid
  end
end
