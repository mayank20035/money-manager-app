import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Versioned JSON persistence on top of shared_preferences.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const ledgerKey = 'mm.ledger';
  static const settingsKey = 'mm.settings';
  static const schemaVersion = 1;

  ({List<Bucket> buckets, List<Txn> txns})? loadLedger() {
    final raw = _prefs.getString(ledgerKey);
    if (raw == null) return null;
    try {
      return decodeLedger(raw);
    } on Object {
      return null;
    }
  }

  Future<void> saveLedger(List<Bucket> buckets, List<Txn> txns) =>
      _prefs.setString(ledgerKey, encodeLedger(buckets, txns));

  Map<String, dynamic> loadSettings() {
    final raw = _prefs.getString(settingsKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      return {};
    }
  }

  Future<void> saveSettings(Map<String, dynamic> json) =>
      _prefs.setString(settingsKey, jsonEncode(json));

  static String encodeLedger(List<Bucket> buckets, List<Txn> txns, {bool pretty = false}) {
    final doc = {
      'app': 'money_manager',
      'version': schemaVersion,
      'buckets': buckets.map((b) => b.toJson()).toList(),
      'txns': txns.map((t) => t.toJson()).toList(),
    };
    return pretty ? const JsonEncoder.withIndent('  ').convert(doc) : jsonEncode(doc);
  }

  /// Throws [FormatException] when [raw] is not a valid ledger document.
  static ({List<Bucket> buckets, List<Txn> txns}) decodeLedger(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Not valid JSON');
    }
    if (decoded is! Map || decoded['buckets'] is! List || decoded['txns'] is! List) {
      throw const FormatException('This is not a Money Manager backup');
    }
    try {
      final buckets = (decoded['buckets'] as List)
          .map((e) => Bucket.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final txns = (decoded['txns'] as List)
          .map((e) => Txn.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return (buckets: buckets, txns: txns);
    } on Object {
      throw const FormatException('The backup is damaged');
    }
  }
}
