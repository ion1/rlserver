require "fileutils"
require "menu"
require "games"
require "users"

module Config
  CONFIG = "/etc/rlserver"
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

  def self.init_files
    @config["games"].each_key do |game|
      FileUtils.mkdir_p "#{game}/ttyrec"
      FileUtils.mkdir_p "#{game}/rcfiles/diff"
      Dir.foreach Config.config["games"][game]["rcfiles"] do |file|
        if file != ".." and file != "." then
          unless File.exists? "#{game}/rcfiles/#{file}" then
            FileUtils.cp "#{Config.config["games"][game]["rcfiles"]}/#{file}", "#{game}/rcfiles"
          end
        end
      end
    end
    Users.users.each_key do |name|
      @config["games"].each_pair do |game, config|
        if config.key? "directories" then
          config["directories"].split(" ").each do |dir|
            dir.gsub! /%user%/, name
            dir.gsub! /%game%/, game
            FileUtils.mkdir_p "#{game}/#{dir.strip}"
          end
        end
      end
    end
  end

  def self.initialize (*file)
    if file = [] then
      @config = load_config_dir CONFIG
    else
      @config = load_config_dir *file
    end
  end
end
