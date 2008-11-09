#!/usr/bin/env ruby
#Module User

require 'digest'
require 'yaml'

module Users
  USERS = 'user'
  def self.initialize
    @users = YAML::load_file(USERS)
  end
  class User
    attr_accessor :name, :password
    def initialize(name, password)
      @name = name
      @password = Digest::SHA256.digest(password)
    end
  end
  def self.dump
    File.open(USERS, 'w') do |out|
      YAML.dump(@users, out)
    end
  end
  def self.adduser(name, password)
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
  end
  def self.login(name, password)
    login = false
    @users.each do |user|
      if login == false
        login = (user.name == name) && (user.password == Digest::SHA256.digest(password))
      end
    end
    login
  end
end

