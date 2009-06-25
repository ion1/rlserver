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
    attr_reader :idle, :player, :game, :time, :cols, :rows, :attached, :socket, :screen_pid
    def initialize(data)
      @screen_pid = data[0].to_i
      @socket = data[1,4].join "."
      @attached = File.executable? "/var/run/screen/S-#{Server::SERVER_USER}/#{@screen_pid}.#{@socket}"
      @player = data[1]
      @game = data[2]
      @cols = data[3].split("x")[0].to_i
      @rows = data[3].split("x")[1].to_i
      @time = data[4]
      if File.exists? "inprogress/#{@socket}.ttyrec.bz2" then
        @idle = Time.now - File.stat("inprogress/#{@socket}.ttyrec.bz2").mtime
      elsif File.exists? "crawl/ttyrec/#{@player}/#{@socket}.ttyrec.bz2" then
        @idle = Time.now - File.stat("crawl/ttyrec/#{@player}/#{@socket}.ttyrec.bz2").mtime
      end
    end
  end

  def self.populate
    @games = []
    @by_user = {}
    @by_socket = {}
    if File.exists? "/var/run/screen/S-#{Server::SERVER_USER}" then
      Dir.foreach "/var/run/screen/S-#{Server::SERVER_USER}" do |f|
        if f.match /(\d+)\.([\w\d\s\-_ ]+)\.(\w+)\.(\d+x\d+)\.(\d+-\d\d-\d\dT\d\d:\d\d:\d\d\+\d\d:\d\d)/ then
          @games += [game = Game.new($~[1,6])]
          @by_user[game.player] = {game.game => game}
          @by_socket[game.socket] = game
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
        exec "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-D", "-r", @socket
      end
    else
      @socket = "#{user}.#{gamename}.#{cols}x#{rows}.#{DateTime.now}"
      env.each do |e|
        ENV[e[0]] = e[1]
      end
      @pid = fork do
        exec "dtach", "-A", "socket/#{@socket}", "-E", "-r", "screen", "-C", "^\\", "-z", "screen", "-S", @socket, "-c", "player.screenrc", "termrec", "crawl/ttyrec/#{user}/#{@socket}.ttyrec.bz2", "-e", "#{executable} #{options.join(" ")}"
      end
    end
    Process.wait @pid
  end

  def self.watchgame(socket)
    @pid = fork do
      exec "dtach", "-a", "socket/#{socket}", "-R", "-e", "\q", "-r", "screen", "-C", "^\\", "-z", "-s"
    end
    Process.wait @pid
  end

  def self.editrc(user, game)
    @pid = fork do
      exec "nano", "-R", "rcfiles/#{user}.#{game}"
    end
    Process.wait @pid
  end
end
