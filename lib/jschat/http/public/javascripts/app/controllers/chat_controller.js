JsChat.ChatController = Class.create({
  initialize: function() {
    $('loading').show();

    this.resizeEvent();
    setTimeout(this.initDisplay.bind(this), 50);
    this.tabCompletion = new TabCompletion('message');

    Event.observe(window, 'focus', this.focusEvent.bindAsEventListener(this));
    Event.observe(window, 'blur', this.blurEvent.bindAsEventListener(this));
    Event.observe(window, 'resize', this.resizeEvent.bindAsEventListener(this));

    $('post_message').observe('submit', this.postMessageFormEvent.bindAsEventListener(this));
    $('messages').observe('scroll', this.messagesScrolled.bindAsEventListener(this));
  },

  messagesScrolled: function() {
    Display.scrolled = (($('messages').scrollHeight - $('messages').scrollTop) > $('messages').getHeight());
  },

  focusEvent: function() {
    Display.unread = 0;
    Display.show_unread = false;
    document.title = PageHelper.title();
  },

  blurEvent: function() {
    Display.show_unread = true;
  },

  resizeEvent: function() {
    var messageInset = PageHelper.isDevice('iphone') ? 390 : 290,
        heightInset = PageHelper.isDevice('iphone') ? 200 : 100,
        windowSize = document.viewport.getDimensions();
    $('messages').setStyle({ width: windowSize.width - 220 + 'px' });
    $('messages').setStyle({ height: windowSize.height - heightInset + 'px' });
    $('message').setStyle({ width: windowSize.width - messageInset + 'px' });
    $('names').setStyle({ height: windowSize.height - 200 + 'px' });
    Display.scrollMessagesToTop();
  },

  postMessageFormEvent: function(e) {
    try {
      var element = Event.element(e);
      var message = $('message').value;
      $('message').value = '';

      if (message.length > 0) {
        var command_posted = $H(UserCommands).find(function(command) {
          var name = command[0];
          var matches = message.match(new RegExp('^' + name + '$'));
          if (matches) {
            command[1].bind(this)(matches);
            return true;
          }
        }.bind(this));

        if (!command_posted) {
          if (message.match(/^\//)) {
            Display.add_message('Error: Command not found.  Use /help display commands.', 'error');
          } else {
            Display.message({ 'message': message.escapeHTML(), 'user': $('name').innerHTML }, true);
            new Ajax.Request('/message', {
              method: 'post',
              parameters: { 'message': message, 'to': PageHelper.currentRoom() }
            });
          }
        }
      }
    } catch (exception) {
      console.log(exception);
    }

    Event.stop(e);
    return false;
  },

  initDisplay: function() {
    Display.unread = 0;
    Display.show_unread = false;
    Display.ignore_notices = false;

    $('room-name').innerHTML = TextHelper.truncateRoomName(PageHelper.currentRoom());
    $('room-name').title = PageHelper.currentRoom();
    $('message').activate();
    $$('.header .navigation li').invoke('hide');
    $('quit-nav').show();
    $('help-nav').show();

    $('help-link').observe('click', function(e) {
      UserCommands['/help']();
      $('message').activate();
      Event.stop(e);
      return false;
    });

    this.createPollers();
    this.joinRoom();
  },

  joinRoom: function() {
    new Ajax.Request('/join', {
      method: 'post',
      parameters: { time: new Date().getTime(), room: PageHelper.currentRoom() },
      onFailure: function() {
        Display.add_message("Error: Couldn't join channel", 'server');
        $('loading').hide();
      },
      onComplete: function() {
        // Make the server update the last polled time
        JsChat.Request.get('/messages');
        document.title = PageHelper.title();
        UserCommands['/lastlog'].apply(this);
        $('loading').hide();
      }.bind(this)
    });
  },

  updateNames: function() {
    UserCommands['/names'].apply(this);
  },

  showMessagesResponse: function(transport) {
    try {
      this.displayMessages(transport.responseText);

      if ($$('#messages li').length > 1000) {
        $$('#messages li').slice(0, 500).invoke('remove');
      }
    } catch (exception) {
      console.log(transport.responseText);
      console.log(exception);
    }
  },

  updateMessages: function() {
    new Ajax.Request('/messages', {
      method: 'get',
      parameters: { time: new Date().getTime(), room: PageHelper.currentRoom() },
      onSuccess: function(transport) {
        this.showMessagesResponse(transport);
      }.bind(this),
      onFailure: function(request) {
        this.stopPolling();
        Display.add_message('Server error: <a href="/#{room}">please reconnect</a>'.interpolate({ room: PageHelper.currentRoom() }), 'server');
      }.bind(this)
    });
  },

  displayMessages: function(text, successCallback) {
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
          if (json['display'] !== 'error' && typeof successCallback !== 'undefined') {
            successCallback();
          }
        }
      } catch (exception) {
      }
    });
  },

  checkIdleNames: function() {
    $$('#names li').each(function(element) {
      if (Display.isIdle(element.lastIdle)) {
        element.addClassName('idle');
      }
    });
  },

  stopPolling: function() {
    this.pollers.invoke('stop');
  },

  firePollers: function() {
    this.pollers.invoke('execute');
  },

  createPollers: function() {
    this.pollers = $A();
    this.pollers.push(new PeriodicalExecuter(this.updateMessages.bind(this), 3));
    this.pollers.push(new PeriodicalExecuter(this.checkIdleNames.bind(this), 5));
  }
});
