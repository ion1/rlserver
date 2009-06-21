require "date"
require "server"
require "fileutils"
require "menu"
require "ui"

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

  class Game
    attr_reader :socket, :idle, :player, :game, :time, :size, :attached
    def initialize(name)
      pidremoved = name.sub /\A\d*\./, ""
      @socket = pidremoved
      now = Time.new
      @idle = now - File.new("inprogress/" + pidremoved).mtime
      @attached = File.executable? "/var/run/screen/S-" + Server::SERVER_USER + "/" + name
      split = pidremoved.split(".")
      @player = split[0]
      @game = split[1]
      @size = Termsize.new split[2].split("x")[0].to_i, split[2].split("x")[1].to_i
      @time = split[3]
    end
  end

  class Termsize
    attr_reader :cols, :rows
    def initialize(cols, rows)
      @rows = rows
      @cols = cols
    end
  end

  def self.populate
    @games = []
    if File.exists? "/var/run/screen/S-" + Server::SERVER_USER then
      Dir.foreach("/var/run/screen/S-" + Server::SERVER_USER) do |f|
        unless f == "." or f == ".." then
          pidremoved = f.sub /\A\d*\./, ""
          if File.exists? "inprogress/" + pidremoved then
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
  
  def self.launchgame(user, executable, gamename, env, *options)
    populate
    i = index user, gamename
    if i >= 0 then
      socket = @games[i].socket
      puts "\033[8;#{Games.games[i].size.rows};#{Games.games[i].size.cols}t"
      system "dtach", "-A", "socket/" + socket, "-E", "-r", "screen", "-z", "screen.real", "-D", "-r", socket
    else
      size = Termsize.new(Menu.menuwindow.columns, Menu.menuwindow.rows)
      socket = user + "." + gamename + "." + size.cols.to_s + "x" + size.rows.to_s + "." + DateTime.now.to_s
      env.each do |e|
        ENV[e[0]] = e[1]
      end
      system "dtach", "-A", "socket/" + socket, "-E", "-r", "screen", "-z", "screen.real", "-S", socket, "-c", "player.screenrc", "ttyrec", "inprogress/" + socket , "-e", executable + " " + options.join(" ")
    end
    populate
    i = index user, gamename
    if i < 0 then
      Thread.new do
        FileUtils.mv "inprogress/" + socket, "inprogress/" + socket + ".ttyrec"
        system "gzip", "-q", "inprogress/" + socket + ".ttyrec"
        FileUtils.mv "inprogress/" + socket + ".ttyrec.gz", "ttyrec/"
      end
    end
  end

  def self.watchgame(socket)
    system "dtach", "-a", "socket/" + socket, "-e", "\q", "-R", "-s", "-r", "screen", "-z"
  end

  def self.editrc(user, game)
    system "nano", "-R", "rcfiles/" + user + "." + game
  end

end
