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
