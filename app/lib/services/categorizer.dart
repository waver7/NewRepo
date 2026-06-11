/// Auto-categorization engine — the local implementation of the design's
/// five-stage cascade (docs/07): user overrides first, then a curated
/// merchant/keyword knowledge base, then heuristics. Every result carries a
/// source + confidence so the UI can explain itself.
library;

import '../models/models.dart';

class CategorizationResult {
  final String categoryId;
  final String source; // user|keyword|heuristic|none
  final double confidence;
  final String cleanedMerchant;

  const CategorizationResult(
      this.categoryId, this.source, this.confidence, this.cleanedMerchant);
}

class Categorizer {
  /// Learned overrides: normalized merchant key -> category id.
  /// Populated from user corrections ("always categorize X as Y").
  final Map<String, String> userOverrides;

  Categorizer({Map<String, String>? userOverrides})
      : userOverrides = userOverrides ?? {};

  /// Stage 0 — descriptor normalization. Strips processor prefixes, store
  /// numbers, dates and noise so "SQ *BLUEBTL COFFEE 4421" -> "BLUEBTL COFFEE".
  static String normalize(String raw) {
    var s = raw.toUpperCase();
    // Processor / channel prefixes.
    for (final p in [
      'SQ *', 'SQ*', 'TST* ', 'TST*', 'PAYPAL *', 'PYPL*', 'PP*',
      'AMZN MKTP ', 'AMAZON.COM*', 'GOOGLE *', 'APPLE.COM/BILL',
      'POS DEBIT ', 'DEBIT CARD PURCHASE ', 'ACH DEBIT ', 'ACH CREDIT ',
      'CHECKCARD ', 'PURCHASE AUTHORIZED ON ',
    ]) {
      if (s.startsWith(p)) s = s.substring(p.length);
    }
    // Trailing store numbers, dates, card suffixes, state codes w/ city noise.
    s = s.replaceAll(RegExp(r'\b\d{2}/\d{2}\b'), ' ');
    s = s.replaceAll(RegExp(r'#\d+'), ' ');
    s = s.replaceAll(RegExp(r'\b\d{4,}\b'), ' ');
    s = s.replaceAll(RegExp(r'[^A-Z0-9&. ]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// A stable key for grouping/learning: first 3 tokens of the normalized name.
  static String merchantKey(String raw) {
    final tokens = normalize(raw).split(' ');
    return tokens.take(3).join(' ');
  }

  /// Title-cases a normalized descriptor for display.
  static String displayName(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return raw.trim();
    return n
        .split(' ')
        .map((w) => w.length <= 2
            ? w
            : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Curated keyword knowledge base. First match wins (list order = priority),
  /// so more specific entries (UBER EATS) come before generic ones (UBER).
  static const List<(String, String)> _keywordRules = [
    // Income
    ('PAYROLL', 'income.salary'), ('DIRECT DEP', 'income.salary'),
    ('SALARY', 'income.salary'), ('PAYCHECK', 'income.salary'),
    ('INTEREST PAYMENT', 'income.interest'), ('INTEREST PAID', 'income.interest'),
    ('REFUND', 'income.refund'), ('REVERSAL', 'income.refund'),
    // Transfers / P2P
    ('TRANSFER', 'transfer.internal'), ('ZELLE', 'transfer.p2p'),
    ('VENMO', 'transfer.p2p'), ('CASH APP', 'transfer.p2p'),
    ('CREDIT CARD PAYMENT', 'transfer.cc_payment'),
    ('PAYMENT THANK YOU', 'transfer.cc_payment'),
    ('AUTOPAY', 'transfer.cc_payment'),
    // Housing & utilities
    ('RENT', 'housing.rent'), ('MORTGAGE', 'housing.mortgage'),
    ('ELECTRIC', 'utilities.electric'), ('PG&E', 'utilities.electric'),
    ('CONED', 'utilities.electric'), ('DUKE ENERGY', 'utilities.electric'),
    ('WATER UTIL', 'utilities.water'), ('COMCAST', 'utilities.internet'),
    ('XFINITY', 'utilities.internet'), ('SPECTRUM', 'utilities.internet'),
    ('VERIZON FIOS', 'utilities.internet'),
    ('VERIZON', 'utilities.phone'), ('T MOBILE', 'utilities.phone'),
    ('TMOBILE', 'utilities.phone'), ('AT&T', 'utilities.phone'),
    ('MINT MOBILE', 'utilities.phone'),
    // Coffee before restaurants (more specific).
    ('STARBUCKS', 'food.coffee'), ('BLUE BOTTLE', 'food.coffee'),
    ('BLUEBTL', 'food.coffee'), ('PEETS', 'food.coffee'),
    ('DUTCH BROS', 'food.coffee'), ('DUNKIN', 'food.coffee'),
    ('PHILZ', 'food.coffee'), ('COFFEE', 'food.coffee'),
    // Delivery before restaurants and before rideshare (UBER EATS vs UBER).
    ('UBER EATS', 'food.delivery'), ('UBEREATS', 'food.delivery'),
    ('DOORDASH', 'food.delivery'), ('GRUBHUB', 'food.delivery'),
    ('POSTMATES', 'food.delivery'), ('INSTACART', 'food.groceries'),
    // Groceries
    ('WHOLE FOODS', 'food.groceries'), ('TRADER JOE', 'food.groceries'),
    ('SAFEWAY', 'food.groceries'), ('KROGER', 'food.groceries'),
    ('ALDI', 'food.groceries'), ('COSTCO', 'food.groceries'),
    ('WALMART', 'food.groceries'), ('TARGET', 'shopping.general'),
    ('WEGMANS', 'food.groceries'), ('PUBLIX', 'food.groceries'),
    ('LIDL', 'food.groceries'), ('GROCERY', 'food.groceries'),
    ('MARKET', 'food.groceries'),
    // Restaurants
    ('MCDONALD', 'food.restaurants'), ('CHIPOTLE', 'food.restaurants'),
    ('CHICK FIL A', 'food.restaurants'), ('SHAKE SHACK', 'food.restaurants'),
    ('SWEETGREEN', 'food.restaurants'), ('PANERA', 'food.restaurants'),
    ('TACO BELL', 'food.restaurants'), ('PIZZA', 'food.restaurants'),
    ('RESTAURANT', 'food.restaurants'), ('SUSHI', 'food.restaurants'),
    ('THAI', 'food.restaurants'), ('BURGER', 'food.restaurants'),
    ('CAFE', 'food.restaurants'), ('DINER', 'food.restaurants'),
    ('GRILL', 'food.restaurants'), ('KITCHEN', 'food.restaurants'),
    // Transport
    ('SHELL', 'transport.gas'), ('CHEVRON', 'transport.gas'),
    ('EXXON', 'transport.gas'), ('MOBIL', 'transport.gas'),
    ('BP ', 'transport.gas'), ('ARCO', 'transport.gas'),
    ('76 ', 'transport.gas'), ('FUEL', 'transport.gas'),
    ('UBER', 'transport.rideshare'), ('LYFT', 'transport.rideshare'),
    ('MTA', 'transport.transit'), ('BART', 'transport.transit'),
    ('TRANSIT', 'transport.transit'), ('METRO', 'transport.transit'),
    ('CLIPPER', 'transport.transit'), ('PARKING', 'transport.parking'),
    ('GEICO', 'transport.insurance'), ('PROGRESSIVE', 'transport.insurance'),
    ('STATE FARM', 'transport.insurance'),
    // Health
    ('CVS', 'health.pharmacy'), ('WALGREENS', 'health.pharmacy'),
    ('RITE AID', 'health.pharmacy'), ('PHARMACY', 'health.pharmacy'),
    ('GYM', 'health.fitness'), ('FITNESS', 'health.fitness'),
    ('EQUINOX', 'health.fitness'), ('PLANET FIT', 'health.fitness'),
    ('CRUNCH', 'health.fitness'), ('PELOTON', 'health.fitness'),
    ('CLASSPASS', 'health.fitness'),
    // Streaming & subscriptions
    ('NETFLIX', 'fun.streaming'), ('HULU', 'fun.streaming'),
    ('DISNEY PLUS', 'fun.streaming'), ('DISNEYPLUS', 'fun.streaming'),
    ('HBO', 'fun.streaming'), ('MAX.COM', 'fun.streaming'),
    ('PARAMOUNT', 'fun.streaming'), ('PEACOCK', 'fun.streaming'),
    ('SPOTIFY', 'fun.streaming'), ('APPLE MUSIC', 'fun.streaming'),
    ('YOUTUBE PREMIUM', 'fun.streaming'), ('AUDIBLE', 'fun.streaming'),
    ('CRUNCHYROLL', 'fun.streaming'), ('TWITCH', 'fun.streaming'),
    ('ICLOUD', 'subs.software'), ('GOOGLE STORAGE', 'subs.software'),
    ('GOOGLE ONE', 'subs.software'), ('DROPBOX', 'subs.software'),
    ('ADOBE', 'subs.software'), ('NOTION', 'subs.software'),
    ('CHATGPT', 'subs.software'), ('OPENAI', 'subs.software'),
    ('CLAUDE.AI', 'subs.software'), ('ANTHROPIC', 'subs.software'),
    ('GITHUB', 'subs.software'), ('1PASSWORD', 'subs.software'),
    ('NYTIMES', 'subs.news'), ('NY TIMES', 'subs.news'),
    ('WSJ', 'subs.news'), ('WASHINGTON POST', 'subs.news'),
    ('ECONOMIST', 'subs.news'), ('SUBSTACK', 'subs.news'),
    ('PRIME MEMBERSHIP', 'subs.membership'), ('AMAZON PRIME', 'subs.membership'),
    // Shopping
    ('AMAZON', 'shopping.general'), ('AMZN', 'shopping.general'),
    ('EBAY', 'shopping.general'), ('ETSY', 'shopping.general'),
    ('BEST BUY', 'shopping.electronics'), ('APPLE STORE', 'shopping.electronics'),
    ('IKEA', 'shopping.general'), ('H&M', 'shopping.general'),
    ('ZARA', 'shopping.general'), ('UNIQLO', 'shopping.general'),
    ('NIKE', 'shopping.general'), ('SEPHORA', 'personal.beauty'),
    // Travel
    ('AIRLINE', 'travel.flights'), ('AIRLINES', 'travel.flights'),
    ('DELTA AIR', 'travel.flights'), ('UNITED ', 'travel.flights'),
    ('SOUTHWEST', 'travel.flights'), ('JETBLUE', 'travel.flights'),
    ('AIRBNB', 'travel.hotels'), ('MARRIOTT', 'travel.hotels'),
    ('HILTON', 'travel.hotels'), ('HOTEL', 'travel.hotels'),
    ('EXPEDIA', 'travel.other'), ('BOOKING.COM', 'travel.other'),
    // Pets / education / misc
    ('CHEWY', 'family.pets'), ('PETCO', 'family.pets'),
    ('PETSMART', 'family.pets'), ('VET ', 'family.pets'),
    ('UDEMY', 'family.education'), ('COURSERA', 'family.education'),
    ('TUITION', 'family.education'),
    // Financial
    ('OVERDRAFT', 'financial.fees'), ('MONTHLY FEE', 'financial.fees'),
    ('SERVICE FEE', 'financial.fees'), ('ATM FEE', 'financial.fees'),
    ('FOREIGN TRANSACTION', 'financial.fees'),
    ('LOAN PAYMENT', 'financial.loan'), ('STUDENT LOAN', 'financial.loan'),
    ('NELNET', 'financial.loan'), ('IRS', 'financial.taxes'),
    ('TAX PAYMENT', 'financial.taxes'),
    ('ATM WITHDRAWAL', 'personal.cash'), ('ATM ', 'personal.cash'),
  ];

  CategorizationResult categorize(String rawDesc, int amountCents) {
    final normalized = normalize(rawDesc);
    final key = merchantKey(rawDesc);
    final display = displayName(rawDesc);

    // Stage 1 — user override (learned from corrections). Highest trust.
    final override = userOverrides[key];
    if (override != null) {
      return CategorizationResult(override, 'user', 0.99, display);
    }

    // Stage 2 — curated keyword knowledge base.
    for (final (kw, cat) in _keywordRules) {
      if (normalized.contains(kw)) {
        // Income keywords should not fire on outflows and vice versa.
        final kind = Categories.get(cat).kind;
        if (kind == CategoryKind.income && amountCents < 0) continue;
        return CategorizationResult(cat, 'keyword', 0.92, display);
      }
    }

    // Stage 3 — heuristics on amount sign.
    if (amountCents > 0) {
      return CategorizationResult('income.other', 'heuristic', 0.5, display);
    }
    return CategorizationResult(
        'other.uncategorized', 'none', 0.0, display);
  }

  /// Records a user correction so every future transaction from the same
  /// merchant gets their category ("never the same correction twice").
  void learn(String rawDesc, String categoryId) {
    userOverrides[merchantKey(rawDesc)] = categoryId;
  }
}
