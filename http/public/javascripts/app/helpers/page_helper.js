var PageHelper = {
  currentRoom: function() {
    return window.location.hash;
  },

  title: function() {
    if (PageHelper.currentRoom()) {
      return 'JsChat: ' + PageHelper.currentRoom();
    } else {
      return 'JsChat';
    }
  }
};
