#!/usr/bin/env ruby
# Module UI

require "ncurses"

module UI

  A_NORMAL = Ncurses::A_NORMAL
  A_STANDOUT = Ncurses::A_STANDOUT
  A_UNDERLINE = Ncurses::A_UNDERLINE
  A_REVERSE = Ncurses::A_REVERSE
  A_BLINK = Ncurses::A_BLINK
  A_DIM = Ncurses::A_DIM
  A_BOLD = Ncurses::A_BOLD
  A_PROTECT = Ncurses::A_PROTECT
  A_INVIS = Ncurses::A_INVIS
  
  
  class Coord
    attr_accessor :y, :x
    def initialize(y, x)
      @y = y
      @x = x
    end
  end
  
  class Window
    def initialize(sy, sx, y, x)
      @win = Ncurses::WINDOW.new(sy, sx, y, x)
    end
    def move(y,x)
      @win.move(y,x)
    end
    def putc(ch)
      @win.addch(ch)
    end
    def move_putc(y,x,ch) 
      move(y,x)
      @win.addch(ch)
    end
    #def puts(str)
    #  @win.printw(str)
    #end
    #def move_puts(y,x,str)
    #  move(y,x)
    #  @win.printw(str)
    #end
    def puts(str)
      @win.addstr(str)
    end
    def move_puts(y, x, str, n=-1)
      move(y,x)
      @win.addnstr(str,n)
    end
    def rows
      @win.getmaxy
    end
    def columns
      @win.getmaxx
    end
    def gets
      str = ""
      @win.getstr(str)
      str
    end
    def move_gets(y,x)
      str = ""
      move(y,x)
      @win.getstr(str)
      str
    end
    def getc
      @win.getch
    end
    def move_getc(y,x)
      move(y,x)
      @win.getch
    end
    def clear
      @win.clear
    end
    def refresh
      @win.noutrefresh
    end
    #def attr_on
    #end
  end
  
  class Scroller
    attr_accessor :direction, :scroll_on_new, :max_rows
    def initialize(max,*str)
      @direction = -1
      @viewport_size = Coord.new(0,0)
      @viewport_pos = Coord.new(0,0)
      @scroll_on_new = true
      @max_rows = max
      @rows = str
      @new_row_inserted = true
    end
    def + (*str)
      @rows += str
      @new_row_inserted = true
      if @rows.length > @max_rows then
        while @rows.length > @max_rows do
          @rows.shift
        end
      end
    end
    def draw(win)
      win.clear
      row = @viewport_pos.y
      @viewport_size.y = win.rows; @viewport_size.x = win.columns
      if @new_row_inserted then 
        @new_row_inserted = false
        if @scroll_on_new then
          @viewport_pos.y = @rows.length-@viewport_size.y
          @viewport_pos.x = 0
          if @direction < 0 then y = 0 end
          if @direction > 0 then y = @viewport_size.y - 1 end
        end
      end
      for row in @viewport_pos.y...@viewport_pos.y+@viewport_size.y do 
        if row >= 0 and row < @rows.length
          win.move_puts(y, 0, @rows[row][@viewport_pos.x,@viewport_size.x])
        end
        y -= @direction
      end
      @old_rows = @rows
      win.refresh
    end
  end
  def self.initialize
    Ncurses.initscr
    Ncurses.nonl
    Ncurses.cbreak
    Ncurses.stdscr.intrflush(false)
    Ncurses.stdscr.keypad(true)
    Ncurses.noecho
  end
  def self.echo() Ncurses.echo end
  def self.noecho() Ncurses.noecho end
  def self.raw() Ncurses.raw end
  def self.destroy
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
  end
  def self.endwin
    Ncurses.endwin
  end
  def self.nl
    Ncurses.nl
  end
  def self.nonl
    Ncurses.nonl
  end
  def self.cbreak
    Ncurses.cbreak
  end
  def self.nocbreak
    Ncurses.nocbreak
  end
  def self.refresh() Ncurses.doupdate end
  def self.move(y,x)
    Ncurses.move(y,x)
  end
  def self.putc(ch)
    Ncurses.addch(ch)
  end
  def self.move_putc(y,x,ch) 
    move(y,x)
    Ncurses.addch(ch)
  end
  #def self.(str)
  #  Ncurses.printw(str)
  #end
  #def self.mvprint(y,x,str)
  #  move(y,x)
  #  Ncurses.printw(str)
  #end
  def self.puts(str)
    Ncurses.addstr(str)
  end
  def self.move_puts(y, x, str, n=-1)
    move(y,x)
    Ncurses.addnstr(str,n)
  end
  def self.rows
    Ncurses.getmaxy
  end
  def self.columns
    Ncurses.getmaxx
  end
  def self.gets
    str = ""
    Ncurses.getstr(str)
    str
  end
  def self.move_gets(y,x)
    str = ""
    move(y,x)
    Ncurses.getstr(str)
    str
  end
  def self.getc
    Ncurses.getch
  end
  def self.move_getc(y,x)
    move(y,x)
    Ncurses.getch
  end
  def self.clear
    Ncurses.clear
  end
  #def self.attron
  #end
end
