var UserCommands = {
  '/help': function() {
    var help = [];
    Display.add_message('<strong>JsChat Help</strong> &mdash; Type the following commands into the message field:', 'help')
    help.push(['/clear', 'Clears messages']);
    help.push(['/lastlog', 'Shows recent activity']);
    help.push(['/names', 'Refreshes the names list']);
    help.push(['/name new_name', 'Changes your name']);
    $A(help).each(function(options) {
      var help_text = '<span class="command">#{command}</span><span class="command_help">#{text}</span>'.interpolate({ command: options[0], text: options[1]});
      Display.add_message(help_text, 'help');
    });
  },

  '/clear': function() {
    $('messages').innerHTML = '';
  },

  '/lastlog': function() {
    $('messages').innerHTML = '';
    JsChat.Request.get('/lastlog');
  },

  '/(name|nick)\\s+(.*)': function(name) {
    name = name[2];
    new Ajax.Request('/change-name', {
      method: 'post',
      parameters: { name: name },
      onSuccess: function() {
        JsChat.Request.get('/names', this.updateName.bindAsEventListener(this));
      }.bind(this),
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  },

  '/names': function() {
    JsChat.Request.get('/names');
  }
};
