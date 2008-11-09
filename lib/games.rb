require "date"
require "server"

module Games
  def self.crawl(user)
    ttyrec = user + " " + DateTime.now.to_s + ".ttyrec"
    system "ttyrec", "inprogress/" + ttyrec, "-e", "/usr/games/crawl -name " + user + " -rc " + "rcfiles/" + user + ".crawlrc"
    system "apack", "ttyrec/" + ttyrec + ".tgz", "inprogress/" + ttyrec, ">", "/dev/null"
    system "rm", "inprogress/" + ttyrec, ">", "/dev/null"
  end
end
