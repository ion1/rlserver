$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'fileutils'
require 'mongo'

require 'config'
require 'log'

module RLServer
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
      user.chomp!
      @coll.find_one('user' => user) != nil
    end

    def self.add(user, pass_plain)
      RLServer.log.info "New user: #{user}"
      @coll.update(
        {'user' => user},
        {'user' => user, :password => MiscHacks::Password.new_from_password(pass_plain).to_s},
        {:upsert => true}
      )
    end

    def self.email(user, email)
    end

    def self.check_name(name)
      if name then
        name.force_encoding 'UTF-8'
        name == name[/[\w\d_\-]+/]
      else
        nil
      end
    end

    def self.login(user, pass_plain)
      info = coll.find_one({'user' => user})
      if info then
        if MiscHacks::Password.new(info['password']) =~ pass_plain then
          # TODO: Move filesystem stuff
          Config.config["games"].each_pair do |game, config|
            FileUtils.mkdir_p "#{game}/stuff/#{info['user']}"
            if config.key? "defaultrc" then
              unless File.exists? "#{game}/init/#{info['user']}.txt" then
                FileUtils.cp config["defaultrc"], "#{game}/init/#{info['user']}.txt"
              end
            end
          end
        else
          info = nil
        end
      end
      if info then
        RLServer.log.info "Login successful: #{user}"
      else
        RLServer.log.warn "Login failed: #{user}"
      end
      info
    end
  end
end
