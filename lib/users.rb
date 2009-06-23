#!/usr/bin/env ruby
#Module Users

require 'digest'
require 'yaml'
require 'server'
require 'fileutils'

module Users
  USERS = 'user'
  def self.load
    if File.exists? USERS then
      @users = YAML.load_file USERS
    else
      @users = []
      save
    end
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
    @users.each do |user|
      FileUtils.mkdir_p "crawl/macro/" + user.name
      FileUtils.mkdir_p "crawl/morgue/" + user.name
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

  def self.adduser(name, password)
    if (name != "") and (password != "")
      unless exists name 
        @users = @users + [User.new(name, password)]
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
        if @users[i].name == name then
          id = i
        end
      end
    end
    id
  end

  def self.checkname(name)
    valid = true
    name.each_byte do |b|
      case b 
      when " "[0], "-"[0], "0"[0].."9"[0], "A"[0].."Z"[0], "_"[0], "a"[0].."z"[0]:
      else 
        valid = false
        break
      end
    end
    valid
  end

  def self.changepass(name, password)
    if (name != "") and (password != "")
      @users[getid(name)].password = Digest::SHA256.digest(password)
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
        if (user.name == name) and (user.password == Digest::SHA256.digest(password))
          login = user.name
        end
      end
    end
    login
  end
end

