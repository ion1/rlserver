require "date"
require "server"

module Games
  def self.crawl(user)
    ttyrec = Server::SERVER_DIR + "inprogress/" + user + "\\ " + DateTime.now.to_s + ".ttyrec"
    system "ttyrec " + ttyrec + " -e \"/usr/games/crawl -name " + user + "\""
    system "mv " + ttyrec + " " + " " + Server::SERVER_DIR + "ttyrec"
  end
end
