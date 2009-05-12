JsChat.SignOnController = Class.create({
  initialize: function() {
    this.retries = 0;
    this.signOn();
  },

  showError: function(message) {
    $('feedback').innerHTML = '<div class="error">#{message}</div>'.interpolate({ message: message });
    $('feedback').show();
  },

  signOn: function() {
    $('loading').show();
    
    new Ajax.Request('/identify', {
      parameters: $('sign-on').serialize(true),
      onSuccess: function(transport) {
        try {
          var json = transport.responseText.evalJSON(true);
          if (json['action'] == 'reload' && this.retries < 4) {
            setTimeout(function() { this.signOn(this.retries + 1) }.bind(this), 500);
          } else if (json['action'] == 'redirect') {
            if (window.location.toString().match(new RegExp(json['to'] + '$'))) {
              window.location.reload();
            } else {
              window.location = json['to'];
            }
          } else if (json['error']) {
            this.showError(json['error']['message']);
            $('loading').hide();
          } else {
            this.showError('Connection error');
          }
        } catch (exception) {
          this.showError('Connection error: #{error}'.interpolate({ error: exception }));
        }
      }.bind(this),
      onFailure: function() {
        this.showError('Connection error');
      }.bind(this),
      onComplete: function() {
        $('loading').hide();
      }
    });
  }
});
