require "date"
require "server"
require "escape"

module Games
  def self.crawl(user)
    ttyrec = user + " " + DateTime.now.to_s + ".ttyrec"
    system Escape.shell_command(["ttyrec ", Server::SERVER_DIR + "inprogress/" + ttyrec,"-e","/usr/games/crawl -name " + user])
    system "apack \"" + Server::SERVER_DIR + "ttyrec/" + ttyrec + ".tgz\" \"" + Server::SERVER_DIR + "inprogress/" + ttyrec + "\""
  end
end
