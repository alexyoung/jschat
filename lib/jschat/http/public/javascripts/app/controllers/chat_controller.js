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
    $$('#rooms li.join a').first().observe('click', this.joinRoomClicked.bindAsEventListener(this));
    Event.observe(document, 'click', this.roomTabClick.bindAsEventListener(this));
    this.allRecentMessages();
  },

  allRecentMessages: function() {
    new Ajax.Request('/room_update_times', {
      method: 'get',
      onComplete: function(request) {
        var times = request.responseText.evalJSON();
        $H(this.lastUpdateTimes).each(function(data) {
          var room = data[0],
              time = data[1];
          if (Date.parse(time) < Date.parse(times[room])) {
            this.roomTabAlert(room);
          }
        }.bind(this));
        this.lastUpdateTimes = times;
      }.bind(this)
    });
  },

  roomTabAlert: function(room) {
    if (room === PageHelper.currentRoom()) return;

    $$('ul#rooms li a').each(function(roomLink) {
      if (roomLink.innerHTML === room) {
        roomLink.addClassName('new');
      }
    });
  },

  clearRoomTabAlert: function(room) {
    $$('ul#rooms li a').each(function(roomLink) {
      if (roomLink.innerHTML === room) {
        roomLink.removeClassName('new');
      }
    });
  },

  joinRoomClicked: function(e) {
    this.addRoomPrompt(e);
    Event.stop(e);
    return false;
  },

  roomTabClick: function(e) {
    var element = Event.element(e);

    if (element.tagName == 'A' && element.up('#rooms') && !element.up('li').hasClassName('join')) {
      this.switchRoom(element.innerHTML);
      Event.stop(e);
      return false;
    }
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

    if (PageHelper.isDevice('ipad')) {
      messageInset = 330;
      heightInset = 130;
    }

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

      this.tabCompletion.history.add(message);

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
          if (message.match(/^\/\s?\//)) {
            this.postMessage(message.replace(/\//, '').strip());
          } else if (message.match(/^\//)) {
            Display.add_message('Error: Command not found.  Use /help display commands.', 'error');
          } else {
            this.postMessage(message);
          }
        }
      }
    } catch (exception) {
      console.log(exception);
    }

    Event.stop(e);
    return false;
  },

  postMessage: function(message) {
    Display.message({ 'message': message.escapeHTML(), 'user': JsChat.user.name }, new Date());
    new Ajax.Request('/message', {
      method: 'post',
      parameters: { 'message': message, 'to': PageHelper.currentRoom() }
    });
  },

  sendTweet: function(message) {
    new Ajax.Request('/tweet', {
      method: 'post',
      parameters: { 'tweet': message }
    });
  },

  initDisplay: function() {
    Display.unread = 0;
    Display.show_unread = false;
    Display.ignore_notices = false;

    PageHelper.setCurrentRoomName(window.location.hash);
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
    this.getRoomList(this.addRoomAndCheckSelected);
    this.joinRoom(PageHelper.currentRoom());
  },

  getRoomList: function(callback) {
    new Ajax.Request('/rooms', {
      method: 'get',
      parameters: { time: new Date().getTime() },
      onComplete: function(response) {
        response.responseText.evalJSON().sort().each(function(roomName) {
          try {
            callback.apply(this, [roomName]);
          } catch (exception) {
            console.log(exception);
          }
        }.bind(this));
      }.bind(this)
    }); 
  },

  joinRoom: function(roomName) {
    new Ajax.Request('/join', {
      method: 'post',
      parameters: { time: new Date().getTime(), room: roomName },
      onFailure: function() {
        Display.add_message("Error: Couldn't join channel", 'server');
        $('loading').hide();
      },
      onComplete: function() {
        // Make the server update the last polled time
        JsChat.Request.get('/messages', function() {});
        document.title = PageHelper.title();
        UserCommands['/lastlog'].apply(this);
        $('loading').hide();
        $('rooms').show();
        this.addRoomToNav(roomName, true);
      }.bind(this)
    });
  },

  isValidRoom: function(roomName) {
    if (PageHelper.allRoomNames().include(roomName)) {
      return false;
    }
    return true;
  },

  validateAndJoinRoom: function(roomName) {
    if (roomName === null || roomName.length == 0) {
      return;
    }

    if (!roomName.match(/^#/)) {
      roomName = '#' + roomName;
    }

    if (this.isValidRoom(roomName)) {
      this.joinRoomInTab(roomName);
    }
  },

  addRoomPrompt: function() {
    var roomName = prompt('Enter a room name:');
    this.validateAndJoinRoom(roomName);
  },

  addRoomToNav: function(roomName, selected) {
    if (PageHelper.allRoomNames().include(roomName)) return;

    var classAttribute = selected ? ' class="selected"' : '';
    $('rooms').insert({ bottom: '<li#{classAttribute}><a href="#{roomName}">#{roomName}</a></li>'.interpolate({ classAttribute: classAttribute, roomName: roomName }) });
  },

  addRoomAndCheckSelected: function(roomName) {
    this.addRoomToNav(roomName, PageHelper.currentRoom() == roomName);
  },

  removeSelectedTab: function() {
    $$('#rooms .selected').invoke('removeClassName', 'selected');
  },

  selectRoomTab: function(roomName) {
    $$('#rooms a').each(function(a) {
      if (a.innerHTML == roomName) {
        a.up('li').addClassName('selected');
      }
    });
  },

  joinRoomInTab: function(roomName) {
    this.removeSelectedTab();
    PageHelper.setCurrentRoomName(roomName);
    this.joinRoom(roomName);
    $('message').focus();
  },

  switchRoom: function(roomName) {
    if (PageHelper.currentRoom() == roomName) {
      return;
    }

    this.removeSelectedTab();
    this.selectRoomTab(roomName);
    PageHelper.setCurrentRoomName(roomName);
    UserCommands['/lastlog'].apply(this);
    this.clearRoomTabAlert(roomName);
    $('message').focus();
  },

  rooms: function() {
    return $$('#rooms li a').slice(1).collect(function(element) {
      return element.innerHTML;
    });
  },

  partRoom: function(roomName) {
    if (this.rooms().length == 1) {
      return UserCommands['/quit']();
    }

    new Ajax.Request('/part', {
      method: 'get',
      parameters: { room: roomName },
      onSuccess: function(request) {
        this.removeTab(roomName);
      }.bind(this),
      onFailure: function(request) {
        Display.add_message('Error: ' + request.responseText, 'server');
      }
    });
  },

  removeTab: function(roomName) {
    $$('#rooms li').each(function(element) {
      if (element.down('a').innerHTML == roomName) {
        element.remove();

        if (roomName == PageHelper.currentRoom()) {
          this.switchRoom($$('#rooms li a')[1].innerHTML);
        }
      }
    }.bind(this));
  },

  updateNames: function() {
    JsChat.Request.get('/names', function(t) { this.displayMessages(t.responseText); }.bind(this));
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
    if (this.pausePollers) {
      return;
    }

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
          Change[json['change']](json[json['change']], json['time']);
        } else {
          Display[json['display']](json[json['display']], json['time']);
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
    this.pollers.push(new PeriodicalExecuter(this.allRecentMessages.bind(this), 10));
  }
});
