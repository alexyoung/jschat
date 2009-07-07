var EmoteHelper = {
  legalEmotes: ['angry', 'arr', 'blink', 'blush', 'brucelee', 'btw', 'chuckle', 'clap', 'cool', 'drool', 'drunk', 'dry', 'eek', 'flex', 'happy', 'holmes', 'huh', 'laugh', 'lol', 'mad', 'mellow', 'noclue', 'oh', 'ohmy', 'ph34r', 'pimp', 'punch', 'realmad', 'rock', 'rofl', 'rolleyes', 'sad', 'scratch', 'shifty', 'shock', 'shrug', 'sleep', 'sleeping', 'smile', 'suicide', 'sweat', 'thumbs', 'tongue', 'unsure', 'w00t', 'wacko', 'whistling', 'wink', 'worship', 'yucky'],

  emoteToImage: function(emote) {
    var result = emote;
    emote = emote.replace(/^:/, '').toLowerCase();
    if (EmoteHelper.legalEmotes.find(function(v) { return v == emote })) {
      result = '<img src="/images/emoticons/#{emote}.gif" alt="#{description}" />'.interpolate({ emote: emote, description: emote });
    }
    return result;
  },

  insertEmotes: function(text) {
    var result = '';
    $A(text.split(/(:[^ ]*)/)).each(function(segment) {
      if (segment && segment.match(/^:/)) {
        segment = EmoteHelper.emoteToImage(segment);
      }
      result += segment;
    });
    return result;
  }
};
