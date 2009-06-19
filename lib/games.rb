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

  class Game
    attr_reader :socket, :idle, :player, :game, :time
    def initialize(name)
      @socket = name
      now = Time.new
      @idle = now - File.new("inprogress/" + name).mtime
      split = name.split(".")
      @player = split[0]
      @game = split[1]
      @time = split[2]
    end
  end

  def self.populate
    @games = []
    Dir.foreach("socket") do |f|
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
  
  def self.launchgame(user, executable, gamename, options, env)
    ttyrec = user + "." + gamename + "." + DateTime.now.to_s + ".ttyrec"
    env.each do |e|
      ENV[e[0]] = e[1]
    end
    #pid = fork do
    system "ttyrec", "inprogress/" + ttyrec, "-e", "dtach -A socket/" + ttyrec + " -E -z " + executable + " " + options
    #end
    #sleep 1
    #@game = Game.new(ttyrec)
    #Process.wait pid
    #FileUtils.rm "pid/" + ttyrec
    Thread.new do
      system "gzip", "-q", "inprogress/" + ttyrec
      FileUtils.mv "inprogress/" + ttyrec + ".gz", "ttyrec/"
    end
  end

  def self.attachgame(index)
    if index >= 0 then
      system "dtach", "-a", "socket/" + @games[index].socket, "-E", "-z"
      true
    else false end
  end

  def self.watchgame(file)
    #pid = fork do
    system "dtach", "-a", file, "-R","-e", "\q", "-z"
    #end
    #Process.wait pid
  end

  def self.editrc(user, game)
    #pid = fork do
    system "nano", "-R", "rcfiles/" + user + "." + game
    #end
    #Process.wait pid
  end

end
