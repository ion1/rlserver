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
      Ncurses.getmaxy(@win)
    end
    def columns
      Ncurses.getmaxx(@win)
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

  def self.stdin_dead?
    File.stat("/dev/fd/0").nlink == 0
  end
  
  def self.stdout_dead?
    File.stat("/dev/fd/1").nlink == 0
  end
  
  def self.stderr_dead?
    File.stat("/dev/fd/2").nlink == 0
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
  #def self.rows
  #  Ncurses.getmaxy
  #end
  #def self.columns
  #  Ncurses.getmaxx
  #end
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
