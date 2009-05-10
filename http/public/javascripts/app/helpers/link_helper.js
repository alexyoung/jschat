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
