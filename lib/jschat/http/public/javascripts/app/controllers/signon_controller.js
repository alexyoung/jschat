JsChat.SignOnController = Class.create({
  initialize: function() {
    this.retries = 0;
    setTimeout(function() { $('name').activate(); }, 500);
    $('sign-on').observe('submit', this.submitEvent.bindAsEventListener(this));
  },

  submitEvent: function(e) {
    this.signOn();
    Event.stop(e);
    return false;
  },

  showError: function(message) {
    $('feedback').innerHTML = '<div class="error">#{message}</div>'.interpolate({ message: message });
    $('feedback').show();
    $('sign-on-submit').enable();
  },

  signOn: function() {
    $('loading').show();
    $('sign-on-submit').disable();
    this.retries += 1;

    new Ajax.Request('/identify', {
      parameters: $('sign-on').serialize(true),
      onSuccess: function(transport) {
        try {
          var json = transport.responseText.evalJSON(true);
          if (json['action'] == 'reload' && this.retries < 4) {
            setTimeout(function() { this.signOn() }.bind(this), 50);
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
