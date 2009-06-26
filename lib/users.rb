require 'config'
require 'digest'
require 'yaml'
require 'fileutils'

module Users
  def self.users;@users end
  USERS = 'users'

  def self.load
    if File.exists? USERS then
      @users = YAML.load_file USERS
    else
      @users = {}
      save
    end
  end

  def self.load_old
    @users = YAML.load_file "user"
  end
  
  class User
    attr_accessor :name, :password
    def initialize(name, password)
      @name = name
      @password = Digest::SHA256.digest password
    end
  end

  def self.save
    File.open USERS, 'w' do |out|
      YAML.dump @users, out
    end
  end

  def self.exists?(username)
    username != "" and @users.has_key? username
  end

  def self.adduser(name, password)
    @users[name] = Digest::SHA256.digest password
    save
  end

  def self.checkname(name)
    valid = true
    name.each_char do |b|
      case b 
      when " ", "-", "0".."9", "A".."Z", "_", "a".."z":
      else 
        valid = false
        break
      end
    end
    valid
  end

  def self.login(name, password)
    if @users[name] == Digest::SHA256.digest(password) then
      Config.config["games"].each_pair do |game, config|
        if config.key? "directories" then
          config["directories"].split(" ").each do |dir|
            dir.gsub! /%user%/, name
            dir.gsub! /%game%/, game
            FileUtils.mkdir_p "#{game}/#{dir.strip}"
          end
        end
      end
      name
    else "" end
  end
end
