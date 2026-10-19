/// The script of the iPhone shortcut "Guardar no Deal Tracker", run by
/// Shortcuts on the Safari page being shared. It reads only what the ad
/// shows (title, price, description, place, photo; never the seller's
/// name) and returns this app's "add" address with it, which the shortcut
/// then opens.
String shareScript(String origin) =>
    '''
var og = function (n) {
  var e = document.querySelector("meta[property=\\"og:" + n + "\\"]");
  return e ? e.content : "";
};
var text = document.body.innerText.slice(0, 6000);
var price = text.match(/€\\s?\\d[\\d .,]*|\\d[\\d .,]*\\s?€/);
var place = text.match(/(?:em|in) ([^\\n,]+, Portugal)/);
var query = new URLSearchParams({
  u: location.href,
  t: og("title") || document.title,
  p: price ? price[0] : "",
  d: (og("description") || "").slice(0, 3000),
  l: place ? place[1] : "",
  i: og("image")
});
completion("$origin/#/add?" + query.toString());
''';
