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
    attr_reader :ttyrec
    def initialize(filename)
      @ttyrec = filename
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
    system "ttyrec", "inprogress/" + ttyrec, "-e", "/usr/games/" + executable + " " + options
    Thread.new do
      system "apack", "-q", "ttyrec/" + ttyrec + ".gz", "inprogress/" + ttyrec
      FileUtils.rm "inprogress/" + ttyrec
    end
  end

  def self.ttyplay(file)
    system "./bin/ttyplay", "-n", "-p", file
  end

  def self.editrc(user, game)
    system "nano", "-R", "rcfiles/" + user + "." + game
  end

end
