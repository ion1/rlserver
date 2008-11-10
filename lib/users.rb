#!/usr/bin/env ruby
#Module Users

require 'digest'
require 'yaml'
require 'server'

module Users
  USERS = 'user'
  def self.load
    if File.exists? USERS then
      @users = YAML::load_file USERS
    else
      @users = []
      save
    end
  end
  class User
    attr_accessor :name, :password
    def initialize(name, password)
      @name = name.chomp
      @password = Digest::SHA256.digest password.chomp
    end
  end
  
  def self.save
    File.open USERS, 'w' do |out|
      YAML.dump @users, out
    end
  end

  def self.exists(username)
    exists = false
    @users.each do |user|
      unless exists
        exists = user.name == username
      end
    end
    exists
  end

  def self.adduser(name, password, password2)
    if (name != "") and (password != "") and (password == password2)
      unless exists name 
        @users = @users + [self::User.new(name, password)]
        save
      end
      true
    else
      false
    end
  end

  def self.getid(name)
    id = -1
    if exists(name) then
      for i in 0..@users.length-1 do
        if @users[i].name == name then id = i end
     end
    end
    id
  end

  def self.checkname(name)
    valid = true
    name.each_byte do |b|
      case b 
      when 45, 48..57, 65..90, 95, 97..122:
      else 
        valid = false
        break
      end
    end
    valid
  end

  def self.changepass(name, password, password2)
    if (name != "") and (password != "") and (password == password2)
      @users[getid(name.chomp)].password = Digest::SHA256.digest(password.chomp)
      save
      true
    else
      false
    end
  end
  
  def self.login(name, password)
    login = ""
    @users.each do |user|
      if login == ""
        if (user.name == name.chomp) and (user.password == Digest::SHA256.digest(password.chomp))
          login = user.name
        end
      end
    end
    login
  end
end

