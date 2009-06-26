require "fileutils"
require "menu"
require "games"

module Config
  CONFIG = "config"

  def self.load_config_file(file)
    config = {}
    File.foreach file do |line|
      key, value = line.split "=", 2
      if key and value then
        config[key.strip] = value.strip
      end
    end
    config
  end

  def self.load_config_dir(dir)
    config = {}
    path = File.expand_path(dir) + "/"
    Dir.foreach path do |file|
      if File.directory? path + file then
        if file != ".." and file != "." then
          config[file] = load_config_dir path + file
        end
      else
        config[file] = load_config_file path + file
      end
    end
    config
  end

  def self.initialize
    @config = load_config_dir CONFIG
    ENV.each_key do |k|
      case k
      when "LANG", "LANGUAGE", /\ALC_/: ENV.delete k
      end
      ENV["LANG"] = "en_US.UTF-8" #should this be in the config?
    end
    Signal.trap "HUP" do
      Menu.destroy
      if Games.socket then
        system "screen", "-D", Games.socket
      end
      exit 1
    end
    Dir.chdir @config["dir"]
  end
end
