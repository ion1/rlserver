require "fileutils"
require "lib/menu"
require "lib/games"
require "lib/users"

module Config
  RL_CONFIG = "/etc/rlserver"
  def self.config;@config end

  def self.load_config_file(file)
    config = {}
    File.foreach file do |line|
      key, value = line.split "=", 2
      if key and value then
        config[key.strip] = value.strip.gsub /\\n/, "\n"
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

  def self.initialize (*file)
    if file = [] then
      @config = load_config_dir RL_CONFIG
    else
      @config = load_config_dir *file
    end
  end
end
