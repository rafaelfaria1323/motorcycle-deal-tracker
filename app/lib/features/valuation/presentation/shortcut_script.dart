/// The iPhone shortcut "Avaliar no Deal Tracker" (N.110): the script its
/// "Executar JavaScript na página web" step runs on the ad Safari shows,
/// and where the next step sends what it returns.
///
/// The script reads only that page, as Safari already shows it (after
/// opening the description's "Ver mais"): the link, the title of its
/// share data, the description (script 4: the longest of the share
/// data's, the opened "Ver mais" block's and the text under a
/// "Descrição" heading up to "Ver menos", line breaks kept, at most 5000
/// characters), the page's lines up to the seller's
/// part (never a line about the seller: "Membro desde 2015", "Joined in
/// 2015", or one that looks like a name: "João Silva"; at most 8000
/// characters), the lines among them that hold a price, a year, km or
/// how long the ad has been up, a struck-through price (the price before
/// a drop), and the addresses of up to 12 large photos. It asks the site
/// for nothing.
library;

import '../../../core/config/supabase_config.dart';

/// The script's version; keep it equal to the database's
/// `shared_ad_script_version()`, which tells an older script's shortcut
/// to copy the new one.
const sharedAdScriptVersion = 4;

/// The address the shortcut posts to.
String get sharedAdReceiveUrl => '$supabaseUrl/rest/v1/rpc/receive_shared_ad';

/// The header the shortcut sends with it: the publishable key, which the
/// web app also sends with every request.
String get sharedAdApiKey => supabasePublishableKey;

/// The header the shared shortcut sends the account's key in (its script
/// carries none); a key in the script's body wins over it.
const sharedAdKeyHeader = 'x-deal-tracker-key';

/// The iCloud link of the shared shortcut (N.110b): its script is
/// [sharedAdScript] without a key, and it asks for the key when it is
/// installed. Left empty, the page shows only the steps to make the
/// shortcut by hand.
const sharedAdShortcutLink =
    'https://www.icloud.com/shortcuts/466d7f6a160c42fc86be10a45ae92a8a';

const _template = r'''
// Deal Tracker: Avaliar no Deal Tracker (script __VERSION__)
var KEY = __KEY__;
function meta(name) {
  var e = document.querySelector('meta[property="' + name + '"], meta[name="' + name + '"]');
  return e ? (e.getAttribute('content') || '').trim() : '';
}
var wanted = /€|\beur\b|\bkms?\b|quil[oó]metr|(^|\D)(19[89]\d|20\d\d)(\D|$)|\bh[aá]\s+(\d+|um|uma)\s|\bago\b|\bontem\b|\byesterday\b/i;
var seller = /membro|member|joined|aderiu|desde|since|vendedor|seller|perfil|profile|avalia|rating|responde|responds|mensagem|message/i;
var sellerPart = /^(informa[cç][oõ]es (sobre )?o vendedor|seller information|seller details|sobre o vendedor|about the seller|anunciante|detalhes do vendedor)$/i;
var nameLike = /^(\p{Lu}[\p{L}'.-]*)(\s+\p{Lu}[\p{L}'.-]*){0,3}$/u;
function read() {
  var seen = {};
  var lines = [];
  var text = [];
  var size = 0;
  var all = String(document.body ? document.body.innerText : '').split('\n');
  for (var i = 0; i < all.length; i++) {
    var line = all[i].trim();
    if (sellerPart.test(line)) break;
    if (!line || seen[line] || seller.test(line) || nameLike.test(line)) continue;
    seen[line] = true;
    if (line.length <= 200 && lines.length < 60 && wanted.test(line)) lines.push(line);
    if (size < 8000 && line.length <= 3000) {
      text.push(line);
      size += line.length + 1;
    }
  }
  var oldPrice = '';
  Array.prototype.some.call(document.querySelectorAll('s, del, strike, [style*="line-through"]'), function (e) {
    var t = (e.innerText || '').trim();
    if (/\d/.test(t) && /€|eur/i.test(t) && t.length <= 40) oldPrice = t;
    return oldPrice !== '';
  });
  var whole = '';
  function keep(t) {
    t = String(t || '').split('\n').map(function (l) { return l.replace(tail, '').trim(); }).filter(function (l) {
      return l && !buttons.test(l) && !heading.test(l);
    }).join('\n');
    if (t.length > whole.length && t.length <= 5000) whole = t;
  }
  opened.forEach(function (e) { if (e.isConnected) keep(e.innerText); });
  Array.prototype.forEach.call(document.querySelectorAll('h2, h3, span, div'), function (e) {
    if ((e.textContent || '').length > 40 || !heading.test((e.innerText || '').trim())) return;
    var n = e.parentElement;
    while (n && n !== document.body && (n.innerText || '').length < (e.innerText || '').length + 80) n = n.parentElement;
    if (!n || n === document.body) return;
    var t = String(n.innerText || '');
    var at = t.indexOf((e.innerText || '').trim());
    t = t.slice(at < 0 ? 0 : at);
    var stop = t.search(/(\n|\s)(ver menos|see less|mostrar menos|show less)\s*(\n|$)/i);
    if (stop >= 0) keep(t.slice(0, stop));
  });
  var shared = meta('og:description') || meta('description');
  var photos = [];
  function photo(src) {
    if (src && src.indexOf('https://') === 0 && photos.indexOf(src) < 0 && photos.length < 12) photos.push(src);
  }
  photo(meta('og:image'));
  Array.prototype.forEach.call(document.images, function (img) {
    if (img.naturalWidth >= 300 && img.naturalHeight >= 200) photo(img.currentSrc || img.src);
  });
  completion(JSON.stringify({
    p_key: KEY,
    p_ad: {
      version: __VERSION__,
      url: location.href,
      title: meta('og:title') || document.title,
      description: whole.length > shared.length ? whole : shared,
      price: meta('product:price:amount') || meta('og:price:amount'),
      old_price: oldPrice,
      lines: lines,
      text: text.join('\n'),
      photos: photos
    }
  }));
}
var buttons = /^(ver|mostrar|ler|see|show) (mais|menos|more|less)$/i;
var tail = /\s+(ver|mostrar|ler|see|show) (mais|menos|more|less)$/i;
var heading = /^(descri[cç][aã]o( do vendedor| do an[uú]ncio)?|(seller'?s )?description)$/i;
var opened = [];
var more = 0;
Array.prototype.forEach.call(document.querySelectorAll('[role="button"], button, span'), function (e) {
  var t = (e.innerText || '').trim();
  if (more < 3 && !e.closest('a[href]') && /^(ver mais|mostrar mais|see more|show more|ler mais)$/i.test(t)) {
    var n = e.parentElement;
    while (n && n !== document.body && (n.innerText || '').length < t.length + 80) n = n.parentElement;
    if (n && n !== document.body) opened.push(n);
    e.click();
    more++;
  }
});
setTimeout(read, more ? 800 : 0);
''';

/// The script with the account's [key] in it (64 hex digits, as
/// `create_ad_import_key` makes it), or, without one, the shared
/// shortcut's: the key then comes in [sharedAdKeyHeader].
String sharedAdScript([String? key]) {
  if (key != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
    throw ArgumentError.value(key, 'key', 'not a shortcut key');
  }
  return _template
      .replaceAll('__KEY__', key == null ? 'null' : "'$key'")
      .replaceAll('__VERSION__', '$sharedAdScriptVersion')
      .trim();
}
