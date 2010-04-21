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
