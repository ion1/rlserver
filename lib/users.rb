#!/usr/bin/env ruby
#Module Users

require 'digest'
require 'yaml'

module Users
  USERS = 'user'
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
  
  def self.adduser(name, password)
    if (name > "") && (password > "")
      exists = false
      @users.each do |user|
        if exists == false
          exists = user.name == name
        end
      end
      if exists == false 
        @users = @users + [self::User.new(name, password)]
      end
      exists == false
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

