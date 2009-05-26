var FormHelpers = {
  getCaretPosition: function(element) {
    if (element.setSelectionRange) {
      return element.selectionStart;
    } else if (element.createTextRange) {
      try {
        // The current selection
        var range = document.selection.createRange();
        // We'll use this as a 'dummy'
        var stored_range = range.duplicate();
        // Select all text
        stored_range.moveToElementText(element);
        // Now move 'dummy' end point to end point of original range
        stored_range.setEndPoint('EndToEnd', range);

        return stored_range.text.length - range.text.length;
      } catch (exception) {
        // IE is being mental.  TODO: Figure out what IE's issue is
        return 0;
      }
    }
  },

  setCaretPosition: function(element, pos) {
    if (element.setSelectionRange) {
      element.focus()
      element.setSelectionRange(pos, pos)
    } else if (element.createTextRange) {
      var range = element.createTextRange()

      range.collapse(true)
      range.moveEnd('character', pos)
      range.moveStart('character', pos)
      range.select()
    }
  }
};
