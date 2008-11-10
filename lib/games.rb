require "date"
require "server"
require "fileutils"

module Games
  def self.ttyrec(user, gamename, executable, options, env)
    ttyrec = user + " " + gamename + " " + DateTime.now.to_s
    env.each do |e|
      ENV[e[0]] = e[1]
    end
    system "ttyrec", "inprogress/" + ttyrec, "-e", " " + executable + " " + options
    system "apack", "ttyrec/" + ttyrec + ".tgz", "inprogress/" + ttyrec
    FileUtils.rm "inprogress/" + ttyrec
  end

  def self.ttyplay(file)
    system "tail -f \""+ file + "\"|" + "ttyplay -n"
  end

  def self.editrc(user, game)
    system "nano", "-R", "rcfiles/" + user + "." + game
  end

  def self.play(user, game, options, env)
    ttyrec user, game.capitalize, "/usr/games/" + game, options, env
  end
end
