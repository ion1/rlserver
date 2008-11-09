require "date"

module Games
  def self.crawl(user)
    ttyrec = "inprogress/" + user + "\\ " + DateTime.now.to_s + ".ttyrec"
    system "ttyrec " + ttyrec + " -e \"crawl -name " + user + "\""
    system "mv " + ttyrec + " ttyrec"
  end
end
