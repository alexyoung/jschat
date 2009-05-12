var Display = {
  add_message: function(text, className, time) {
    var time_html = '<span class="time">\#{time}</span>'.interpolate({ time: TextHelper.dateText(time) });
    $('messages').insert({ bottom: '<li class="' + className + '">' + time_html + ' ' + text + '</li>' });
    this.scrollMessagesToTop();
  },

  message: function(message) {
    var name = $('name').innerHTML;
    var user_class = name == message['user'] ? 'user active' : 'user';
    var text = '<span class="\#{user_class}">\#{user}</span> <span class="\#{message_class}">\#{message}</span>';

    if (message['message'].match(new RegExp(name, 'i')) && name != message['user']) {
      user_class = 'user mentioned';
    }

    Display.clearIdleState(message['user']);

    text = text.interpolate({ user_class: user_class, room: message['room'], user: TextHelper.truncateName(message['user']), message: TextHelper.decorateMessage(message['message']), message_class: 'message' });
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
    /* This is assumed to be the point at which displaying /lastlog completes */
    $('loading').hide();
    Cookie.create('jschat-name', $('name').innerHTML, 28, '/');
  },

  scrollMessagesToTop: function() {
    $('messages').scrollTop = $('messages').scrollHeight;   
  },

  clearIdleState: function(user_name) {
    $$('#names li').each(function(element) {
      if (element.innerHTML == user_name && element.hasClassName('idle')) {
        element.lastIdle = (new Date());
        element.removeClassName('idle');
      }
    });
  },

  isIdle: function(dateValue) {
    try {
      var d = typeof dateValue == 'string' ? new Date(Date.parse(dateValue)) : dateValue,
          now = new Date();
      if (((now - d) / 1000) > (5 * 60)) {
        return true;
      }
    } catch (exception) {
      console.log(exception);
    }
    return false;
  },

  names: function(users) {
    $('names').innerHTML = '';
    users.each(function(user) {
      var name = user['name'],
          list_class = this.isIdle(user['last_activity']) ? 'idle' : '';
      var element = $('names').insert({ bottom: '<li class="#{class_name}">#{name}</li>'.interpolate({ class_name: list_class, name: TextHelper.truncateName(name) }) });

      try {
        // Record the last idle time so the idle state can be dynamically updated
        element.lastIdle = new Date(Date.parse(user['last_activity']));
      } catch (exception) {
        element.lastIdle = null;
      }
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
