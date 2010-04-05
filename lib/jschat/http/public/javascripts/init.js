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
