#!/usr/bin/env ruby

require 'rubygems'
require 'eventmachine'
require 'json'
require 'ncurses'

ClientConfig = {
  :port => 6789,
  :ip => ARGV[0] || '0.0.0.0'
}

module Ncurses
  KEY_DELETE = ?\C-h
end

module JsClient
  def keyboard=(keyboard)
    @keyboard = keyboard
  end

  module KeyboardInput
    def setup_screen
      window = Ncurses.initscr
      @windows = {}
      
      Ncurses.raw
      Ncurses.start_color
      Ncurses.noecho
      Ncurses.init_pair 1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK
      Ncurses.init_pair 2, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE

      cols, rows = [], []
      Ncurses.stdscr.getmaxyx rows, cols
      cols, rows = cols.first, rows.first
      Ncurses.refresh

      @windows[:text] = Ncurses.newwin(rows - 2, cols, 0, 0)
      @windows[:info] = Ncurses.newwin(rows - 1, cols, rows - 2, 0)
      @windows[:input] = Ncurses.newwin(rows, cols, rows - 1, 0)
      @windows[:text].bkgd Ncurses.COLOR_PAIR(1)
      @windows[:info].bkgd Ncurses.COLOR_PAIR(2)
      @windows[:info].addstr "[Time] \n"
      @windows[:input].bkgd Ncurses.COLOR_PAIR(1)
      @windows[:input].keypad(true)

      @windows[:text].refresh
      @windows[:info].refresh
      @windows[:input].refresh

      @input_field = Ncurses::Form::FIELD.new(1, Ncurses.COLS - 10, 0, 10, 0, 0)
      @input_field.set_max_field(140)

      @input_form = Ncurses::Form::FORM.new([@input_field])
      @input_form.set_form_win @windows[:input]
      @input_form.post_form
      @windows[:input].mvprintw(0, 0, "[channel] ")
      @windows[:input].refresh
    end

    def receive_data(data)
      @clipboard ||= ''
      c = data[0]
      @windows[:input].addstr data
      @windows[:input].refresh
      case c
        when -1
        # Return
        when ?\n, ?\r, ?\C-m
          @input_form.form_driver Ncurses::Form::REQ_BEG_LINE
          line = @input_field.field_buffer(0)
          line.strip!

          unless line.empty? and line.length > 1
            manage_commands line[0..-2]
          end
          @input_form.form_driver Ncurses::Form::REQ_CLR_FIELD
          @windows[:input].refresh
        # Backspace
        when Ncurses::KEY_BACKSPACE, ?\C-h
          @input_form.form_driver Ncurses::Form::REQ_DEL_PREV
          @input_form.form_driver Ncurses::Form::REQ_CLR_EOL
          @windows[:input].refresh
        when ?\C-d
          @input_form.form_driver Ncurses::Form::REQ_DEL_CHAR
        when Ncurses::KEY_LEFT, ?\C-b
          @input_form.form_driver Ncurses::Form::REQ_PREV_CHAR
        when Ncurses::KEY_RIGHT, ?\C-f
          @input_form.form_driver Ncurses::Form::REQ_NEXT_CHAR
        when ?\C-a
          @input_form.form_driver Ncurses::Form::REQ_BEG_LINE
        when ?\C-e
          @input_form.form_driver Ncurses::Form::REQ_END_LINE
        when ?\C-k
          @input_form.form_driver Ncurses::Form::REQ_CLR_EOL
        when ?\C-u
          @input_form.form_driver Ncurses::Form::REQ_BEG_LINE
          @clipboard = @input_field.field_buffer(0)
          @input_form.form_driver Ncurses::Form::REQ_CLR_FIELD
        when ?\C-y
          unless @clipboard.empty?
            cursor_position = Ncurses.getcurx(@windows[:input])
            
            text = @input_field.field_buffer(0).insert(cursor_position - 9, @clipboard)
            @input_field.set_field_buffer(0, text)
            
            @windows[:text].addstr "#{cursor_position}\n #{text}"
            @windows[:text].refresh
          end
        when ?\C-c
          quit
        when ?\C-w
          @input_form.form_driver Ncurses::Form::REQ_PREV_CHAR
          @input_form.form_driver Ncurses::Form::REQ_DEL_WORD
        else
          @input_form.form_driver c
      end
    end

    def show_message(message)
      @windows[:text].addstr "#{message}\n"
      @windows[:text].refresh
      @windows[:input].refresh
    end

    def quit
      Ncurses.endwin
      exit
    end

    def manage_commands(line)
      operand = strip_command line
      case line
        when %r{/nick}
          @connection.send_identify operand
        when %r{/quit}
          quit
        when %r{/join}
          @connection.send_join operand
        else
          @connection.send_message(line)
      end
    end

    def strip_command(line)
      if line.match %r{^/}
        line.match(%r{/[a-zA-Z][^ ]*(.*)})[1].strip
      else
        line
      end
    end

    def connection=(connection)
      @connection = connection
    end
  end

  def receive_data(data)
    json = JSON.parse(data)
    if json.has_key? 'message'
      @keyboard.show_message "#{Time.now.strftime('%H:%M')} [#{json['room']}] <#{json['user']}> #{json['message']}"
    else
      @keyboard.show_message "[server] #{data.strip}"
    end
  end

  def send_join(channel)
    @current_channel = channel
    send_data({ 'join' => channel }.to_json)
  end

  def send_message(line)
    send_data({ 'to' => @current_channel, 'send' => line }.to_json + "\n")
  end

  def send_identify(username)
    send_data({ 'identify' => username }.to_json + "\n")
  end
end

EM.run do
  puts "Connecting to: #{ClientConfig[:ip]}"
  connection = EM.connect ClientConfig[:ip], ClientConfig[:port], JsClient

  EM.open_keyboard(JsClient::KeyboardInput) do |keyboard|
    keyboard.connection = connection
    keyboard.setup_screen
    connection.keyboard = keyboard
  end
end
