User = function() {
  this.name = Cookie.find('jschat-name');
  this.hideImages = Cookie.find('jschat-hideImages') === '1' ? true : false;
};

User.prototype.setName = function(name) {
  Cookie.create('jschat-name', name, 28, '/');
  this.name = name;
};

User.prototype.setHideImages = function(hideImages) {
  this.hideImages = hideImages;
  Cookie.create('jschat-hideImages', (hideImages ? '1' : '0'), 28, '/');
};
