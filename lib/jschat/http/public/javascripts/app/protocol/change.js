var Change = {
  user: function(user, time) {
    if (user['name']) {
      change = $H(user['name']).toArray()[0];
      var old = change[0],
          new_value = change[1];
      if (new_value !== PageHelper.nickname()) {
        Display.add_message("#{old} is now known as #{new_value}".interpolate({ old: old, new_value: new_value }), 'server', time);
      }
      $$('#names li').each(function(element) {
        if (element.innerHTML == old) element.innerHTML = new_value;
      });
    }
  }
};
