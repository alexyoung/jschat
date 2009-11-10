/* FIXME: Later on this should be a class */
JsChat.Request = {
  get: function(url, callback) {
    new Ajax.Request(url, {
      method: 'get',
      parameters: { time: new Date().getTime(), room: PageHelper.currentRoom() },
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      },
      onComplete: function(transport) { return callback(transport); }
    });
  }
};
