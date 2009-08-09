require 'config'
require 'digest'
require 'yaml'
require 'fileutils'

module Users
  USERS = 'users'

  def self.loadusers
    if File.exists? USERS then
      @users = YAML.load_file USERS
    else
      @users = {}
      save
    end
  end

  def self.save
    File.open USERS, 'w' do |out|
      YAML.dump @users, out
    end
  end

  def self.exists?(username)
    loadusers
    username != "" and @users.has_key? username
  end

  def self.adduser(name, password)
    loadusers
    @users[name] = Digest::SHA256.digest password
    save
  end

  def self.checkname(name)
    loadusers
    if name then
      name.each_char do |b|
        case b 
        when " ", "-", "0".."9", "A".."Z", "_", "a".."z": true
        else 
          false
          break
        end
      end
    end
  end

  def self.login(name, password)
    loadusers
    if @users[name] == Digest::SHA256.digest(password) then
      Config.config["games"].each_pair do |game, config|
        FileUtils.mkdir_p "#{game}/stuff/#{name}"
        if config.key? "directories" then
          config["directories"].split(" ").each do |dir|
            dir.gsub! /%user%/, name
            dir.gsub! /%game%/, game
            FileUtils.mkdir_p "#{game}/#{dir.strip}"
          end
        end
        if config.key? "defaultrc" then
          unless File.exists? "#{game}/init/#{name}" then
            FileUtils.cp config["defaultrc"], "#{game}/init/#{name}"
          end
        end
      end
      name
    else nil end
  end
end
