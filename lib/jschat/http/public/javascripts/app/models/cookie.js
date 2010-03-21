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
