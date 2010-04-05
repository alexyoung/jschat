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
    }
  },

  isDevice: function(device) {
    return PageHelper.device() == device;
  }
};
