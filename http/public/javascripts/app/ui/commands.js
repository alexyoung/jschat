var UserCommands = {
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
