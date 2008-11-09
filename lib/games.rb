require "date"
require "server"

module Games
  def self.crawl(user)
    ttyrec = user + " " + DateTime.now.to_s + ".ttyrec"
    system "ttyrec", Server::SERVER_DIR + "inprogress/" + ttyrec, "-e", "/usr/games/crawl -name " + user + "-rc " + Server::SERVER_DIR + "rcfiles/" + user + ".crawlrc"
    system "apack", Server::SERVER_DIR + "ttyrec/" + ttyrec + ".tgz", Server::SERVER_DIR + "inprogress/" + ttyrec
    system "rm", Server::SERVER_DIR + "inprogress/" + ttyrec
  end
end
