/// Persisted account-language codes, shared with the app and database.
enum NotificationLanguage {
  portuguese('pt'),
  english('en');

  const NotificationLanguage(this.code);

  final String code;

  static NotificationLanguage fromCode(String code) => switch (code) {
    'pt' => portuguese,
    'en' => english,
    _ => throw FormatException('Unsupported notification language: $code'),
  };
}

/// Bundled notification copy. Seller content and diagnostics never pass here.
extension NotificationText on NotificationLanguage {
  String _text(String portuguese, String english) => switch (this) {
    .portuguese => portuguese,
    .english => english,
  };

  String alertHeading(String type, {required bool myColour}) => switch (type) {
    'new_listing' when myColour => _text(
      '🆕 Novo anúncio na sua cor',
      '🆕 New listing in your colour',
    ),
    'new_listing' => _text('🆕 Novo anúncio', '🆕 New listing'),
    'price_reduction' => _text('📉 Baixa de preço', '📉 Price drop'),
    'excellent_opportunity' => _text(
      '🔥 Excelente oportunidade',
      '🔥 Excellent opportunity',
    ),
    'listing_removed' => _text('🚫 Anúncio removido', '🚫 Listing removed'),
    'back_on_market' => _text('🔁 Voltou ao mercado', '🔁 Back on the market'),
    'target_price_reached' => _text(
      '🎯 Chegou ao seu preço',
      '🎯 Your target price was reached',
    ),
    _ => _text('🔔 Alerta', '🔔 Alert'),
  };

  String previously(String price) => _text('antes $price', 'previously $price');
  String targetPrice(String price) =>
      _text('o seu preço: $price', 'your target: $price');
  String get inYourColour => _text('Na sua cor', 'In your colour');
  String score(int? value) => _text('Pontuação $value', 'Score $value');

  String get testTitle => _text('Notificação de teste', 'Test notification');
  String get testBody => _text(
    'As notificações chegam a este aparelho. Os alertas aparecem assim '
        'depois de cada recolha.',
    'This device receives notifications. Alerts appear like this '
        'after each collection.',
  );
  String get testNote => _text(
    'Exemplo de teste: nada mudou.',
    'Test example: nothing has changed.',
  );
  String get example => _text('exemplo', 'example');

  String get recovered => _text(
    '✅ A recolha de anúncios voltou a funcionar.',
    '✅ Listing collection is working again.',
  );
  String get blocked => _text(
    '⛔ Um site recusou os pedidos da recolha de anúncios.',
    '⛔ A site refused the listing collector\'s requests.',
  );
  String get blockedAdvice => _text(
    'A recolha desse site fica em pausa durante 24 h e volta a tentar '
        'automaticamente.',
    'Collection from that site is paused for 24 hours and will resume '
        'automatically.',
  );
  String get failed => _text(
    '⚠️ A recolha de anúncios falhou.',
    '⚠️ Listing collection failed.',
  );
  String get failedTwice => _text(
    '⚠️ A recolha de anúncios falhou duas vezes seguidas.',
    '⚠️ Listing collection failed twice in a row.',
  );
  String get notStarted => _text(
    'Parou antes de começar (ao preparar a execução no GitHub): nada foi '
        'recolhido. Veja a execução em Estado da recolha.',
    'It stopped before starting (while preparing the GitHub run): nothing '
        'was collected. See the run in Collection status.',
  );
  String get failedAdvice => _text(
    'Os preços na app podem ficar desatualizados até a recolha voltar a '
        'funcionar.',
    'Prices in the app may be out of date until collection is working again.',
  );

  String _count(int count, String one, String many) =>
      '$count ${count == 1 ? one : many}';
  String newListings(int count) => _text(
    _count(count, 'anúncio novo', 'anúncios novos'),
    _count(count, 'new listing', 'new listings'),
  );
  String priceDrops(int count) => _text(
    _count(count, 'baixa de preço', 'baixas de preço'),
    _count(count, 'price drop', 'price drops'),
  );
  String goneListings(int count) => _text(
    _count(count, 'saiu do mercado', 'saíram do mercado'),
    '$count left the market',
  );

  /// The title of a run's summary of [count] more alerts.
  String moreAlerts(int count) => _text(
    '🔔 Mais ${_count(count, 'alerta', 'alertas')}',
    '🔔 ${_count(count, 'more alert', 'more alerts')}',
  );

  /// "[count] alerts of [type]", one part of that summary.
  String alertCount(String type, int count) => switch (type) {
    'new_listing' => newListings(count),
    'price_reduction' => priceDrops(count),
    'excellent_opportunity' => _text(
      _count(count, 'excelente oportunidade', 'excelentes oportunidades'),
      _count(count, 'excellent opportunity', 'excellent opportunities'),
    ),
    'listing_removed' => _text(
      _count(count, 'anúncio removido', 'anúncios removidos'),
      _count(count, 'listing removed', 'listings removed'),
    ),
    'back_on_market' => _text(
      _count(count, 'voltou ao mercado', 'voltaram ao mercado'),
      '$count back on the market',
    ),
    'target_price_reached' => _text(
      _count(count, 'chegou ao seu preço', 'chegaram ao seu preço'),
      '$count at your target price',
    ),
    _ => _text(
      _count(count, 'alerta', 'alertas'),
      _count(count, 'alert', 'alerts'),
    ),
  };

  String weekTitle(String from, String to) => _text(
    '📊 Resumo da semana · $from a $to',
    '📊 Weekly summary · $from to $to',
  );
  String bestDeal(String deal) => _text('Melhor: $deal', 'Best: $deal');

  String get bikeValueTitle => _text(
    '💶 Já sabemos quanto vale a sua mota',
    '💶 Your bike\'s value is ready',
  );
  String bikeValueEstimate(String price, int count) => _text(
    'Cerca de $price (de ${_count(count, 'anúncio', 'anúncios')})',
    'About $price (from ${_count(count, 'listing', 'listings')})',
  );
  String get bikeValueNone => _text(
    'Ainda não há anúncios suficientes para uma estimativa.',
    'There aren\'t enough listings for an estimate yet.',
  );

  String get photoExamTitle => _text(
    '📷 Todas as fotos foram examinadas',
    '📷 Every photo was examined',
  );
  String photoExamHints(int kinds) => kinds == 0
      ? _text(
          'Nenhuma pista de problemas nas fotos.',
          'No hint of problems in the photos.',
        )
      : _text(
          '${_count(kinds, 'pista', 'pistas')} nas fotos: veja a Avaliação.',
          '${_count(kinds, 'hint', 'hints')} in the photos: see the Assessment.',
        );

  String number(int value) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    final separator = _text(' ', ',');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(separator);
      out.write(digits[i]);
    }
    return out.toString();
  }

  String currency(num value) {
    final rounded = value.round();
    return _text(
      '${number(rounded)} €',
      '${rounded < 0 ? '-' : ''}€${number(rounded.abs())}',
    );
  }
}
