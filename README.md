# Money Manager (Flutter)

A bucket-based personal money manager, rebuilt in Flutter from the original Expo / React Native app
([mayank20035/money-manager-app](https://github.com/mayank20035/money-manager-app)).

Split your money into **buckets** (spending cash, investments, a trip fund…), add income and split it
across buckets, record spends item by item, move money between buckets, and see where it all goes.

See [docs/ANALYSIS_AND_PLAN.md](docs/ANALYSIS_AND_PLAN.md) for the analysis of the original app and the
design of this version.

## Features
**Everything from the original app**
- Buckets with total balance, and a filter to include/exclude buckets from the total
- Add money with an optional percentage split to other buckets (remainder stays)
- Spend with multiple line items
- Split & transfer from one bucket to others
- Create, rename, delete buckets; reset everything

**New**
- Full **activity ledger** with search, filters, day grouping, swipe-to-delete (balances reverse automatically)
- **Undo** after every action
- **Categories** for spends and income sources
- **Insights**: monthly in/out/net, savings rate, category donut, daily spending, 6-month trend, balance by bucket
- **Savings goals** per bucket and a **monthly budget**
- **Calculator keypad** (`450+120×2`)
- Split by **% or amount**, "split equally", live allocation bar, remembers your last split per bucket
- Bucket **emoji + colour**, drag to reorder, bucket detail page, opening balance, balance adjustment
- **Dark mode**, accent colours, multiple currencies (₹ uses lakh grouping: ₹1,23,456.00)
- **Privacy mode** to mask amounts
- **Back up / restore** (JSON) and **CSV export** via clipboard
- Back-dated entries

## Under the hood
- Money is stored as **integer paise** – no floating-point drift
- The **ledger is the source of truth**: balances are the sum of transaction legs
- Splits use basis points with floor division; rounding remainders stay in the source bucket
- `provider` + `ChangeNotifier`, persisted to `shared_preferences` as versioned JSON

```
lib/
  core/     money formatting, calculator, split math, categories, theme
  data/     models + storage
  state/    MoneyStore (ledger + operations + undo), SettingsStore
  ui/       home, composer, bucket, history, insights, settings, shared widgets
test/       unit tests (core + store) and widget flow tests
```

## Run
```bash
flutter pub get
flutter run            # on a connected device / emulator
flutter run -d chrome  # in the browser
flutter test
```

Build an Android APK:
```bash
flutter build apk --release
```
The release build is signed with the debug key; set up your own keystore before publishing to the Play Store.
