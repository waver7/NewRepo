/// SQLite persistence (sqflite). Mirrors a slice of the production schema in
/// docs/05 — accounts, transactions, budgets, goals, learned category
/// overrides, and a key/value meta table for settings.
library;

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class LumenDb {
  static const _version = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = '${await getDatabasesPath()}/lumen.db';
    _db = await openDatabase(path, version: _version, onCreate: _onCreate);
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        starting_balance_cents INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'USD'
      )''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        date TEXT NOT NULL,
        merchant TEXT NOT NULL,
        raw_desc TEXT NOT NULL,
        category_id TEXT NOT NULL,
        category_source TEXT NOT NULL,
        is_transfer INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'manual',
        fingerprint TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute(
        'CREATE INDEX idx_txn_date ON transactions(date DESC)');
    await db.execute(
        'CREATE INDEX idx_txn_fingerprint ON transactions(fingerprint)');
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL UNIQUE,
        limit_cents INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🎯',
        target_cents INTEGER NOT NULL,
        saved_cents INTEGER NOT NULL DEFAULT 0,
        target_date TEXT
      )''');
    await db.execute('''
      CREATE TABLE category_overrides (
        merchant_key TEXT PRIMARY KEY,
        category_id TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
  }

  // ---- accounts ----
  Future<List<Account>> accounts() async {
    final db = await database;
    final rows = await db.query('accounts', orderBy: 'name');
    return rows.map(Account.fromMap).toList();
  }

  Future<void> upsertAccount(Account a) async {
    final db = await database;
    await db.insert('accounts', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'account_id = ?', whereArgs: [id]);
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ---- transactions ----
  Future<List<Txn>> transactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(Txn.fromMap).toList();
  }

  Future<void> upsertTxn(Txn t) async {
    final db = await database;
    await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTxns(List<Txn> txns) async {
    final db = await database;
    final batch = db.batch();
    for (final t in txns) {
      batch.insert('transactions', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTxn(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ---- budgets ----
  Future<List<Budget>> budgets() async {
    final db = await database;
    return (await db.query('budgets')).map(Budget.fromMap).toList();
  }

  Future<void> upsertBudget(Budget b) async {
    final db = await database;
    await db.insert('budgets', b.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ---- goals ----
  Future<List<Goal>> goals() async {
    final db = await database;
    return (await db.query('goals')).map(Goal.fromMap).toList();
  }

  Future<void> upsertGoal(Goal g) async {
    final db = await database;
    await db.insert('goals', g.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  // ---- learned overrides ----
  Future<Map<String, String>> categoryOverrides() async {
    final db = await database;
    final rows = await db.query('category_overrides');
    return {
      for (final r in rows)
        r['merchant_key'] as String: r['category_id'] as String
    };
  }

  Future<void> saveOverride(String merchantKey, String categoryId) async {
    final db = await database;
    await db.insert(
        'category_overrides',
        {'merchant_key': merchantKey, 'category_id': categoryId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- meta ----
  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> wipeAll() async {
    final db = await database;
    for (final t in [
      'transactions', 'accounts', 'budgets', 'goals',
      'category_overrides', 'meta',
    ]) {
      await db.delete(t);
    }
  }
}
