require "date"
require "server"

module Games
  def self.crawl(user)
    ttyrec = Server::RLSERVER_DIR + "inprogress/" + user + "\\ " + DateTime.now.to_s + ".ttyrec"
    system "ttyrec " + ttyrec + " -e \"crawl -name " + user + "\""
    system "mv " + ttyrec + " ttyrec"
  end
end
