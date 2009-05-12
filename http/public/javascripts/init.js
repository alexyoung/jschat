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
 
    setTimeout(function() { $('name').activate() }, 500);

    /* The form uses Ajax to sign on */
    $('sign-on').observe('submit', function(e) {
      var signOnController = new JsChat.SignOnController();
      Event.stop(e);
      return false;
    });
  }
});
