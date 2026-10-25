# Money Manager — Analysis & Flutter Implementation Plan

## 1. Analysis of the original app (`mayank20035/money-manager-app`)

**Stack:** Expo 54 / React Native 0.81, expo-router, AsyncStorage. Practically all logic and UI live
in a single 905-line component, `app/(tabs)/index.tsx`. The rest of the repo is unused Expo template
code (`explore.tsx` is empty, `modal.tsx`, themed components, `firebase` dependency never imported).

### Data model
```ts
Section { id, name, currentAmount: number, isIncludedInTotal?: boolean }
```
Stored as a JSON array under `@money_manager_sections`. Two default buckets: *Usable Money* and *Invested Money*.

### Features
| Feature | Behaviour |
|---|---|
| Total balance | Sum of buckets with `isIncludedInTotal` |
| Filter | Sheet with a switch per bucket to include/exclude from the total |
| Deposit (+) | Adds an amount to a bucket; optional **split**: % per other bucket, remainder stays in the bucket |
| Spend (−) | Multiple amount rows summed into one withdrawal |
| Split & Transfer (ⓘ icon) | Distribute an amount from a bucket to others by %; remainder stays |
| Bucket CRUD | Add, rename, delete (with confirm) |
| Reset | Wipes all buckets |

### Problems found
1. **No transaction history.** Balances are mutated in place; there is no record, no undo, no insights.
2. **Spend rows have no label or category** — just numbers, so you can never see *what* you spent on.
3. **Floating-point money.** `currentAmount` is a JS float; repeated % splits accumulate rounding errors.
4. **Persistence bug:** the save effect only runs when `sections.length > 0`, so deleting the last
   bucket is never saved — it reappears on next launch.
5. **No overspend check** on Spend; a bucket silently goes negative.
6. Deposit amount isn't validated by regex (`parseFloat("12abc") === 12`).
7. Transfer is hidden behind an *Info* icon — poor discoverability.
8. Split state (`splitAllocations`) is shared between two different modals.
9. `₹` with `en-US` grouping (1,234,567) instead of Indian grouping (12,34,567).
10. Light theme only (hard-coded colours) despite `userInterfaceStyle: automatic`.
11. No way to set an opening balance, back-date an entry, back up or export data.
12. Single-file architecture: hard to test or extend; dead styles and dead dependencies.

## 2. Goals for the Flutter version
* **Full parity** with every original feature (buckets, include-in-total filter, deposit with split,
  multi-item spend, split & transfer, CRUD, reset).
* **Fix every problem above.**
* **Look and feel much better**: Material 3, gradient hero card, bucket colours + emoji, animations,
  dark mode, custom calculator keypad.
* **Clean, testable architecture.**

## 3. New features
| # | Feature | Notes |
|---|---|---|
| 1 | **Ledger / History** | Every action is a transaction. Search, filter by type & bucket, grouped by day with daily totals. Swipe to delete (balances auto-reverse). |
| 2 | **Undo** | Snackbar "Undo" after every add/spend/transfer/delete. |
| 3 | **Categories** | Expense categories (Food, Transport, Bills…) and income sources (Salary, Freelance…) with emoji + colour. |
| 4 | **Insights** | Month picker; income / spend / net / savings-rate tiles; category donut; 6-month income-vs-spend bars; daily spending trend. |
| 5 | **Savings goals** | Optional target per bucket, progress bar on card and ring on detail page. |
| 6 | **Monthly budget** | Global monthly spending budget with progress on the home screen. |
| 7 | **Calculator keypad** | Enter `450+120×2` directly; haptic feedback. |
| 8 | **Split editor 2.0** | Split by % *or* by amount, "Equal" quick action, live coloured allocation bar, remember last split per bucket. |
| 9 | **Bucket detail page** | Balance, goal ring, month in/out, the bucket's own history, quick actions. |
| 10 | **Opening balance & Adjust balance** | Set a starting amount or correct a balance; recorded as an adjustment. |
| 11 | **Reorder buckets** | Long-press & drag. |
| 12 | **Privacy mode** | Eye toggle masks all amounts. |
| 13 | **Theme & currency** | System/Light/Dark, accent colour, currency symbol (₹ uses lakh grouping). |
| 14 | **Backup** | Export/Import JSON and export CSV via clipboard. |
| 15 | **Back-dating** | Pick the date of any transaction. |

## 4. Architecture
```
lib/
  main.dart                 bootstrap: load stores, runApp
  app.dart                  MaterialApp, theme wiring
  core/
    money.dart              Money formatting/parsing (integer minor units)
    calculator.dart         Safe expression evaluator for the keypad
    split.dart              Exact integer split math (basis points)
    theme.dart              Light/dark themes from accent seed
    categories.dart         Built-in expense/income categories
  data/
    models.dart             Bucket, Txn, TxnLeg, TxnType (+ JSON)
    storage.dart            shared_preferences JSON persistence (versioned)
  state/
    money_store.dart        ChangeNotifier: buckets, ledger, balances, operations, undo
    settings_store.dart     ChangeNotifier: theme, accent, currency, budget, privacy
  ui/
    shell.dart              Bottom navigation (Home / History / Insights / Settings) + FAB
    home/                   Hero balance card, bucket cards, recent activity
    bucket/                 Bucket detail page, bucket editor sheet
    composer/               Expense / Income / Transfer composer, keypad, split editor
    history/                Ledger list, transaction detail sheet
    insights/               Charts (fl_chart)
    settings/               Settings & backup
    widgets/                MoneyText (privacy-aware), animated amount, pickers, empty states
```

**Key design decisions**
* **Money is stored as integer paise** (`int amountMinor`). No floating-point drift.
* **Ledger is the source of truth.** A `Txn` has one or more *legs* (`bucketId`, signed amount).
  Bucket balance = Σ legs. Deleting a transaction automatically reverses its effect; a deposit split
  across 3 buckets is one transaction with 3 legs, a transfer is one transaction with a negative source
  leg and positive target legs.
* **Splits use basis points and floor division**; any rounding remainder stays in the source bucket, so
  totals always reconcile to the paisa.
* **Undo = snapshot** of (buckets, txns) before each mutation.
* State: `provider` + `ChangeNotifier` (small app, no codegen needed).
* Persistence: `shared_preferences` with a versioned JSON document (works on Android, iOS, web, desktop).

**Packages:** `provider`, `shared_preferences`, `intl`, `fl_chart`.

## 5. Implementation steps
1. `flutter create` (org `com.mayank20035`, Android/iOS/web), add packages, lints.
2. Core layer: money, calculator, split math, categories, theme — with unit tests.
3. Data layer: models + JSON + storage.
4. State: MoneyStore operations (create/update/delete/reorder bucket, income with split, multi-item
   expense, split transfer, adjust balance, delete txn, undo, reset, import/export) — with unit tests.
5. UI: shell → Home → composer → bucket detail/editor → history → insights → settings.
6. `flutter analyze`, `flutter test`, run on web and check every screen visually; build an Android APK.

## 6. Out of scope (possible next steps)
Cloud sync / multi-device, recurring transactions, biometric app lock, home-screen widget, importing
data from the old Expo app (its AsyncStorage data cannot be read by a different app).
