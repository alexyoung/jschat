var PageHelper = {
  currentRoom: function() {
    return window.location.hash;
  },

  nickname: function() {
    return Cookie.find('jschat-name');
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
    }
  },

  isDevice: function(device) {
    return PageHelper.device() == device;
  }
};
