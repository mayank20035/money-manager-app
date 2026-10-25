import 'dart:math';

import 'package:flutter/painting.dart';

final _rand = Random();

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rand.nextInt(1 << 30).toRadixString(36);

/// A pot of money ("bucket" in the original app).
class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.includeInTotal = true,
    this.goalMinor,
    this.defaultSplit = const {},
  });

  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final bool includeInTotal;

  /// Optional savings target in minor units.
  final int? goalMinor;

  /// Last split used from this bucket (target bucket id → basis points),
  /// used to pre-fill the split editor next time.
  final Map<String, int> defaultSplit;

  Color get color => Color(colorValue);

  Bucket copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    bool? includeInTotal,
    int? Function()? goalMinor,
    Map<String, int>? defaultSplit,
  }) =>
      Bucket(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorValue: colorValue ?? this.colorValue,
        includeInTotal: includeInTotal ?? this.includeInTotal,
        goalMinor: goalMinor != null ? goalMinor() : this.goalMinor,
        defaultSplit: defaultSplit ?? this.defaultSplit,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': colorValue,
        'include': includeInTotal,
        if (goalMinor != null) 'goal': goalMinor,
        if (defaultSplit.isNotEmpty) 'split': defaultSplit,
      };

  factory Bucket.fromJson(Map<String, dynamic> j) => Bucket(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] as String?) ?? '💰',
        colorValue: (j['color'] as num?)?.toInt() ?? 0xFF6366F1,
        includeInTotal: (j['include'] as bool?) ?? true,
        goalMinor: (j['goal'] as num?)?.toInt(),
        defaultSplit: ((j['split'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

enum TxnType { income, expense, transfer, adjustment }

/// The effect of a transaction on one bucket (signed, minor units).
class TxnLeg {
  const TxnLeg(this.bucketId, this.amountMinor);

  final String bucketId;
  final int amountMinor;

  Map<String, dynamic> toJson() => {'b': bucketId, 'a': amountMinor};

  factory TxnLeg.fromJson(Map<String, dynamic> j) =>
      TxnLeg(j['b'] as String, (j['a'] as num).toInt());
}

/// One ledger entry. Bucket balances are the sum of all legs.
class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.date,
    required this.legs,
    this.categoryId,
    this.note = '',
    this.groupId,
  });

  final String id;
  final TxnType type;
  final DateTime date;
  final List<TxnLeg> legs;
  final String? categoryId;
  final String note;

  /// Shared by entries created together (e.g. a multi-item spend), so they undo together.
  final String? groupId;

  /// Headline amount, always positive except for downward adjustments.
  int get amountMinor {
    switch (type) {
      case TxnType.income:
      case TxnType.transfer:
        return legs.where((l) => l.amountMinor > 0).fold(0, (s, l) => s + l.amountMinor);
      case TxnType.expense:
        return -legs.fold(0, (s, l) => s + l.amountMinor);
      case TxnType.adjustment:
        return legs.fold(0, (s, l) => s + l.amountMinor);
    }
  }

  /// The bucket this transaction is "about": the source of a spend or
  /// transfer, the receiving bucket of a deposit.
  String? get primaryBucketId {
    if (legs.isEmpty) return null;
    if (type == TxnType.expense || type == TxnType.transfer) {
      return legs.firstWhere((l) => l.amountMinor < 0, orElse: () => legs.first).bucketId;
    }
    return legs.first.bucketId;
  }

  int deltaFor(String bucketId) =>
      legs.where((l) => l.bucketId == bucketId).fold(0, (s, l) => s + l.amountMinor);

  Txn copyWith({List<TxnLeg>? legs}) => Txn(
        id: id,
        type: type,
        date: date,
        legs: legs ?? this.legs,
        categoryId: categoryId,
        note: note,
        groupId: groupId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        't': type.name,
        'd': date.millisecondsSinceEpoch,
        'l': legs.map((l) => l.toJson()).toList(),
        if (categoryId != null) 'c': categoryId,
        if (note.isNotEmpty) 'n': note,
        if (groupId != null) 'g': groupId,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: TxnType.values.byName(j['t'] as String),
        date: DateTime.fromMillisecondsSinceEpoch((j['d'] as num).toInt()),
        legs: (j['l'] as List)
            .map((e) => TxnLeg.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        categoryId: j['c'] as String?,
        note: (j['n'] as String?) ?? '',
        groupId: j['g'] as String?,
      );
}

/// One line of a multi-item spend.
class ExpenseItem {
  const ExpenseItem({required this.amountMinor, required this.categoryId, this.note = ''});

  final int amountMinor;
  final String categoryId;
  final String note;
}
