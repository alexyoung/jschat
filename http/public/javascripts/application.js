var LinkHelper = {
  url: function(url) {
    return url.match(/(https?:\/\/[^\s]*)/gi);
  },

  link: function(url) {
    return '<a href="\#{url}" target="_blank">\#{link_name}</a>'.interpolate({ url: url, link_name: url});
  },

  image_url: function(url) {
    return url.match(/(jp?g|png|gif)/i);
  },

  image: function(url) {
    return '<a href="\#{url}" target="_blank"><img class="inline-image" src="\#{image}" /></a>'.interpolate({ url: url, image: url })
  },

  youtube_url: function(url) {
    return url.match(/youtube\.com/) && url.match(/watch\?v/);
  },

  youtube: function(url) {
    var youtube_url_id = url.match(/\?v=([^&\s]*)/);
    if (youtube_url_id && youtube_url_id[1]) {
      var youtube_url = 'http://www.youtube.com/v/' + youtube_url_id[1];
      var youtube_html = '<object width="480" height="295"><param name="movie" value="#{movie_url}"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="#{url}" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="480" height="295"></embed></object>';
      return youtube_html.interpolate({ movie_url: youtube_url, url: youtube_url });
    } else {
      return this.link(url);
    }
  }
};

var TextHelper = {
  zeroPad: function(value, length) {
    value = value.toString();
    if (value.length >= length) {
      return value;
    } else {
      return this.zeroPad('0' + value, length);
    }
  },

  dateText: function(time) {
    var d = new Date();
    if (typeof time != 'undefined') {
      d = new Date(Date.parse(time));
    }
    return this.zeroPad(d.getHours(), 2) + ':' + this.zeroPad(d.getMinutes(), 2); 
  },

  truncateName: function(text) {
    return text.truncate(15);
  },

  decorateMessage: function(text) {
    return this.autoLink(text);
  },

  autoLink: function(text) {
    var result = '';
    try {
      if (!LinkHelper.url(text)) {
        return text;
      }

      $A(text.split(/(https?:\/\/[^\s]*)/gi)).each(function(link) {
        if (link.match(/href="/)) {
          result += link;
        } else {
          if (LinkHelper.youtube_url(link)) {
            result += link.replace(link, LinkHelper.youtube(link));
          } else if (LinkHelper.image_url(link)) {
            result += link.replace(link, LinkHelper.image(link));
          } else if (LinkHelper.url(link)) {
            result += link.replace(link, LinkHelper.link(link));
          } else {
            result += link;
          }
        }
      });
    } catch (exception) {
    }
    return result;
  }
}

var Change = {
  user: function(user) {
    if (user['name']) {
      change = $H(user['name']).toArray()[0];
      var old = change[0],
          new_value = change[1];
      Display.add_message("#{old} is now known as #{new_value}".interpolate({ old: old, new_value: new_value }), 'server', user['time']);
    }
  }
};

var Display = {
  add_message: function(text, className, time) {
    var time_html = '<span class="time">\#{time}</span>'.interpolate({ time: TextHelper.dateText(time) });
    $('messages').insert({ bottom: '<li class="' + className + '">' + time_html + ' ' + text + '</li>' });
    this.scrollMessagesToTop();
  },

  message: function(message) {
    var text = '<span class="user">\#{user}</span> <span class="message">\#{message}</span>';
    text = text.interpolate({ room: message['room'], user: TextHelper.truncateName(message['user']), message: TextHelper.decorateMessage(message['message']) });
    this.add_message(text, 'message', message['time']);

    if (this.show_unread) {
      this.unread++;
      document.title = 'JsChat: (' + this.unread + ') new messages';
    }
  },

  messages: function(messages) {
    $('messages').innerHTML = '';
    this.ignore_notices = true;
    $A(messages).each(function(json) {
      try {
        if (json['change']) {
          Change[json['change']](json[json['change']]);
        } else {
          this[json['display']](json[json['display']]);
        }
      } catch (exception) {
      }
    }.bind(this));
    this.ignore_notices = false;
    this.scrollMessagesToTop();
  },

  scrollMessagesToTop: function() {
    $('messages').scrollTop = $('messages').scrollHeight;   
  },

  names: function(names) {
    $('names').innerHTML = '';
    names.each(function(name) {
      $('names').insert({ bottom: '<li>' + TextHelper.truncateName(name) + '</li>' });
    }.bind(this));
  },

  join: function(join) {
    $('room-name').innerHTML = join['room'];
  },

  join_notice: function(join) {
    this.add_user(join['user']);
    this.add_message(join['user'] + ' has joined the room', 'server', join['time']);
  },

  add_user: function(name) {
    if (!this.ignore_notices) {
      $('names').insert({ bottom: '<li>' + TextHelper.truncateName(name) + '</li>' });
    }
  },

  remove_user: function(name) {
    if (!this.ignore_notices) {
      $$('#names li').each(function(element) { if (element.innerHTML == name) element.remove(); });
    }
  },

  part_notice: function(part) {
    this.remove_user(part['user']);
    this.add_message(part['user'] + ' has left the room', 'server', part['time']);
  },

  quit_notice: function(quit) {
    this.remove_user(quit['user']);
    this.add_message(quit['user'] + ' has quit', 'server', quit['time']);
  },

  notice: function(notice) {
    this.add_message(notice, 'server');
  },

  error: function(error) {
    this.add_message(error['message'], 'error');
  }
};

var JsChatRequest = {
  get: function(url) {
    new Ajax.Request(url, {
      method: 'get',
      parameters: { time: new Date().getTime(), room: currentRoom() },
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  }
}

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
        JsChatRequest.get('/names');
      },
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  },

  '/names': function() {
    JsChatRequest.get('/names');
  }
}

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
      } catch (exception) {
        console.log(transport.responseText);
        console.log(exception);
      }
    },
    onFailure: function(request) {
      poller.stop();
      Display.add_message('Server error: <a href="/">please reconnect</a>', 'server');
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

var TabCompletion = Class.create({
  initialize: function(element) {
    this.element = $(element);
    this.matches = [];
    this.match_offset = 0;
    this.cycling = false;

    document.observe('keydown', this.keyboardEvents.bindAsEventListener(this));
    this.element.observe('focus', this.reset.bindAsEventListener(this));
    this.element.observe('blur', this.reset.bindAsEventListener(this));
    this.element.observe('click', this.reset.bindAsEventListener(this));
  },

  tabSearch: function(input) {
    var names = $$('#names li').collect(function(element) { return element.innerHTML });
    return names.findAll(function(name) { return name.match(input) });
  },

  textToLeft: function() {
    var text = this.element.value;
    var caret_position = getCaretPosition(this.element);
    if (caret_position < text.length) {
      text = text.slice(0, caret_position);
    }

    text = text.split(' ').last();
    return text;
  },

  keyboardEvents: function(e) {
    if (document.activeElement == this.element) {
      switch (e.keyCode) {
        case Event.KEY_TAB:
          var caret_position = getCaretPosition(this.element);

          if (this.element.value.length > 0) {
            var search_text = '';
            var search_result = '';
            var replace_inline = false;
            var editedText = this.element.value.match(/[^a-zA-Z0-9]/);

            if (this.cycling) {
              if (this.element.value == '#{last_result}: '.interpolate({ last_result: this.last_result })) {
                editedText = false;
              } else {
                replace_inline = true;
              }
              search_text = this.last_result;
            } else if (editedText && this.matches.length == 0) {
              search_text = this.textToLeft();
              replace_inline = true;
            } else {
              search_text = this.element.value;
            }

            if (this.matches.length == 0) {
              this.matches = this.tabSearch(search_text);
              search_result = this.matches.first();
              this.cycling = true;
            } else {
              this.match_offset++;
              if (this.match_offset >= this.matches.length) {
                this.match_offset = 0;
              }
              search_result = this.matches[this.match_offset];
            }
            
            if (search_result && search_result.length > 0) {
              if (this.cycling && this.last_result) {
                search_text = this.last_result;
              }
              this.last_result = search_result;

              if (replace_inline) {
                var slice_start = caret_position - search_text.length;
                if (slice_start > 0) {
                  this.element.value = this.element.value.substr(0, slice_start) + search_result + this.element.value.substr(caret_position, this.element.value.length);
                  setCaretPosition(this.element, slice_start + search_result.length);
                }
              } else if (!editedText) {
                this.element.value = '#{search_result}: '.interpolate({ search_result: search_result });
              }
            }
          }

          Event.stop(e);
          return false;
        break;

        default:
          this.reset();
        break;
      }
    }
  },

  reset: function() {
    this.matches = [];
    this.match_offset = 0;
    this.last_result = null;
    this.cycling = false;
  }
});

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
        onFailure: function() { Display.add_message("Error: Couldn't join channel", 'server'); },
        onComplete: function() {
          setTimeout(function() { JsChatRequest.get('/names'); }, 250);
        }
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

  new Ajax.Request('/identify', {
    parameters: $('sign-on').serialize(true),
    onSuccess: function(transport) {
      try {
        var json = transport.responseText.evalJSON(true);
        if (json['action'] == 'reload' && retries < 4) {
          setTimeout(function() { signOn(retries + 1) }, 500);
        } else if (json['action'] == 'redirect') {
          window.location = json['to'];
        } else if (json['error']) {
          showError(json['error']['message']);
        } else {
          showError('Connection error');
        }
      } catch (exception) {
        showError('Connection error: #{error}'.interpolate({ exception: exception }));
      }
    },
    onFailure: function() {
      showError('Connection error');
    }
  });
}

document.observe('dom:loaded', function() {
  if ($('room') && window.location.hash) {
    $('room').value = window.location.hash;
  }

  if ($('post_message')) {
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
    setTimeout(function() { $('name').activate() }, 500);

    /* The form uses Ajax to sign on */
    $('sign-on').observe('submit', function(e) {
      signOn(0);
      Event.stop(e);
      return false;
    });
  }
});

