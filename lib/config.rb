require "fileutils"
require "menu"
require "games"

module Config
  CONFIG = "config"
  def self.config;@config end

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
    @config["games"].each_key do |game|
      FileUtils.mkdir_p "#{game}/ttyrec"
      FileUtils.mkdir_p "#{game}/rcfiles/diff"
      FileUtils.cp_r "#{Config.config["games"][game]["rcfiles"]}/.", "#{game}/rcfiles"
    end
  end
end
