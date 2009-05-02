var Display = {
  add_message: function(text) {
    $('messages').insert({ bottom: '<li>' + text + '</li>' });
    $('messages').scrollTop = $('messages').scrollHeight;   
  },

  message: function(message) {
    var text = '<span class="user">\#{user}</span> <span class="message">\#{message}</span>';
    text = text.interpolate({ room: message['room'], user: message['user'], message: message['message'] });
    this.add_message(text);
  },

  names: function(names) {
    names.each(function(name) {
      $('names').insert({ bottom: '<li>' + name + '</li>' });
    });
  },

  join: function(join) {
    $('room-name').innerHTML = join['room'];
  },

  join_notice: function(join) {
    $('names').insert({ bottom: '<li>' + join['user'] + '</li>' });
    this.add_message(join['user'] + ' has joined the room');
  },

  remove_user: function(name) {
    $$('#names li').each(function(element) { if (element.innerHTML == name) element.remove(); });
  },

  part_notice: function(part) {
    this.remove_user(part['user']);
    this.add_message(part['user'] + ' has left the room');
  },

  quit_notice: function(quit) {
    this.remove_user(part['user']);
    this.add_message(part['user'] + ' has quit');
  }
};

function displayMessages(text) {
  var json_set = text.evalJSON(true);
  if (json_set.length == 0) {
    return;
  }
  json_set.each(function(json) {
    Display[json['display']](json[json['display']]);
  });
}

function updateMessages() {
  new Ajax.Request('/messages', {
    method: 'get',
    onSuccess: function(transport) {
      displayMessages(transport.responseText);
    }
  });
}

document.observe('dom:loaded', function() {
  if ($('post_message')) {
    $('message').activate();
    $('post_message').observe('submit', function(e) {
      var element = Event.element(e);
      var message = $('message').value;
      $('message').value = '';
      new Ajax.Request('/message', {
        method: 'post',
        parameters: { 'message': message },
        onSuccess: function(transport) {
        }
      });

      Event.stop(e);
    });

    Event.observe(window, 'unload', function() {
      new Ajax.Request('/quit');
    });
  }

  if ($('messages')) {
    new PeriodicalExecuter(updateMessages, 3);
  }
});

