require 'lib/config'
require 'digest'
require 'yaml'
require 'fileutils'
require 'rubygems'
require 'mongo'
require 'base64'

module Users
  USERS = 'users'
  USERDB = 'userdb'
  USERCOLL = 'users'
  @conn = Mongo::Connection.new
  @userdb = @conn[USERDB]
  @usercoll = @userdb[USERCOLL]

  def self.user
    @user
  end

  def self.users
    @users
  end

  def self.usercoll
    @usercoll
  end

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
    @usercoll.find_one('name' => username) != nil
  end

  def self.adduser(name, password)
    userinfo = ['name' => name, 'pwdhash' => Base64.encode64(Digest::SHA256.digest(password))]
    @usercoll.remove('name' => name)
    @usercoll.insert userinfo
  end

  def self.checkname(name)
    if name then
      name.each_char do |b|
        case b 
        when " ", "-", "0".."9", "A".."Z", "_", "a".."z"
          true
        else 
          false
          break
        end
      end
    end
  end

  def self.login(name, password)
    userinfo = @usercoll.find_one('name' => name, 'pwdhash' => Base64.encode64(Digest::SHA256.digest(password)))
    if userinfo then
      RlConfig.config["games"].each_pair do |game, config|
        FileUtils.mkdir_p "#{game}/stuff/#{userinfo['name']}"
        if config.key? "defaultrc" then
          unless File.exists? "#{game}/init/#{userinfo['name']}.txt" then
            FileUtils.cp config["defaultrc"], "#{game}/init/#{userinfo['name']}.txt"
          end
        end
      end
    end
    userinfo
  end
end
