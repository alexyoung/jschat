function displayMessages(text) {
  var json_set = text.evalJSON(true);
  if (json_set.length == 0) {
    return;
  }
  json_set.each(function(json) {
    try {
      if (json['change']) {
        Change[json['change']](json[json['change']]);
      } else {
        Display[json['display']](json[json['display']]);
      }
    } catch (exception) {
    }
  });
}

function updateMessages() {
  new Ajax.Request('/messages', {
    method: 'get',
    parameters: { time: new Date().getTime(), room: currentRoom() },
    onSuccess: function(transport) {
      try {
        displayMessages(transport.responseText);

        if ($$('#messages li').length > 1000) {
          $$('#messages li').slice(0, 500).invoke('remove');
        }
      } catch (exception) {
        console.log(transport.responseText);
        console.log(exception);
      }
    },
    onFailure: function(request) {
      poller.stop();
      Display.add_message('Server error: <a href="/#{room}">please reconnect</a>'.interpolate({ room: currentRoom() }), 'server');
    }
  });
}

function updateName() {
  new Ajax.Request('/user/name', {
    method: 'get',
    parameters: { time: new Date().getTime() },
    onSuccess: function(transport) {
      $('name').innerHTML = transport.responseText;
      Cookie.create('jschat-name', $('name').innerHTML, 28, '/');
    }
  });
}

function getCaretPosition(element) {
  if (element.setSelectionRange) {
    return element.selectionStart;
  } else if (element.createTextRange) {
    var range = document.selection.createRange();
    var stored_range = range.duplicate();
    stored_range.moveToElementText(element);
    stored_range.setEndPoint('EndToEnd', range);
    return stored_range.text.length - range.text.length;
  }
}

function setCaretPosition(element, pos) {
  if (element.setSelectionRange) {
    element.focus()
    element.setSelectionRange(pos, pos)
  } else if (element.createTextRange) {
    var range = element.createTextRange()

    range.collapse(true)
    range.moveEnd('character', pos)
    range.moveStart('character', pos)
    range.select()
  }
}

function adaptSizes() {
  var windowSize = document.viewport.getDimensions();
  $('messages').setStyle({ width: windowSize.width - 220 + 'px' });
  $('messages').setStyle({ height: windowSize.height - 100 + 'px' });
  $('message').setStyle({ width: windowSize.width - 290 + 'px' });
  Display.scrollMessagesToTop();
}

function currentRoom() {
  return window.location.hash;
}

function initDisplay() {
  Display.unread = 0;
  Display.show_unread = false;
  Display.ignore_notices = false;
  $('room-name').innerHTML = currentRoom();
  poller = new PeriodicalExecuter(updateMessages, 3);

  new Ajax.Request('/join', {
    method: 'post',
    parameters: { time: new Date().getTime(), room: currentRoom() },
    onComplete: function() {
      new Ajax.Request('/lastlog', {
        method: 'get',
        parameters: { time: new Date().getTime(), room: currentRoom() },
        onFailure: function() { Display.add_message("Error: Couldn't join channel", 'server'); $('loading').hide(); },
        onComplete: function() { setTimeout(function() { JsChatRequest.get('/names'); }, 250); }
      });
    }
  });

  new TabCompletion('message');

  Event.observe(window, 'focus', function() {
    Display.unread = 0;
    Display.show_unread = false;
    document.title = 'JsChat';
  });
  Event.observe(window, 'blur', function() {
    Display.show_unread = true;
  });
}

function signOn(retries) {
  function showError(message) {
    $('feedback').innerHTML = '<div class="error">#{message}</div>'.interpolate({ message: message });
    $('feedback').show();
  }

  $('loading').show();
  
  new Ajax.Request('/identify', {
    parameters: $('sign-on').serialize(true),
    onSuccess: function(transport) {
      try {
        var json = transport.responseText.evalJSON(true);
        if (json['action'] == 'reload' && retries < 4) {
          setTimeout(function() { signOn(retries + 1) }, 500);
        } else if (json['action'] == 'redirect') {
          if (window.location.toString().match(new RegExp(json['to'] + '$'))) {
            window.location.reload();
          } else {
            window.location = json['to'];
          }
        } else if (json['error']) {
          showError(json['error']['message']);
        } else {
          showError('Connection error');
        }
      } catch (exception) {
        showError('Connection error: #{error}'.interpolate({ error: exception }));
      }
    },
    onFailure: function() {
      showError('Connection error');
    },
    onComplete: function() {
      $('loading').hide();
    }
  });
}

document.observe('dom:loaded', function() {
 if ($('post_message')) {
    $('loading').show();
    adaptSizes();
    Event.observe(window, 'resize', adaptSizes);
    setTimeout(initDisplay, 1000);

    $('message').activate();
    $('post_message').observe('submit', function(e) {
      var element = Event.element(e);
      var message = $('message').value;
      $('message').value = '';

      if (message.length == 0) {
        return;
      }

      var command_posted = $H(UserCommands).find(function(command) {
        var name = command[0];
        var matches = message.match(new RegExp('^' + name + '$'));
        if (matches) {
          command[1](matches);
          return true;
        }
      });

      if (!command_posted) {
        new Ajax.Request('/message', {
          method: 'post',
          parameters: { 'message': message, 'to': currentRoom() }
        });
      }

      Event.stop(e);
    });

    $$('.header .navigation li').invoke('hide');
    $('quit-link').show();
  }

  if ($('sign-on')) {
    if (Cookie.find('jschat-name')) {
      $('name').value = Cookie.find('jschat-name');
    }

    if ($('room') && window.location.hash) {
      $('room').value = window.location.hash;
    }
 
    setTimeout(function() { $('name').activate() }, 500);

    /* The form uses Ajax to sign on */
    $('sign-on').observe('submit', function(e) {
      signOn(0);
      Event.stop(e);
      return false;
    });
  }
});
