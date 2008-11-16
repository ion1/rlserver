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
    attr_reader :ttyrec, :pid, :idle, :rows, :cols, :name, :game, :time
    def initialize(filename)
      @ttyrec = filename
      if File.exists? "pid/" + filename then
        File.open "pid/" + filename do |file|
          @pid = file.readline
        end
      end else @pid = 0
      now = Time.new
      @idle = now - File.new("inprogress/" + filename).mtime
      split = filename.split
      @name = split[0]
      @game = split[1]
      @time = Timeparse split[2]
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

  def self.ttyrec(user, executable, options, env)
    ttyrec = user + " " + executable.capitalize +  " " + DateTime.now.to_s
    env.each do |e|
      ENV[e[0]] = e[1]
    end
    system "ttyrec", "inprogress/" + ttyrec, "-e", "./run \"pid/" + ttyrec + "\" " + "/usr/games/" + executable + " " + options
    Thread.new do
      FileUtils.rm "pid/" + ttyrec
      system "gzip", "-q", "inprogress/" + ttyrec
      FileUtils.mv "inprogress/" + ttyrec + ".gz", "ttyrec/"
    end
  end

  def self.ttyplay(file)
    system "./bin/ttyplay", "-n", "-p", file
  end

  def self.editrc(user, game)
    system "nano", "-R", "rcfiles/" + user + "." + game
  end

end
