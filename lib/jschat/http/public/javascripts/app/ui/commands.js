var UserCommands = {
  '/emotes': function() {
    var text = '';
    Display.add_message('<strong>Available Emotes</strong> &mdash; Prefix with a : to use', 'help');
    Display.add_message(EmoteHelper.legalEmotes.join(', '), 'help');
  },

  '/help': function() {
    var help = [];
    Display.add_message('<strong>JsChat Help</strong> &mdash; Type the following commands into the message field:', 'help')
    help.push(['/clear', 'Clears messages']);
    help.push(['/join #room_name', 'Joins a room']);
    help.push(['/part #room_name', 'Leaves a room.  Leave room_name blank for the current room']);
    help.push(['/lastlog', 'Shows recent activity']);
    help.push(['/search query', 'Searches the logs for this room']);
    help.push(['/names', 'Refreshes the names list']);
    help.push(['/name new_name', 'Changes your name']);
    help.push(['/toggle images', 'Toggles showing of images and videos']);
    help.push(['/quit', 'Quit']);
    help.push(['/emotes', 'Shows available emotes']);
    $A(help).each(function(options) {
      var help_text = '<span class="command">#{command}</span><span class="command_help">#{text}</span>'.interpolate({ command: options[0], text: options[1]});
      Display.add_message(help_text, 'help');
    });
  },

  '/clear': function() {
    $('messages').innerHTML = '';
  },

  '/lastlog': function() {
    this.pausePollers = true;
    $('messages').innerHTML = '';
    JsChat.Request.get('/lastlog', function(transport) {
      this.displayMessages(transport.responseText);
      $('names').innerHTML = '';
      this.updateNames();
      this.pausePollers = false;
    }.bind(this));
  },

  '/search\\s+(.*)': function(query) {
    query = query[1];
    this.pausePollers = true;
    $('messages').innerHTML = '';
    JsChat.Request.get('/search?q=' + query, function(transport) {
      Display.add_message('Search results:', 'server');
      this.displayMessages(transport.responseText);
      this.pausePollers = false;
    }.bind(this));
  },

  '/(name|nick)\\s+(.*)': function(name) {
    name = name[2];
    new Ajax.Request('/change-name', {
      method: 'post',
      parameters: { name: name },
      onSuccess: function(response) {
        this.displayMessages(response.responseText);
        JsChat.user.setName(name);
        this.updateNames();
      }.bind(this),
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  },

  '/names': function() {
    this.updateNames();
  },

  '/toggle images': function() {
    JsChat.user.setHideImages(!JsChat.user.hideImages);
    Display.add_message("Hide images set to #{hide}".interpolate({ hide: JsChat.user.hideImages }), 'server');
  },

  '/(join)\\s+(.*)': function() {
    var room = arguments[0][2];
    this.validateAndJoinRoom(room);
  },

  '/(part|leave)': function() {
    this.partRoom(PageHelper.currentRoom());
  },

  '/(part|leave)\\s+(.*)': function() {
    var room = arguments[0][2];
    this.partRoom(room);
  },

  '/tweet\\s+(.*)': function() {
    var message = arguments[0][1];
    this.sendTweet(message);
  },

  '/quit': function() {
    window.location = '/quit';
  }
};
