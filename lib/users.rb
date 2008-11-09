#!/usr/bin/env ruby
#Module Users

require 'digest'
require 'yaml'
require 'server'

module Users
  USERS = Server::SERVER_DIR + 'user'
  def self.load
    @users = YAML::load_file(USERS)
  end
  class User
    attr_accessor :name, :password
    def initialize(name, password)
      @name = name
      @password = Digest::SHA256.digest(password)
    end
  end
  
  def self.save
    File.open(USERS, 'w') do |out|
      YAML.dump(@users, out)
    end
  end

  def self.exists(username)
    exists = false
    @users.each do |user|
      if exists == false
        exists = user.name == username
      end
    end
    exists
  end

  def self.adduser(name, password,password2)
    if (name > "") && (password > "") && (password == password2)
      if exists(name) == false 
        @users = @users + [self::User.new(name, password)]
        save
      end
      true
    else
      false
    end
  end
  
  def self.login(name, password)
    login = ""
    @users.each do |user|
      if login == ""
        if (user.name == name.chomp) && (user.password == Digest::SHA256.digest(password.chomp))
          login = user.name
        end
      end
    end
    login
  end
end

