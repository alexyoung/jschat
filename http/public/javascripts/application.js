var Display = {
  add_message: function(text) {
    $('messages').insert({ bottom: '<li>' + text + '</li>' });
    $('messages').scrollTop = $('messages').scrollHeight;   
  },

  message: function(message) {
    var date_text = this.dateText();
    var text = '<span class="time">\#{time}</span> <span class="user">\#{user}</span> <span class="message">\#{message}</span>';
    text = text.interpolate({ time: date_text, room: message['room'], user: this.truncateName(message['user']), message: this.decorateMessage(message['message']) });
    this.add_message(text);
  },

  dateText: function() {
    var d = new Date;
    var minutes = d.getMinutes().toString();
    var hours = d.getHours();
    minutes = minutes.length == 1 ? '0' + minutes : minutes;
    hours = hours.length == 1 ? '0' + hours : hours;
    var date_text = hours + ':' + minutes; 
    return date_text;
  },

  truncateName: function(text) {
    return text.truncate(12);
  },

  extractURLs: function(text) {
    return text.match(/(http:\/\/[^\s]*)/g);
  },

  decorateMessage: function(text) {
    try {
      var links = this.extractURLs(text);

      if (links) {
        links.each(function(url) {
          if (url.match(/(jp?g|png|gif)/i)) {
            text = text.replace(url, '<a href="\#{url}" target="_blank"><img class="inline-image" src="\#{image}" /></a>'.interpolate({ url: url, image: url }));
          } else {
            text = text.replace(url, '<a href="\#{url}">\#{link_name}</a>'.interpolate({ url: url, link_name: url}));
          }
        });
      }
    } catch (exception) {
      console.log(exception);
    }
    return text;
  },

  names: function(names) {
    $('names').innerHTML = '';
    names.each(function(name) {
      $('names').insert({ bottom: '<li>' + this.truncateName(name) + '</li>' });
    }.bind(this));
  },

  join: function(join) {
    $('room-name').innerHTML = join['room'];
  },

  join_notice: function(join) {
    $('names').insert({ bottom: '<li>' + this.truncateName(join['user']) + '</li>' });
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
    this.remove_user(quit['user']);
    this.add_message(quit['user'] + ' has quit');
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
    parameters: { time: new Date().getTime() },
    onSuccess: function(transport) {
      displayMessages(transport.responseText);
    }
  });
}

function adaptSizes() {
  var windowSize = document.viewport.getDimensions();
  $('messages').setStyle({ width: windowSize.width - 220 + 'px' });
  $('messages').setStyle({ height: windowSize.height - 90 + 'px' });
  $('message').setStyle({ width: windowSize.width - 290 + 'px' });
}

document.observe('dom:loaded', function() {
  if ($('room') && window.location.hash) {
    $('room').value = window.location.hash;
  }

  if ($('post_message')) {
    adaptSizes();
    
    Event.observe(window, 'resize', function() {
      adaptSizes();
    });

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

