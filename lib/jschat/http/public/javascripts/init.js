var JsChat = {};

document.observe('dom:loaded', function() {
  if ($('post_message')) {
    var chatController = new JsChat.ChatController();
  }

  if ($('sign-on')) {
    if (Cookie.find('jschat-name')) {
      $('name').value = Cookie.find('jschat-name');
    }

    if ($('room') && window.location.hash) {
      $('room').value = window.location.hash;
    }
 
    var signOnController = new JsChat.SignOnController();
  }
});
