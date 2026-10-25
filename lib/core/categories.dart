import 'package:flutter/material.dart';

class Category {
  const Category(this.id, this.name, this.emoji, this.color);

  final String id;
  final String name;
  final String emoji;
  final Color color;
}

const expenseCategories = <Category>[
  Category('food', 'Food & Dining', '🍔', Color(0xFFF97316)),
  Category('groceries', 'Groceries', '🛒', Color(0xFF22C55E)),
  Category('transport', 'Transport', '🚕', Color(0xFF0EA5E9)),
  Category('shopping', 'Shopping', '🛍️', Color(0xFFEC4899)),
  Category('bills', 'Bills & Utilities', '💡', Color(0xFFEAB308)),
  Category('rent', 'Rent & Home', '🏠', Color(0xFF8B5CF6)),
  Category('health', 'Health', '💊', Color(0xFFEF4444)),
  Category('fun', 'Entertainment', '🎬', Color(0xFF6366F1)),
  Category('education', 'Education', '📚', Color(0xFF14B8A6)),
  Category('travel', 'Travel', '✈️', Color(0xFF06B6D4)),
  Category('subscriptions', 'Subscriptions', '🔁', Color(0xFFA855F7)),
  Category('gifts', 'Gifts & Donations', '🎁', Color(0xFFF43F5E)),
  Category('other', 'Other', '📦', Color(0xFF64748B)),
];

const incomeCategories = <Category>[
  Category('salary', 'Salary', '💼', Color(0xFF10B981)),
  Category('business', 'Business', '🏪', Color(0xFF0EA5E9)),
  Category('freelance', 'Freelance', '💻', Color(0xFF6366F1)),
  Category('interest', 'Interest & Returns', '📈', Color(0xFF22C55E)),
  Category('gift_in', 'Gift', '🎁', Color(0xFFF43F5E)),
  Category('refund', 'Refund', '↩️', Color(0xFFF59E0B)),
  Category('other_in', 'Other', '💰', Color(0xFF64748B)),
];

const _fallback = Category('other', 'Other', '📦', Color(0xFF64748B));

Category categoryById(String? id) {
  for (final c in expenseCategories) {
    if (c.id == id) return c;
  }
  for (final c in incomeCategories) {
    if (c.id == id) return c;
  }
  return _fallback;
}

/// Emoji choices for buckets.
const bucketEmojis = [
  '💳', '💵', '📈', '🐷', '🏦', '🎯', '🏠', '🚗', '✈️', '🎓',
  '💍', '🎁', '🛡️', '🏥', '📱', '🍽️', '🛒', '👶', '🐶', '🎮',
  '💼', '🪙', '💎', '🌴',
];

/// Colour choices for buckets.
const bucketColors = <Color>[
  Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF14B8A6),
  Color(0xFF64748B), Color(0xFFF97316),
];
