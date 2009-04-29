var Display = {
  message: function(message) {
    var text = '<span class="user">\#{user}</span> <span class="message">\#{message}</span>';
    return text.interpolate({ room: message['room'], user: message['user'], message: message['message'] });
  }
};

function displayMessages(text) {
  var json_set = text.evalJSON(true);
  if (json_set.length == 0) {
    return;
  }
  json_set.each(function(json) {
    var display_text = Display[json['display']](json[json['display']]);
    $('messages').insert({ bottom: '<li>' + display_text + '</li>' });
    $('messages').scrollTop = $('messages').scrollHeight;
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
  }

  if ($('messages')) {
    new PeriodicalExecuter(updateMessages, 3);
  }
});

