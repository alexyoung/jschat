var FormHelpers = {
  getCaretPosition: function(element) {
    if (element.setSelectionRange) {
      return element.selectionStart;
    } else if (element.createTextRange) {
      var range = document.selection.createRange();
      var stored_range = range.duplicate();
      stored_range.moveToElementText(element);
      stored_range.setEndPoint('EndToEnd', range);
      return stored_range.text.length - range.text.length;
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
