# Roguelike server in the spirit of dgamelaunch
#
# CANNOT BE ARSED PUBLIC LICENSE
# TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
# 0. You just DO WHAT THE FUCK YOU WANT TO.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')
require 'date'
require 'fileutils'
require 'mischacks'
require 'digest'
require 'base64'
require 'ncurses'

# TODO: Simple tmux wrapper; lots of duplicated shit
require 'tmux-ruby/lib/tmux'
require 'config'
require 'log'

module RLServer
  module Games
    PLAY_SERVER = 'rlserver'
    WATCH_SERVER = 'rlwatch'
    @play = Tmux::Server.new PLAY_SERVER
    @watch = Tmux::Server.new WATCH_SERVER

    def self.sessions(search = {})
      sessions = []
      @play.sessions.each do |ses|
        info = ses.name.match(/^(?<user>[\w\d\-_]+?)\.(?<game>[\w\d\-_\.]+?)\.(?<size>\d+x\d+)\.(?<date>.+)$/)
        if info then
          width, height = info[:size].split('x')
          ttyrec = "#{Config.config['server']['path']}/#{info[:game]}/stuff/#{info[:user]}/#{ses.name}.ttyrec"
          sessions << {
            :name => ses.name,
            :user => info[:user],
            :game => info[:game],
            :shortname => "#{Config.config['games'][info[:game]]['name']} #{Config.config["games"][info[:game]]["version"]}",
            :longname => "#{Config.config['games'][info[:game]]['longname']} #{Config.config["games"][info[:game]]["version"]}",
            :width => width,
            :height => height,
            :date => DateTime.parse(info[:date]),
            :attached => ses.attached,
            :ttyrec => ttyrec,
            :idle => File.exists?(ttyrec) ? Time.now - File.stat(ttyrec).mtime : 0,
          }
        end
      end
      sessions.select do |ses|
        ses.all? do |key, value|
          !search.has_key?(key) || value == search[key]
        end
      end
    end

    def self.launchgame(user, game)
      if Config.config['games'][game].key? 'chdir' then
        pushd = Dir.pwd
        Dir.chdir(Config.config['games'][game]['chdir'])
      end
      height = Ncurses.getmaxy Ncurses.stdscr
      width = Ncurses.getmaxx Ncurses.stdscr
      @session = Games.sessions({:user => user, :game => game}).first
      if @session then
        ENV['TMUX'] = ''
        print "\033[8;#{@session[:height]};#{@session[:width]}t"
        MiscHacks.sh('stty rows "$1"; stty cols "$2"', @session[:height], @session[:width])
        MiscHacks.sh(
          %{exec "$tmux_bin" -f "$config" -L "$server" attach -t "$session"},
          :tmux_bin => Tmux.binary,
          :config => "#{Config.config['server']['path']}/play.conf",
          :server => PLAY_SERVER,
          :session => @session[:name],
        )
      else
        date = DateTime.now
        name = "#{user}.#{game}.#{width}x#{height}.#{date}"
        @session = {
          :name => name,
          :user => user,
          :game => game,
          :shortname => "#{Config.config['games'][game]['name']} #{Config.config["games"][game]["version"]}",
          :longname => "#{Config.config['games'][game]['longname']} #{Config.config["games"][game]["version"]}",
          :width => width,
          :height => height,
          :date => date,
          :ttyrec => "#{Config.config['server']['path']}/#{game}/stuff/#{user}/#{name}.ttyrec",
        }
        if Config.config['games'][game].key? 'env' then
          Config.config['games'][game]['env'].split(' ').each do |env|
            env.gsub! /%path%/, Config.config['server']['path']
            env.gsub! /%user%/, user
            env.gsub! /%game%/, game
            var, set = env.split '='
            ENV[var.strip] = set.strip
          end
        end
        options = []
        if Config.config['games'][game].key? 'parameters' then
          Config.config['games'][game]['parameters'].split(' ').each do |arg|
            arg.gsub! /%path%/, Config.config['server']['path']
            arg.gsub! /%user%/, user
            arg.gsub! /%game%/, game
            options << %{'#{arg.strip}'}
          end
        end
        ENV['TMUX'] = ''
        MiscHacks.sh(
          %{exec "$tmux_bin" -f "$config" -L "$server" new -s "$session" "exec $ttyrec_bin $ttyrec -e '$game_bin $options'"},
          :tmux_bin => Tmux.binary,
          :config => "#{Config.config['server']['path']}/play.conf",
          :ttyrec => @session[:ttyrec],
          :ttyrec_bin => "#{Config.config['server']['path']}/termrec",
          :server => PLAY_SERVER,
          :session => @session[:name],
          :game_bin => Config.config['games'][game]['binary'],
          :options => options.join(' '),
          :width => width,
          :height => height,
        )
      end
      if Config.config['games'][game].key? 'chdir' then
        Dir.chdir(pushd)
      end
      unless Games.sessions({:user => user, :game => game}).first then
        bzip2 = fork do
          MiscHacks.sh('exec bzip2 "$1"', @session[:ttyrec])
        end
        Process.detach bzip2
      end
      print "\033[8;#{height};#{width}t"
      MiscHacks.sh('stty rows "$1"; stty cols "$2"', height, width)
    end

    def self.watchgame(session)
      width = Ncurses.getmaxx Ncurses.stdscr
      height = Ncurses.getmaxy Ncurses.stdscr
      @session = Games.sessions({:name => session}).first
      if @session then
        begin
          print "\033[8;#{@session[:height]};#{@session[:width]}t"
          ENV['TMUX'] = ''
          watch_session = Digest::SHA256.hexdigest("#{@session[:name]}#{ENV['SSH_CLIENT']}")
          unless @play.sessions({:name => watch_session}).first then
            MiscHacks.sh(
              %{stty rows "$height"; stty cols "$width"; exec "$tmux_bin" -f "$config" -L "$server" new -d -s "$watch_session" -t "$session"},
              :config => "#{Config.config['server']['path']}/play.conf",
              :watch_config => "#{Config.config['server']['path']}/watch.conf",
              :watch_session => watch_session,
              :session => @session[:name],
              :tmux_bin => Tmux.binary,
              :server => PLAY_SERVER,
              :height => @session[:height],
              :width => @session[:width],
            )
            MiscHacks.sh(
              %{"$dtach_bin" -n "/tmp/$watch_session" -E -r none sh -c 'stty rows "$height"; stty cols "$width"; "$tmux_bin" -L "$server" attach -r -d -t "$watch_session"'},
              :dtach_bin => "#{Config.config['server']['path']}/dtach",
              :watch_session => watch_session,
              :tmux_bin => Tmux.binary,
              :server => PLAY_SERVER,
              :height => @session[:height],
              :width => @session[:width],
            )
          end
          MiscHacks.sh(
            %{exec "$dtach_bin" -a "/tmp/$session" -e \q -R -r none},
            :dtach_bin => "#{Config.config['server']['path']}/dtach",
            :session => watch_session,
            :height => @session[:height],
            :width => @session[:width],
          )
        rescue Exception => exc
          if @play.sessions({:name => watch_session}).first then
            MiscHacks.sh(
              %{exec "$tmux_bin" -L "$server" kill-session -t "$session"},
              :tmux_bin => Tmux.binary,
              :server => PLAY_SERVER,
              :session => watch_session,
            )
          end
        ensure
          if @play.sessions({:name => watch_session}).first then
            MiscHacks.sh(
              %{exec "$tmux_bin" -L "$server" kill-session -t "$session"},
              :tmux_bin => Tmux.binary,
              :server => PLAY_SERVER,
              :session => watch_session,
            )
          end
          print "\033[8;#{height};#{width}t"
          MiscHacks.sh('stty rows "$1"; stty cols "$2"', height, width)
        end
      end
    end

    def self.editrc(user, game)
      MiscHacks.sh('exec nano -R "$1"', "#{Config.config['server']['path']}/#{game}/init/#{user}.txt")
    end
  end
end
