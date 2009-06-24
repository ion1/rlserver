require "date"
require "server"
require "fileutils"

module Games
  def self.socket
    @socket
  end

  def self.games
    @games
  end

  def self.by_user
    @by_user
  end

  class Game
    attr_reader :idle, :player, :game, :time, :cols, :rows, :attached, :socket
    def initialize(socket)
      pidremoved = socket.sub /\A\d*\./, ""
      @socket = pidremoved
      @idle = Time.now - File.stat("inprogress/" + pidremoved + ".ttyrec.bz2").mtime
      @attached = File.executable? "/var/run/screen/S-" + Server::SERVER_USER + "/" + socket
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
    @by_user = {}
    if File.exists? "/var/run/screen/S-" + Server::SERVER_USER then
      Dir.foreach "/var/run/screen/S-" + Server::SERVER_USER do |f|
        unless f == "." or f == ".." then
          pidremoved = f.sub /\A\d*\./, ""
          if File.exists? "inprogress/" + pidremoved + ".ttyrec.bz2" then
            @games += [game = Game.new(f)]
            @by_user[game.player] = {game.game => game}
          end
        end
      end
    end
  end

  def self.launchgame(cols, rows, user, executable, gamename, env, *options)
    populate
    if @by_user.key? user and @by_user[user].key? gamename then
      @socket = @by_user[user][gamename].socket
      puts "\033[8;#{@by_user[user][gamename].rows};#{@by_user[user][gamename].cols}t"
      @pid = fork do
        system "screen", "-D", @socket
        exec "dtach", "-A", "socket/" + @socket, "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-D", "-r", @socket
      end
    else
      @socket = user + "." + gamename + "." + cols.to_s + "x" + rows.to_s + "." + DateTime.now.to_s
      env.each do |e|
        ENV[e[0]] = e[1]
      end
      @pid = fork do
        exec "dtach", "-A", "socket/" + @socket, "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-S", @socket, "-c", "player.screenrc", "termrec", "inprogress/" + @socket + ".ttyrec.bz2", "-e", executable + " " + options.join(" ")
      end
    end
    Process.wait @pid
    populate
    unless @by_user.key? user and @by_user[user].key? gamename then
      FileUtils.mv "inprogress/" + @socket + ".ttyrec.bz2", "ttyrec/"
    end
  end

  def self.watchgame(socket)
    @pid = fork do
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
