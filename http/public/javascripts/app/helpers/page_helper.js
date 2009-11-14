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
  }
};
