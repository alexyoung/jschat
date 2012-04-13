var JsChat = {};

document.observe('dom:loaded', function() {
  JsChat.user = new User();

  if ($('post_message')) {
    var chatController = new JsChat.ChatController();
  }

  if ($('sign-on')) {
    if (JsChat.user.name) {
      $('name').value = JsChat.user.name;
    }

    if ($('room') && window.location.hash) {
      $('room').value = window.location.hash;
    }
 
    var signOnController = new JsChat.SignOnController();
  }
});
var History = Class.create({
  initialize: function() {
    this.messages = [];
    this.index = 0;
    this.limit = 100;
  },

  prev: function() {
    this.index = this.index <= 0 ? this.messages.length - 1 : this.index - 1;
  },

  next: function() {
    this.index = this.index >= this.messages.length - 1 ? 0 : this.index + 1;
  },

  reset: function() {
    this.index = this.messages.length;
  },

  value: function() {
    if (this.messages.length == 0) return '';
    return this.messages[this.index];
  },

  add: function(value) {
    if (!value || value.length == 0) return;

    this.messages.push(value);
    if (this.messages.length > this.limit) {
      this.messages = this.messages.slice(-this.limit);
    }
    this.index = this.messages.length;
  },

  atTop: function() {
    return this.index === this.messages.length;
  }
});

var TabCompletion = Class.create({
  initialize: function(element) {
    this.element = $(element);
    this.matches = [];
    this.match_offset = 0;
    this.cycling = false;
    this.has_focus = true;
    this.history = new History();

    document.observe('keydown', this.keyboardEvents.bindAsEventListener(this));
    this.element.observe('focus', this.onFocus.bindAsEventListener(this));
    this.element.observe('blur', this.onBlur.bindAsEventListener(this));
    this.element.observe('click', this.onFocus.bindAsEventListener(this));
  },

  onBlur: function() {
    this.has_focus = false;
    this.reset();
  },

  onFocus: function() {
    this.has_focus = true;
    this.reset();
  },

  tabSearch: function(input) {
    var names = $$('#names li').collect(function(element) { return element.innerHTML }).sort();
    return names.findAll(function(name) { return name.toLowerCase().match(input.toLowerCase()) });
  },

  textToLeft: function() {
    var text = this.element.value;
    var caret_position = FormHelpers.getCaretPosition(this.element);
    if (caret_position < text.length) {
      text = text.slice(0, caret_position);
    }

    text = text.split(' ').last();
    return text;
  },

  elementFocused: function(e) {
    if (typeof document.activeElement == 'undefined') {
      return this.has_focus;
    } else {
      return document.activeElement == this.element;
    }
  },

  keyboardEvents: function(e) {
    if (this.elementFocused()) {
      switch (e.keyCode) {
        case Event.KEY_TAB:
          var caret_position = FormHelpers.getCaretPosition(this.element);

          if (this.element.value.length > 0) {
            var search_text = '';
            var search_result = '';
            var replace_inline = false;
            var editedText = this.element.value.match(/[^a-z0-9]/i);

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
                  FormHelpers.setCaretPosition(this.element, slice_start + search_result.length);
                }
              } else if (!editedText) {
                this.element.value = '#{search_result}: '.interpolate({ search_result: search_result });
              }
            }
          }

          Event.stop(e);
          return false;
        break;

        case Event.KEY_UP:
          if (this.history.atTop()) {
            this.history.add(this.element.value);
          }

          this.history.prev();
          this.element.value = this.history.value();
          FormHelpers.setCaretPosition(this.element, this.element.value.length + 1);
          Event.stop(e);
          return false;
        break;

        case Event.KEY_DOWN:
          this.history.next();
          this.element.value = this.history.value();
          FormHelpers.setCaretPosition(this.element, this.element.value.length + 1);
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
var UserCommands = {
  '/emotes': function() {
    var text = '';
    Display.add_message('<strong>Available Emotes</strong> &mdash; Prefix with a : to use', 'help');
    Display.add_message(EmoteHelper.legalEmotes.join(', '), 'help');
  },

  '/help': function() {
    var help = [];
    Display.add_message('<strong>JsChat Help</strong> &mdash; Type the following commands into the message field:', 'help')
    help.push(['/clear', 'Clears messages']);
    help.push(['/join #room_name', 'Joins a room']);
    help.push(['/part #room_name', 'Leaves a room.  Leave room_name blank for the current room']);
    help.push(['/lastlog', 'Shows recent activity']);
    help.push(['/search query', 'Searches the logs for this room']);
    help.push(['/names', 'Refreshes the names list']);
    help.push(['/name new_name', 'Changes your name']);
    help.push(['/toggle images', 'Toggles showing of images and videos']);
    help.push(['/quit', 'Quit']);
    help.push(['/emotes', 'Shows available emotes']);
    $A(help).each(function(options) {
      var help_text = '<span class="command">#{command}</span><span class="command_help">#{text}</span>'.interpolate({ command: options[0], text: options[1]});
      Display.add_message(help_text, 'help');
    });
  },

  '/clear': function() {
    $('messages').innerHTML = '';
  },

  '/lastlog': function() {
    this.pausePollers = true;
    $('messages').innerHTML = '';
    JsChat.Request.get('/lastlog', function(transport) {
      this.displayMessages(transport.responseText);
      $('names').innerHTML = '';
      this.updateNames();
      this.pausePollers = false;
    }.bind(this));
  },

  '/search\\s+(.*)': function(query) {
    query = query[1];
    this.pausePollers = true;
    $('messages').innerHTML = '';
    JsChat.Request.get('/search?q=' + query, function(transport) {
      Display.add_message('Search results:', 'server');
      this.displayMessages(transport.responseText);
      this.pausePollers = false;
    }.bind(this));
  },

  '/(name|nick)\\s+(.*)': function(name) {
    name = name[2];
    new Ajax.Request('/change-name', {
      method: 'post',
      parameters: { name: name },
      onSuccess: function(response) {
        this.displayMessages(response.responseText);
        JsChat.user.setName(name);
        this.updateNames();
      }.bind(this),
      onFailure: function() {
        Display.add_message("Server error: couldn't access: #{url}".interpolate({ url: url }), 'server');
      }
    });
  },

  '/names': function() {
    this.updateNames();
  },

  '/toggle images': function() {
    JsChat.user.setHideImages(!JsChat.user.hideImages);
    Display.add_message("Hide images set to #{hide}".interpolate({ hide: JsChat.user.hideImages }), 'server');
  },

  '/(join)\\s+(.*)': function() {
    var room = arguments[0][2];
    this.validateAndJoinRoom(room);
  },

  '/(part|leave)': function() {
    this.partRoom(PageHelper.currentRoom());
  },

  '/(part|leave)\\s+(.*)': function() {
    var room = arguments[0][2];
    this.partRoom(room);
  },

  '/tweet\\s+(.*)': function() {
    var message = arguments[0][1];
    this.sendTweet(message);
  },

  '/quit': function() {
    window.location = '/quit';
  }
};
var Display = {
  scrolled: false,

  add_message: function(text, className, time) {
    var time_html = '<span class="time">\#{time}</span>'.interpolate({ time: TextHelper.dateText(time) });
    $('messages').insert({ bottom: '<li class="' + className + '">' + time_html + ' ' + text + '</li>' });
    this.scrollMessagesToTop();
  },

  addImageOnLoads: function() {
    $$('#messages li').last().select('img').each(function(element) {
        element.observe('load', this.scrollMessagesToTop);
    }.bind(this));
  },

  message: function(message, time) {
    var name = JsChat.user.name;
    var user_class = name == message['user'] ? 'user active' : 'user';
    var text = '<span class="\#{user_class}">\#{user}</span> <span class="\#{message_class}">\#{message}</span>';
    var blurred_mention = '';

    if (message['message'].match(new RegExp(name, 'i')) && name != message['user']) {
      user_class = 'user mentioned';
      blurred_mention = '*';
    }

    Display.clearIdleState(message['user']);

    text = text.interpolate({
      user_class: user_class,
      room: message['room'],
      user: TextHelper.truncateName(message['user']),
      message: TextHelper.decorateMessage(message['message']),
      message_class: 'message'
    });

    this.add_message(text, 'message', time);
    this.addImageOnLoads();

    if (this.show_unread) {
      this.unread++;
      document.title = 'JsChat: (' + this.unread + blurred_mention + ') new messages';
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
  },

  scrollMessagesToTop: function() {
    if (!this.scrolled) {
      $('messages').scrollTop = $('messages').scrollHeight;
    }
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
      if (((now - d) / 1000) > (60 * 5)) {
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
          list_class = this.isIdle(user['last_activity']) ? 'idle' : '',
          element = $(document.createElement('li'));

      element.addClassName(list_class);
      element.innerHTML = TextHelper.truncateName(name);
      $('names').insert({ bottom: element });

      try {
        // Record the last idle time so the idle state can be dynamically updated
        element.lastIdle = new Date(Date.parse(user['last_activity']));
      } catch (exception) {
        element.lastIdle = null;
      }
    }.bind(this));
  },

  join: function(join) {
    $('room-name').innerHTML = TextHelper.truncateRoomName(join['room']);
    $('room-name').title = PageHelper.currentRoom();
  },

  join_notice: function(join, time) {
    this.add_user(join['user']);
    this.add_message(join['user'] + ' has joined the room', 'server', time);
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

  part_notice: function(part, time) {
    this.remove_user(part['user']);
    this.add_message(part['user'] + ' has left the room', 'server', time);
  },

  quit_notice: function(quit, time) {
    this.remove_user(quit['user']);
    this.add_message(quit['user'] + ' has quit', 'server', time);
  },

  notice: function(notice) {
    this.add_message(notice, 'server');
  },

  error: function(error) {
    this.add_message(error['message'], 'error');
  }
};
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
var Change = {
  user: function(user, time) {
    if (user['name']) {
      change = $H(user['name']).toArray()[0];
      var old = change[0],
          new_value = change[1];
      if (new_value !== PageHelper.nickname()) {
        Display.add_message("#{old} is now known as #{new_value}".interpolate({ old: old, new_value: new_value }), 'server', time);
      }
      $$('#names li').each(function(element) {
        if (element.innerHTML == old) element.innerHTML = new_value;
      });
    }
  }
};
User = function() {
  this.name = Cookie.find('jschat-name');
  this.hideImages = Cookie.find('jschat-hideImages') === '1' ? true : false;
};

User.prototype.setName = function(name) {
  Cookie.create('jschat-name', name, 28, '/');
  this.name = name;
};

User.prototype.setHideImages = function(hideImages) {
  this.hideImages = hideImages;
  Cookie.create('jschat-hideImages', (hideImages ? '1' : '0'), 28, '/');
};
Cookie = {
  create: function(name, value, days, path) {
    var expires = '';
    path = typeof path == 'undefined' ? '/' : path;
    
    if (days) {
      var date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toGMTString();
    }
 
    if (name && value) {
      document.cookie = name + '=' + escape(value) + expires + ';path=' + path;
    }
  },
  
  find: function(name) {
    var matches = document.cookie.match(name + '=([^;]*)');
    if (matches && matches.length == 2) {
      return unescape(matches[1]);
    }
  },
  
  destroy: function(name) {
    this.create(name, ' ', -1);
  }
};
/*
	Cross-Browser Split 0.3
	By Steven Levithan <http://stevenlevithan.com>
	MIT license
	Provides a consistent cross-browser, ECMA-262 v3 compliant split method
*/

String.prototype._$$split = String.prototype._$$split || String.prototype.split;

String.prototype.split = function (s /* separator */, limit) {
	// if separator is not a regex, use the native split method
	if (!(s instanceof RegExp))
		return String.prototype._$$split.apply(this, arguments);

	var	flags = (s.global ? "g" : "") + (s.ignoreCase ? "i" : "") + (s.multiline ? "m" : ""),
		s2 = new RegExp("^" + s.source + "$", flags),
		output = [],
		origLastIndex = s.lastIndex,
		lastLastIndex = 0,
		i = 0, match, lastLength;

	/* behavior for limit: if it's...
	- undefined: no limit
	- NaN or zero: return an empty array
	- a positive number: use limit after dropping any decimal
	- a negative number: no limit
	- other: type-convert, then use the above rules
	*/
	if (limit === undefined || +limit < 0) {
		limit = false;
	} else {
		limit = Math.floor(+limit);
		if (!limit)
			return [];
	}

	if (s.global)
		s.lastIndex = 0;
	else
		s = new RegExp(s.source, "g" + flags);

	while ((!limit || i++ <= limit) && (match = s.exec(this))) {
		var emptyMatch = !match[0].length;

		// Fix IE's infinite-loop-resistant but incorrect lastIndex
		if (emptyMatch && s.lastIndex > match.index)
			s.lastIndex--;

		if (s.lastIndex > lastLastIndex) {
			// Fix browsers whose exec methods don't consistently return undefined for non-participating capturing groups
			if (match.length > 1) {
				match[0].replace(s2, function () {
					for (var j = 1; j < arguments.length - 2; j++) {
						if (arguments[j] === undefined)
							match[j] = undefined;
					}
				});
			}

			output = output.concat(this.slice(lastLastIndex, match.index));
			if (1 < match.length && match.index < this.length)
				output = output.concat(match.slice(1));
			lastLength = match[0].length; // only needed if s.lastIndex === this.length
			lastLastIndex = s.lastIndex;
		}

		if (emptyMatch)
			s.lastIndex++; // avoid an infinite loop
	}

	// since this uses test(), output must be generated before restoring lastIndex
	output = lastLastIndex === this.length ?
		(s.test("") && !lastLength ? output : output.concat("")) :
		(limit ? output : output.concat(this.slice(lastLastIndex)));
	s.lastIndex = origLastIndex; // only needed if s.global, else we're working with a copy of the regex
	return output;
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

  truncateRoomName: function(text) {
    return text.truncate(15);
  },

  decorateMessage: function(text) {
    return EmoteHelper.insertEmotes(this.autoLink(this.textilize(text)));
  },

  textilize: function(text) {
    function escape_regex(text) { return text.replace(/([\*\?\+\^\?])/g, "\\$1"); }
    function openTag(text) { return '<' + text + '>'; }
    function closeTag(text) { return '</' + text + '>'; }

    var map = { '_': 'em', '*': 'strong' };

    $H(map).each(function(mapping) {
      var result = '';
      var m = escape_regex(mapping[0]);
      var mr = new RegExp('(' + m + ')');
      var matcher = new RegExp('(^|\\s+)(' + m + ')([^\\s][^' + mapping[0] + ']*[^\\s])(' + m + ')', 'g');

      if (text.match(matcher)) {
        var open = false;
        text.split(matcher).each(function(segment) {
          if (segment == mapping[0]) {
            var tag = open ? closeTag(mapping[1]) : openTag(mapping[1]);
            result += segment.replace(mr, tag);
            open = !open;
          } else {
            result += segment;
          }
        });

        if (open) result += closeTag(mapping[1]);
        text = result;
      }
    });

    return text;
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
          if (LinkHelper.youtube_url(link) && !JsChat.user.hideImages) {
            result += link.replace(link, LinkHelper.youtube(link));
          } else if (LinkHelper.vimeo_url(link)  && !JsChat.user.hideImages) {
            result += link.replace(link, LinkHelper.vimeo(link));
          } else if (LinkHelper.image_url(link)  && !JsChat.user.hideImages) {
            result += link.replace(link, LinkHelper.image(link));
          } else if (LinkHelper.twitpic_url(link)  && !JsChat.user.hideImages) {
            result += link.replace(link, LinkHelper.twitpic(link));
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
};
var PageHelper = {
  currentRoom: function() {
    return window.location.hash;
  },

  setCurrentRoomName: function(roomName) {
    window.location.hash = roomName;
    $('room-name').innerHTML = TextHelper.truncateRoomName(PageHelper.currentRoom());
    $('room-name').title = PageHelper.currentRoom();
    document.title = PageHelper.title();    
  },

  allRoomNames: function() {
    return $$('#rooms li a').collect(function(link) {
      return link.innerHTML;
    });
  },

  nickname: function() {
    return JsChat.user.name;
  },

  title: function() {
    if (PageHelper.currentRoom()) {
      return 'JsChat: ' + PageHelper.currentRoom();
    } else {
      return 'JsChat';
    }
  },

  device: function() {
    if ($$('body.iphone').length > 0) {
      return 'iphone';
    } else if ($$('body.ipad').length > 0) {
      return 'ipad';
    }
  },

  isDevice: function(device) {
    return PageHelper.device() == device;
  }
};
var LinkHelper = {
  url: function(url) {
    return url.match(/(https?:\/\/[^\s]*)/gi);
  },

  link: function(url) {
    return '<a href="\#{url}" target="_blank">\#{link_name}</a>'.interpolate({ url: url, link_name: url});
  },

  image_url: function(url) {
    return url.match(/\.(jpe?g|png|gif)/i);
  },

  image: function(url) {
    return '<a href="\#{url}" target="_blank"><img class="inline-image" src="\#{image}" /></a>'.interpolate({ url: url, image: url })
  },

  twitpic_url: function(url) {
    return url.match(/\bhttp:\/\/twitpic.com\/(show|[^\s]*)\b/i);
  },

  twitpic: function(url) {
    var twitpic_id = url.split('/').last();
    return '<a href="\#{url}" target="_blank"><img class="inline-image" src="http://twitpic.com/show/mini/\#{twitpic_id}" /></a>'.interpolate({ twitpic_id: twitpic_id, url: url })
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
  },

  vimeo_url: function(url) {
    return url.match(/vimeo\.com/) && url.match(/\/\d+/);
  },

  vimeo: function(url) {
    var vimeo_url_id = url.match(/\d+/);
    if (vimeo_url_id) {
      var vimeo_url = 'http://vimeo.com/' + vimeo_url_id;
      var vimeo_html = '<object width="560" height="315"><param name="allowfullscreen" value="true" /><param name="allowscriptaccess" value="always" /><param name="movie" value="http://vimeo.com/moogaloop.swf?clip_id=' + vimeo_url_id + '&amp;server=vimeo.com&amp;show_title=1&amp;show_byline=0&amp;show_portrait=0&amp;color=969696&amp;fullscreen=1" /><embed src="http://vimeo.com/moogaloop.swf?clip_id=' + vimeo_url_id + '&amp;server=vimeo.com&amp;show_title=1&amp;show_byline=0&amp;show_portrait=0&amp;color=969696&amp;fullscreen=1" type="application/x-shockwave-flash" allowfullscreen="true" allowscriptaccess="always" width="560" height="315"></embed></object>';
      return vimeo_html.interpolate({ movie_url: vimeo_url, url: vimeo_url });
    } else {
      return this.link(url);
    }
  }
};
var FormHelpers = {
  getCaretPosition: function(element) {
    if (element.setSelectionRange) {
      return element.selectionStart;
    } else if (element.createTextRange) {
      try {
        // The current selection
        var range = document.selection.createRange();
        // We'll use this as a 'dummy'
        var stored_range = range.duplicate();
        // Select all text
        stored_range.moveToElementText(element);
        // Now move 'dummy' end point to end point of original range
        stored_range.setEndPoint('EndToEnd', range);

        return stored_range.text.length - range.text.length;
      } catch (exception) {
        // IE is being mental.  TODO: Figure out what IE's issue is
        return 0;
      }
    }
  },

  setCaretPosition: function(element, pos) {
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
};
var EmoteHelper = {
  legalEmotes: ['angry', 'arr', 'blink', 'blush', 'brucelee', 'btw', 'chuckle', 'clap', 'cool', 'drool', 'drunk', 'dry', 'eek', 'flex', 'happy', 'holmes', 'huh', 'laugh', 'lol', 'mad', 'mellow', 'noclue', 'oh', 'ohmy', 'panic', 'ph34r', 'pimp', 'punch', 'realmad', 'rock', 'rofl', 'rolleyes', 'sad', 'scratch', 'shifty', 'shock', 'shrug', 'sleep', 'sleeping', 'smile', 'suicide', 'sweat', 'thumbs', 'tongue', 'unsure', 'w00t', 'wacko', 'whistling', 'wink', 'worship', 'yucky'],

  emoteToImage: function(emote) {
    var result = emote;
    emote = emote.replace(/^:/, '').toLowerCase();
    if (EmoteHelper.legalEmotes.find(function(v) { return v == emote })) {
      result = '<img src="/images/emoticons/#{emote}.gif" alt="#{description}" />'.interpolate({ emote: emote, description: emote });
    }
    return result;
  },

  insertEmotes: function(text) {
    var result = '';
    $A(text.split(/(:[^ ]*)/)).each(function(segment) {
      if (segment && segment.match(/^:/)) {
        segment = EmoteHelper.emoteToImage(segment);
      }
      result += segment;
    });
    return result;
  }
};
JsChat.SignOnController = Class.create({
  initialize: function() {
    this.retries = 0;
    setTimeout(function() { $('name').activate(); }, 500);
    $('sign-on').observe('submit', this.submitEvent.bindAsEventListener(this));
  },

  submitEvent: function(e) {
    this.signOn();
    Event.stop(e);
    return false;
  },

  showError: function(message) {
    $('feedback').innerHTML = '<div class="error">#{message}</div>'.interpolate({ message: message });
    $('feedback').show();
    $('sign-on-submit').enable();
  },

  signOn: function() {
    $('loading').show();
    $('sign-on-submit').disable();
    this.retries += 1;

    new Ajax.Request('/identify', {
      parameters: $('sign-on').serialize(true),
      onSuccess: function(transport) {
        try {
          var json = transport.responseText.evalJSON(true);
          if (json['action'] == 'reload' && this.retries < 4) {
            setTimeout(function() { this.signOn() }.bind(this), 50);
          } else if (json['action'] == 'redirect') {
            if (window.location.toString().match(new RegExp(json['to'] + '$'))) {
              window.location.reload();
            } else {
              window.location = json['to'];
            }
          } else if (json['error']) {
            this.showError(json['error']['message']);
            $('loading').hide();
          } else {
            this.showError('Connection error');
          }
        } catch (exception) {
          this.showError('Connection error: #{error}'.interpolate({ error: exception }));
        }
      }.bind(this),
      onFailure: function() {
        this.showError('Connection error');
      }.bind(this),
      onComplete: function() {
        $('loading').hide();
      }
    });
  }
});
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
