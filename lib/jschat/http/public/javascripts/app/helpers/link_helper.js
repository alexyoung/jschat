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
