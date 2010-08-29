require 'lib/config'
require 'fileutils'
require 'rubygems'
require 'mongo'
require 'base64'
require 'password/password'

module Users
  USERS = 'users'
  USERDB = 'userdb'
  USERCOLL = 'user_salt'
  @conn = Mongo::Connection.new
  @db = @conn[USERDB]
  @coll = @db[USERCOLL]

  def self.exists?(user)
    user.chomp!
    @coll.find_one('user' => user) != nil
  end

  def self.add(user, pass_plain)
    pass = Password.new_from_password pass_plain
    @coll.update(
      {'user' => user},
      {'user' => user, :password => pass.to_s},
      {:upsert => true}
    )
  end

  def self.email(user, email)
  end

  def self.check_name(name)
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

  def self.login(user, pass_plain)
    info = @coll.find_one({'user' => user})
    if info then
      pass = Password.new info['password']
      if pass == pass_plain then
        # TODO: Move filesystem stuff
        Config.config["games"].each_pair do |game, config|
          FileUtils.mkdir_p "#{game}/stuff/#{info['user']}"
          if config.key? "defaultrc" then
            unless File.exists? "#{game}/init/#{info['user']}.txt" then
              FileUtils.cp config["defaultrc"], "#{game}/init/#{info['user']}.txt"
            end
          end
        end
      end
    end
    info
  end
end
