require 'rubygems'
require 'eventmachine'
require 'json'
require 'ncurses'
require 'optparse'
require 'time'

options = {}

ARGV.clone.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{$0} [options]" 

  opts.separator ""

  opts.on("-c", "--config=PATH", String, "Configuration file location (~/.jschat/config.json") { |o| options['config'] = o }
  opts.on("-h", "--hostname=host", String, "JsChat server hostname") { |o| options['hostname'] = o }
  opts.on("-p", "--port=port", String, "JsChat server port number") { |o| options['port'] = o }
  opts.on("-r", "--room=#room", String, "Channel to auto-join: remember to escape the hash") { |o| options['room'] = o }
  opts.on("-n", "--nick=name", String, "Your name") { |o| options['nick'] = o }
  opts.on("--help", "-H", "This text") { puts opts; exit 0 }

  opts.parse!
end

# Command line options will overrides these
def load_options(path)
  path = File.expand_path path
  if File.exists? path
    JSON.parse(File.read path)
  else
    {}
  end
end


options = load_options(options['config'] || '~/.jschat/config.json').merge options

ClientConfig = {
  :port => options['port'] || '6789',
  :ip => options['hostname'] || '0.0.0.0',
  :name => options['nick'] || ENV['LOGNAME'],
  :auto_join => options['room'] || '#jschat'
}

module Ncurses
  KEY_DELETE = ?\C-h
  KEY_TAB = 9
end

module JsChat
  class Protocol
    class Response
      attr_reader :message, :time
      def initialize(message, time)
        @message, @time = message, time
      end
    end

    def initialize(connection)
      @connection = connection
    end

    def legal_commands
      %w(messages message joined quit error join names part identified part_notice quit_notice join_notice)
    end

    def legal_change_commands
      %w(user)
    end

    def legal?(command)
      legal_commands.include? command
    end

    def legal_change?(command)
      legal_change_commands.include? command
    end

    def identified? ; @identified ; end

    def change_user(json)
      original_name = json['name'].keys().first
      new_name = json['name'].values.first
      @connection.names.delete original_name
      @connection.names << new_name
      "* User #{original_name} is now known as #{new_name}"
    end

    def message(json)
      if json['room']
        "[#{json['room']}] <#{json['user']}> #{json['message']}"
      else
        "PRIVATE <#{json['user']}> #{json['message']}"
      end
    end

    def messages(messages)
      results = []
      messages.each do |json|
        results << process_message(json)
      end
      results
    end

    def get_command(json)
      if json.has_key? 'display' and legal? json['display']
        'display'
      elsif json.has_key? 'change' and legal_change? json['change']
        'change'
      end
    end

    def get_time(json)
      if json.kind_of? Hash and json.has_key? 'time'
        Time.parse(json['time']).getlocal
      else
        Time.now.localtime
      end
    end

    def protocol_method_name(command, method_name)
      if command == 'display'
        method_name
      elsif command == 'change'
        "change_#{method_name}"
      end
    end

    def process_message(json)
      command = get_command json

      if command
        time = get_time json[json[command]]
        response = send(protocol_method_name(command, json[command]), json[json[command]])
        case response
        when Array
          response
        when String
          Response.new(response, time)
        end
      end
    end

    def join(json)
      @connection.send_names json['room']
      "* User #{json['user']} joined #{json['room']}"
    end

    def join_notice(json)
      @connection.names << json['user']
      "* User #{json['user']} joined #{json['room']}"
    end

    def part(json)
      "* You left #{json['room']}"
    end

    def part_notice(json)
      @connection.names.delete json['user']
      "* #{json['user']} left #{json['room']}"
    end

    def quit(json)
      @connection.names.delete json['user']
      "* User #{json['user']} left #{json['room']}"
    end
    
    def names(json)
      @connection.names = json.collect { |u| u['name'] }
      "* In this room: #{@connection.names.join(', ')}"
    end

    def identified(json)
      if ClientConfig[:auto_join] and !@auto_joined
        @connection.send_join ClientConfig[:auto_join]
        @auto_joined = true
      end

      @identified = true

      "* You are now known as #{json['name']}"
    end

    def error(json)
      "* [ERROR] #{json['message']}"
    end

    alias_method :quit_notice, :quit
  end
end

module JsClient
  class TabComplete
    attr_accessor :matched, :index

    def initialize
    end

    def run(names, field, form, cursor_x)
      form.form_driver Ncurses::Form::REQ_BEG_LINE
      text = field.field_buffer(0).dup.strip
      if text.size > 0 and cursor_x > 0
        if @matched.nil?
          source = text.slice(0, cursor_x)
          source = text.split(' ').last if text.match(' ')
          @index = 0
        else
          source = @matched
          @index += 1
        end
        names = names.sort.find_all { |name| name.match /^#{source}/i }
        @index = 0 if @index >= names.size
        name = names[@index]
        if name and (@matched or source.size == text.size)
          @matched = source
          field.set_field_buffer(0, "#{name}: ")
          form.form_driver Ncurses::Form::REQ_END_LINE
          form.form_driver Ncurses::Form::REQ_NEXT_CHAR
        else
          @matched = nil
          @index = 0
          (0..cursor_x - 1).each do
            form.form_driver Ncurses::Form::REQ_NEXT_CHAR
          end
        end
      end
    end

    def match(input)
    end

    def reset
      @matched = nil
      @index = 0
    end
  end

  def keyboard=(keyboard)
    @keyboard = keyboard
  end

  # This should take room into account
  def names=(names)
    @names = names
  end

  def names
    @names
  end

  module KeyboardInput
    def setup_screen
      Ncurses.initscr
      @windows = {}
      
      Ncurses.raw
      Ncurses.start_color
      Ncurses.noecho
      Ncurses.use_default_colors
      Ncurses.init_pair 2, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE
      Ncurses.init_pair 3, Ncurses::COLOR_CYAN, -1
      Ncurses.init_pair 4, Ncurses::COLOR_YELLOW, -1
      Ncurses.init_pair 5, Ncurses::COLOR_BLACK, -1
      Ncurses.init_pair 6, Ncurses::COLOR_RED, -1

      @history_position = 0
      @history = []
      @lastlog = []
      @room_name = ''

      setup_windows
    end

    def room_name=(room_name)
      @room_name = room_name 
    end

    def setup_windows
      Ncurses.refresh

      display_windows

      Thread.new do
        loop do
          display_time
          sleep 60 - Time.now.sec
        end
      end

      Signal.trap('SIGWINCH') do
        resize
      end
    end

    def remove_windows_and_forms
      remove_windows
      remove_forms
    end

    def remove_windows
      @windows.each do |name, window|
        window.delete
      end
    end

    def remove_forms
      @input_field.free_field
      @input_form.free_form
    end

    def update_windows
      rows, cols = get_window_size
      remove_windows_and_forms
      display_windows
      display_room_name
    end

    def display_windows
      rows, cols = get_window_size
      @windows[:text] = Ncurses.newwin(rows - 1, cols, 0, 0)
      @windows[:info] = Ncurses.newwin(rows - 1, cols, rows - 2, 0)
      @windows[:input] = Ncurses.newwin(rows, cols, rows - 1, 0)
      @windows[:text].scrollok(true)
      @windows[:info].bkgd Ncurses.COLOR_PAIR(2)
      @windows[:input].keypad(true)
      @windows[:input].nodelay(true)

      @windows[:text].refresh
      @windows[:info].refresh
      @windows[:input].refresh
      display_input
    end

    def display_input
      offset = @room_name.size > 0 ? @room_name.size + 3 : 0
      @input_field = Ncurses::Form::FIELD.new(1, Ncurses.COLS - offset, 0, offset, 0, 0)
      Ncurses::Form.field_opts_off(@input_field, Ncurses::Form::O_AUTOSKIP)
      Ncurses::Form.field_opts_off(@input_field, Ncurses::Form::O_STATIC)
      @input_form = Ncurses::Form::FORM.new([@input_field])
      @input_form.set_form_win @windows[:input]
      @input_form.post_form
      @input_field.set_field_buffer 0, ''
    end

    def display_room_name
      if @room_name
        display_input
        @windows[:input].mvprintw(0, 0, "[#{@room_name}] ")
        @windows[:input].refresh
      end
    end

    def display_time
      @windows[:info].move 0, 0
      @windows[:info].addstr "[#{Time.now.strftime('%H:%M')}]\n"
      @windows[:info].refresh
      @windows[:input].refresh
    end

    def resize
      # Save the user input
      @input_form.form_driver Ncurses::Form::REQ_BEG_LINE
      input = @input_field.field_buffer(0)
      input.rstrip!

      Ncurses.def_prog_mode
      Ncurses.endwin
      Ncurses.reset_prog_mode

      update_windows

      cols = get_window_size[0]
      if @lastlog.size > 0
        lastlog_start = cols > @lastlog.size ? @lastlog.size : cols
        @lastlog[-lastlog_start..-1].each do |message|
          display_text message[0], message[1]
        end
      end

      @input_field.set_field_buffer(0, input)
      @windows[:input].addstr input
      @input_form.form_driver Ncurses::Form::REQ_END_LINE

      Ncurses.refresh
    rescue Exception => exception
      puts exception
    end

    # FIXME: This doesn't work after resize
    # I've tried other ruby ncurses programs and they don't either
    def get_window_size
      Ncurses.refresh
      cols, rows = [], []
      Ncurses.stdscr.getmaxyx rows, cols
      [rows.first, cols.first]
    end

    def get_history_text(offset = 1)
      offset_position = @history_position + offset
      if offset_position >= 0 and offset_position < @history.size
        @history_position = offset_position
        @history[@history_position]
      else
        if @history_position > -1 and @history_position < @history.size
          @history_position = offset_position
        end
        ''
      end
    end

    def arrow_keys(data)
      c = data[0]
      if @sequence
        @sequence << c
        history_text = ''

        if data == 'A'
          @sequence = nil
          history_text = get_history_text(-1)
        elsif data == 'B'
          @sequence = nil
          history_text = get_history_text
        elsif data == 'O'
          return true
        elsif data == 'D'
          # left
          @sequence = nil
          @input_form.form_driver Ncurses::Form::REQ_PREV_CHAR
          @windows[:input].refresh
          return true
        elsif data == 'C'
          # right
          @input_form.form_driver Ncurses::Form::REQ_NEXT_CHAR
          @windows[:input].refresh
          @sequence = nil
          return true
        else
          @sequence = nil
          return true
        end

        begin
          @input_form.form_driver Ncurses::Form::REQ_CLR_FIELD
          @input_field.set_field_buffer(0, history_text)
          @windows[:input].addstr history_text
          @windows[:input].refresh
          @input_form.form_driver Ncurses::Form::REQ_END_LINE
        rescue Exception => exception
        end

        return true
      elsif c == 27
        @sequence = c
        return true
      end
    end

    def cursor_position
      cursor_position = Ncurses.getcurx(@windows[:input]) - 10
    end

    def receive_data(data)
      @clipboard ||= ''
      c = data[0]

      if arrow_keys data
        return
      end

      if c != Ncurses::KEY_TAB
        @tab_completion.reset
      end

      case c
        when -1
          # Return
        when Ncurses::KEY_TAB
          @tab_completion.run @connection.names, @input_field, @input_form, cursor_position
        when Ncurses::KEY_ENTER, ?\n, ?\r
          @input_form.form_driver Ncurses::Form::REQ_BEG_LINE
          line = @input_field.field_buffer(0)
          line.rstrip!

          if !line.empty? and line.length > 0
            @history << line.dup
            @history_position = @history.size
            manage_commands line
          end
          @input_form.form_driver Ncurses::Form::REQ_CLR_FIELD
        when ?\C-l
          # Refresh
          resize
        when Ncurses::KEY_BACKSPACE, ?\C-h, 127
          # Backspace
          @input_form.form_driver Ncurses::Form::REQ_DEL_PREV
          @input_form.form_driver Ncurses::Form::REQ_CLR_EOL
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
      @windows[:input].refresh
    end

    def show_message(messages, time = Time.now.localtime)
      messages.split("\n").each do |message|
        @lastlog << [message.dup, time]
        @lastlog.shift if @lastlog.size > 250
        display_text message, time
      end
    end

    def display_text(message, time = Time.now.localtime)
      message = message.dup
      @windows[:text].addstr "#{time.strftime('%H:%M')} "

      if message.match /^\*/
        @windows[:text].attrset(Ncurses.COLOR_PAIR(3))
      end

      if message.match /^\* \[ERROR\]/
        @windows[:text].attrset(Ncurses.COLOR_PAIR(6))
      elsif message.match /^\[/
        channel_info = message.split(']').first.sub /\[/, ''
        message.sub! "[#{channel_info}]", ''

        @windows[:text].attrset(Ncurses.COLOR_PAIR(5))
        @windows[:text].addstr "["
        @windows[:text].attrset(Ncurses.COLOR_PAIR(4))
        @windows[:text].addstr "#{channel_info}"
        @windows[:text].attrset(Ncurses.COLOR_PAIR(5))
        @windows[:text].addstr "] "

        name = message.split('>').first.sub(/</, '').strip
        message.sub!("<#{name}> ", '')
        @windows[:text].attrset(Ncurses.COLOR_PAIR(5))
        @windows[:text].addstr '<'
        @windows[:text].attrset(Ncurses.COLOR_PAIR(0))
        @windows[:text].addstr "#{name}"
        @windows[:text].attrset(Ncurses.COLOR_PAIR(5))
        @windows[:text].addstr '>'
        @windows[:text].attrset(Ncurses.COLOR_PAIR(0))
      end

      @windows[:text].addstr "#{message}\n"
      @windows[:text].refresh
      @windows[:input].refresh

      display_time

      if message.match /^\*/
        @windows[:text].attrset(Ncurses.COLOR_PAIR(0))
      end
    end

    def quit
      Ncurses.endwin
      exit
    end

    def help_text
      <<-TEXT
*** JsChat Help ***
Commands start with a forward slash.  Parameters in square brackets are optional.
/name new_name      - Change your name.  Alias: /nick
/names [room name]  - List the people in a room.
/join #room         - Join a room.  Alias: /j
/switch #room       - Speak in a different room.  Alias: /s
/part #room         - Leave a room.  Alias: /p
/message person     - Send a private message.  Alias: /m
/lastlog            - Display the last 100 messages for a room.
/quit               - Quit JsChat
*** End Help ***

      TEXT
    end

    def manage_commands(line)
      operand = strip_command line
      case line
        when %r{^/switch}, %r{^/s}
          @connection.switch_room operand
        when %r{^/names}
          @connection.send_names operand
        when %r{^/name}, %r{^/nick}
          @connection.send_change_name operand
        when %r{^/quit}
          quit
        when %r{^/join}, %r{^/j}
          @connection.send_join operand
        when %r{^/part}, %r{^/p}
          @connection.send_part operand
        when %r{^/lastlog}
          @connection.send_lastlog
        when %r{^/clear}
          @windows[:text].clear
          @windows[:text].refresh
          display_time
        when %r{^/message}, %r{^/m}
          if operand and operand.size > 0
            message = operand.match(/([^ ]*)\s+(.*)/)
            if message
              @connection.send_private_message message[1], message[2]
            end
          end
        when %r{^/help}
          help_text.split("\n").each do |message|
            display_text message
          end
        when %r{^/}
          display_text '* Command not found.  Try using /help'
        else
          @connection.send_message(line)
      end
    end

    def strip_command(line)
      matches = line.match(%r{/[a-zA-Z][^ ]*(.*)})
      if matches
        matches[1].strip
      else
        line
      end
    end

    def connection=(connection)
      @connection = connection
      @tab_completion = JsClient::TabComplete.new
    end
  end

  include EM::Protocols::LineText2

  def receive_line(data)
    data.split("\n").each do |line|
      json = JSON.parse(line.strip)
      # Execute the json
      protocol_response = @protocol.process_message json
      if protocol_response
        if protocol_response.kind_of? Array
          protocol_response.each do |response|
            @keyboard.show_message response.message, response.time
          end
        else
          @keyboard.show_message protocol_response.message, protocol_response.time
        end
      elsif json.has_key? 'notice'
        @keyboard.show_message "* #{json['notice']}"
      else
        @keyboard.show_message "* [SERVER] #{line}"
      end
    end
  rescue Exception => exception
    @keyboard.show_message "* [CLIENT ERROR] #{exception}"
  end

  def send_join(room)
    @current_room = room 
    @keyboard.room_name = room 
    @keyboard.display_room_name
    send_data({ 'join' => room }.to_json + "\n")
  end

  def switch_room(room)
    @current_room = room
    @keyboard.room_name = room 
    @keyboard.display_room_name
    @keyboard.show_message "* Switched room to: #{room}"
  end

  def send_part(room = nil)
    room = @current_room if room.nil?
    send_data({ 'part' => room }.to_json + "\n")
  end

  def send_names(room = nil)
    room = @current_room if room.nil? or room.strip.empty?
    send_data({ 'names' => room }.to_json + "\n")
  end

  def send_lastlog(room = nil)
    room = @current_room if room.nil? or room.strip.empty?
    send_data({ 'lastlog' => room }.to_json + "\n")
  end

  def send_message(line)
    send_data({ 'to' => @current_room, 'send' => line }.to_json + "\n")
  end

  def send_private_message(user, message)
    send_data({ 'to' => user, 'send' => message }.to_json + "\n")
  end

  def send_identify(username)
    send_data({ 'identify' => username }.to_json + "\n")
  end

  def send_change_name(username)
    if @protocol.identified?
      send_data({ 'change' => 'user', 'user' => { 'name' => username } }.to_json + "\n")
    else
      send_identify username
    end
  end

  def unbind
    Ncurses.endwin
    Ncurses.clear
    puts "Disconnected from server"
    exit
  end

  def post_init
    # When connected
    @protocol = JsChat::Protocol.new self
    send_identify ClientConfig[:name]
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
