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

  def self.game
    @game
  end

  class Game
    attr_reader :ttyrec, :idle, :rows, :cols, :player, :game, :time
    def initialize(filename)
      @ttyrec = filename
      #if File.exists? "pid/" + filename then
      #  File.open "pid/" + filename do |file|
      #    @pid = file.readline.to_i
      #  end
      #else @pid = 0 end
      now = Time.new
      @idle = now - File.new("inprogress/" + filename).mtime
      split = filename.split
      @player = split[0]
      @game = split[1]
      @time = split[2]
      @rows = 24 #todo: detect size
      @cols = 80
    end
  end

  def self.populate
    @games = []
    Dir.foreach("inprogress") do |f|
      unless f == "." or f == ".." then
        @games += [Game.new(f)]
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
  
  def self.ttyrec(user, executable, options, env)
    ttyrec = user + " " + executable.capitalize +  " " + DateTime.now.to_s
    env.each do |e|
      ENV[e[0]] = e[1]
    end
    pid = fork do 
      system "ttyrec", "inprogress/" + ttyrec, "-e", "ttyrec -e" + "/usr/games/" + executable + " " + options
    end
    @game = Game.new(ttyrec)
    Process.wait pid
#    Thread.new do
#      pid_game = 0
#      File.open "pid/" + ttyrec do |file|
#        pid_game = file.readline.to_i
#      end
#      Process.kill("HUP", pid_game)
#      FileUtils.rm "pid/" + ttyrec
      system "gzip", "-q", "inprogress/" + ttyrec
      FileUtils.mv "inprogress/" + ttyrec + ".gz", "ttyrec/"
#    end
  end

  def self.ttyplay(file)
    system "./bin/ttyplay", "-n", "-p", file
  end

  def self.editrc(user, game)
    system "nano", "-R", "rcfiles/" + user + "." + game
  end

end
