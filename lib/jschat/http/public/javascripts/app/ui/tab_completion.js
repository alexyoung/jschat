var History = Class.create({
  initialize: function() {
    this.messages = [];
    this.index = 0;
    this.limit = 100;
  },

  prev: function() {
    this.index = this.index <= 0 ? this.messages.length - 1 : this.index - 1;
  },

  next: function() {
    this.index = this.index >= this.messages.length - 1 ? 0 : this.index + 1;
  },

  reset: function() {
    this.index = this.messages.length;
  },

  value: function() {
    if (this.messages.length == 0) return '';
    return this.messages[this.index];
  },

  add: function(value) {
    if (!value || value.length == 0) return;

    this.messages.push(value);
    if (this.messages.length > this.limit) {
      this.messages = this.messages.slice(-this.limit);
    }
    this.index = this.messages.length;
  },

  atTop: function() {
    return this.index === this.messages.length;
  }
});

var TabCompletion = Class.create({
  initialize: function(element) {
    this.element = $(element);
    this.matches = [];
    this.match_offset = 0;
    this.cycling = false;
    this.has_focus = true;
    this.history = new History();

    document.observe('keydown', this.keyboardEvents.bindAsEventListener(this));
    this.element.observe('focus', this.onFocus.bindAsEventListener(this));
    this.element.observe('blur', this.onBlur.bindAsEventListener(this));
    this.element.observe('click', this.onFocus.bindAsEventListener(this));
  },

  onBlur: function() {
    this.has_focus = false;
    this.reset();
  },

  onFocus: function() {
    this.has_focus = true;
    this.reset();
  },

  tabSearch: function(input) {
    var names = $$('#names li').collect(function(element) { return element.innerHTML }).sort();
    return names.findAll(function(name) { return name.toLowerCase().match(input.toLowerCase()) });
  },

  textToLeft: function() {
    var text = this.element.value;
    var caret_position = FormHelpers.getCaretPosition(this.element);
    if (caret_position < text.length) {
      text = text.slice(0, caret_position);
    }

    text = text.split(' ').last();
    return text;
  },

  elementFocused: function(e) {
    if (typeof document.activeElement == 'undefined') {
      return this.has_focus;
    } else {
      return document.activeElement == this.element;
    }
  },

  keyboardEvents: function(e) {
    if (this.elementFocused()) {
      switch (e.keyCode) {
        case Event.KEY_TAB:
          var caret_position = FormHelpers.getCaretPosition(this.element);

          if (this.element.value.length > 0) {
            var search_text = '';
            var search_result = '';
            var replace_inline = false;
            var editedText = this.element.value.match(/[^a-z0-9]/i);

            if (this.cycling) {
              if (this.element.value == '#{last_result}: '.interpolate({ last_result: this.last_result })) {
                editedText = false;
              } else {
                replace_inline = true;
              }
              search_text = this.last_result;
            } else if (editedText && this.matches.length == 0) {
              search_text = this.textToLeft();
              replace_inline = true;
            } else {
              search_text = this.element.value;
            }

            if (this.matches.length == 0) {
              this.matches = this.tabSearch(search_text);
              search_result = this.matches.first();
              this.cycling = true;
            } else {
              this.match_offset++;
              if (this.match_offset >= this.matches.length) {
                this.match_offset = 0;
              }
              search_result = this.matches[this.match_offset];
            }
            
            if (search_result && search_result.length > 0) {
              if (this.cycling && this.last_result) {
                search_text = this.last_result;
              }
              this.last_result = search_result;

              if (replace_inline) {
                var slice_start = caret_position - search_text.length;
                if (slice_start > 0) {
                  this.element.value = this.element.value.substr(0, slice_start) + search_result + this.element.value.substr(caret_position, this.element.value.length);
                  FormHelpers.setCaretPosition(this.element, slice_start + search_result.length);
                }
              } else if (!editedText) {
                this.element.value = '#{search_result}: '.interpolate({ search_result: search_result });
              }
            }
          }

          Event.stop(e);
          return false;
        break;

        case Event.KEY_UP:
          if (this.history.atTop()) {
            this.history.add(this.element.value);
          }

          this.history.prev();
          this.element.value = this.history.value();
          FormHelpers.setCaretPosition(this.element, this.element.value.length + 1);
          Event.stop(e);
          return false;
        break;

        case Event.KEY_DOWN:
          this.history.next();
          this.element.value = this.history.value();
          FormHelpers.setCaretPosition(this.element, this.element.value.length + 1);
          Event.stop(e);
          return false;
        break;

        default:
          this.reset();
        break;
      }
    }
  },

  reset: function() {
    this.matches = [];
    this.match_offset = 0;
    this.last_result = null;
    this.cycling = false;
  }
});
