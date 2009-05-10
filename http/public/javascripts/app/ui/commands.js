var UserCommands = {
  '/clear': function() {
    $('messages').innerHTML = '';
  },

  '/lastlog': function() {
    $('messages').innerHTML = '';
    JsChatRequest.get('/lastlog');
  },

  '/(name|nick)\\s+(.*)': function(name) {
    name = name[2];
    new Ajax.Request('/change-name', {
      method: 'post',
      parameters: { name: name },
      onSuccess: function() {
        JsChatRequest.get('/names', updateName);
      },
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  },

  '/names': function() {
    JsChatRequest.get('/names');
  }
};
