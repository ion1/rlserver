require "ui"
require "users"
require "games"

module Menu
  def self.initialize
    UI::initialize
    Users::load
    @window = UI::Window.new(0,0,0,0)
    @user = ""
  end

  def self.login
    @window.clear
    @window.puts "Username: "
    UI::echo
    name = @window.gets
    @window.puts "Password: "
    UI::noecho
    pass = @window.gets
    Users::login(name, pass)
  end

  def self.newuser
    name = ""
    pass = ""
    pass2 = ""
    @window.clear
    @window.puts "Creating new user.\n"
    @window.puts "Username: "
    UI::echo
    name = @window.gets
    if Users::exists(name) then
      name = ""
    else
      UI::noecho
      @window.puts "Password: "
      pass = @window.gets
      @window.puts "Retype password: "
      pass2 = @window.gets
      Users::adduser(name, pass, pass2)
      Users::login(name, pass)
    end
  end

  def self.watch
  end

  def self.games
    UI::noecho
    quit = false
    while quit == false do
      @window.clear
      @window.puts "C - Crawl\n"
      @window.puts "Q - Quit\n"
      UI::refresh
      key = @window.getc
      case key
      when 81,113: quit = true
      when 67,99: Games::crawl(@user)
      end
    end
  end

  def self.mainmenu
    UI::noecho
    quit = false
    key = 0
    while quit == false do
      @window.clear
      if @user == ""
        @window.puts "L - Login\n"
        @window.puts "N - New user\n"
      else
        @window.puts "Logged in as " + @user + "\n"
        @window.puts "G - Games\n"
      end
      @window.puts "W - Watch\n"
      @window.puts "Q - Quit\n"
      @window.puts key.to_s + "\n"
      UI::refresh
      key = @window.getc
      case key
      when 71,103: if @user != "" then games end
      when 76,108: if @user == "" then @user = login end#L
      when 78,110: if @user == "" then @user = newuser end#N
      when 87,119: watch #W
      when 81,113: quit = true #Q
      end
    end
  end
    
  def self.destroy
    UI::destroy
  end
end
