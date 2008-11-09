require "lib/ui"
require "lib/users"

module Menu
  def self.initialize
    UI::initialize
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

  def self.mainmenu
    @window.clear
    if @user == ""
      @window.puts "(L)ogin\n"
      @window.puts "(N)ew user\n"
    else
      @window.puts "Welcome " + @user + "\n"
    end
    @window.puts "(W)atch games\n"
    @window.puts "(Q)uit\n"
    UI::noecho
    key = ""
    while key != "q" do
      keycode = @window.getc
      @window.puts keycode.to_s
    end
  end
    
  def self.destroy
    UI::destroy
  end
end
