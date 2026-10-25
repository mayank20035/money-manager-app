import 'package:flutter/material.dart';

/// Accent colours offered in Settings.
const accentChoices = <Color>[
  Color(0xFF4F46E5), // indigo
  Color(0xFF0D9488), // teal
  Color(0xFF7C3AED), // violet
  Color(0xFF2563EB), // blue
  Color(0xFFDB2777), // pink
  Color(0xFFEA580C), // orange
  Color(0xFF059669), // emerald
];

/// Semantic money colours that stay readable in both themes.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({required this.income, required this.expense, required this.transfer});

  final Color income;
  final Color expense;
  final Color transfer;

  static MoneyColors of(BuildContext context) => Theme.of(context).extension<MoneyColors>()!;

  @override
  MoneyColors copyWith({Color? income, Color? expense, Color? transfer}) => MoneyColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer ?? this.transfer,
      );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

ThemeData buildTheme(Color seed, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final radius = BorderRadius.circular(18);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0E0F14) : const Color(0xFFF5F6FA),
    extensions: [
      MoneyColors(
        income: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
        expense: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
        transfer: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF181A22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F222C) : const Color(0xFFF0F1F6),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF14161D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF14161D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      space: 1,
    ),
  );
}
