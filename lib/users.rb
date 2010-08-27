require 'lib/config'
require 'fileutils'
require 'mongo'
require 'base64'
require 'lib/password'

module Users
  USERDB = 'userdb'
  USERCOLL = 'user_salt'
  @conn = Mongo::Connection.new
  @db = @conn[USERDB]
  @coll = @db[USERCOLL]

  def self.coll
    @coll
  end

  def self.exists?(user)
    @coll.find_one('name' => user) != nil
  end

  def self.add_or_modify(user, pass_plain)
    pass = Password.new_from_password pass_plain
    @usercoll.find_and_modify({
      :query => {'user' => user},
      :upsert => true,
      :update => {'user' => user, :password => pass.to_s}
    })
  end

  def self.set_email(user)
  end

  def self.check_name(name)
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

  def self.login(user, pass_plain)
    info = coll.find_one({'user' => name})
    if info then
      pass = Password.new info['password']
      if pass == pass_plain then
        # TODO: Move filesystem stuff
        RlConfig.config["games"].each_pair do |game, config|
          FileUtils.mkdir_p "#{game}/stuff/#{userinfo['name']}"
          if config.key? "defaultrc" then
            unless File.exists? "#{game}/init/#{userinfo['name']}.txt" then
              FileUtils.cp config["defaultrc"], "#{game}/init/#{userinfo['name']}.txt"
            end
          end
        end
      end
    end
    info.delete_if do |key, value|
      key = 'password'
    end
  end
end
