module Server
  SERVER_DIR = "/home/shared/joosa/src/rlserver/"
  SERVER_USER = "joosa"
  def self.initialize
    @pid = Process.pid
    @ppid = Process.ppid
  end
  def pid
    @pid
  end
  def ppid
    @ppid
  end
end
