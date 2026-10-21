# 💰 Developer Guide: Accounting & Financial Ledger Engine

This technical document details the architecture, mathematical invariants, double-entry ledger engine, and database schema powering the Accounting, Banking, Loan EMI, and Financial Reports subsystems.

---

## 🏛️ Accounting Architecture & Core Invariants

The accounting subsystem enforces GAAP / IFRS-compliant **Double-Entry Bookkeeping**:

### 1. Fundamental Accounting Equation
$$\text{Assets} = \text{Liabilities} + \text{Equity} + (\text{Income} - \text{Expenses})$$

### 2. Transaction Invariant
Every transaction recorded in the ledger MUST satisfy:
$$\sum \text{Debits} = \sum \text{Credits}$$
If a voucher has unequal debits and credits, the database transaction rolls back immediately with an `UNBALANCED_JOURNAL_ENTRY` exception.

---

## 🌳 Chart of Accounts (COA) Model & Tree Hierarchy

All accounts belong to one of 5 root account types (`ASSET`, `LIABILITY`, `EQUITY`, `INCOME`, `EXPENSE`):

```text
Chart of Accounts Tree
├── 1000 - ASSETS (Debit Normal)
│   ├── 1100 - Current Assets
│   │   ├── 1110 - Cash in Hand (Cash Drawer)
│   │   ├── 1120 - Bank Accounts (HDFC, Chase, Barclays)
│   │   └── 1130 - Inventory Asset (Stock Valuation)
│   └── 1200 - Fixed Assets (Equipment, POS Terminals, Vehicles)
├── 2000 - LIABILITIES (Credit Normal)
│   ├── 2100 - Accounts Payable (Supplier Balances)
│   ├── 2200 - Taxes Payable (GST / VAT / Sales Tax Output)
│   └── 2300 - Bank Business Loans
├── 3000 - EQUITY (Credit Normal)
│   ├── 3100 - Owner's Capital
│   └── 3200 - Retained Earnings
├── 4000 - INCOME (Credit Normal)
│   ├── 4100 - Retail Sales Revenue
│   ├── 4200 - Restaurant F&B Revenue
│   └── 4300 - Delivery & Service Fees
└── 5000 - EXPENSES (Debit Normal)
    ├── 5100 - Cost of Goods Sold (COGS)
    ├── 5200 - Salaries & Wages
    ├── 5300 - Shop Rent & Utilities
    └── 5400 - Damage & Spoilage Loss
```

---

## 🧾 Database Entities & Schema

### 1. `Account` (Chart of Accounts Master)
- `id` (PK, Integer)
- `account_code` (String, e.g., "1120-01")
- `account_name` (String, e.g., "HDFC Current Operating Account")
- `account_type` (Enum: `ASSET`, `LIABILITY`, `EQUITY`, `INCOME`, `EXPENSE`)
- `parent_id` (FK -> `Account`, nullable for root nodes)
- `opening_balance` (Decimal)
- `current_balance` (Decimal, cached balance updated atomically)
- `is_active` (Boolean)
- `outlet_code` (String)

### 2. `AccountingVoucher` (Journal Header)
- `id` (PK, Integer)
- `voucher_number` (String, e.g., `JV-2026-0045`, `PV-2026-0120`)
- `voucher_type` (Enum: `JOURNAL`, `PAYMENT`, `RECEIPT`, `CONTRA`, `DEBIT_NOTE`, `CREDIT_NOTE`)
- `voucher_date` (Date)
- `reference_type` (String, e.g., `SALE_INVOICE`, `GRN_PURCHASE`, `LOAN_EMI`, `MANUAL`)
- `reference_id` (String / Integer)
- `total_amount` (Decimal)
- `narration` (Text)
- `created_by` (FK -> `User`)
- `outlet_code` (String)

### 3. `VoucherEntry` (Ledger Line Items)
- `id` (PK, Integer)
- `voucher_id` (FK -> `AccountingVoucher`, CASCADE)
- `account_id` (FK -> `Account`)
- `debit_amount` (Decimal, default 0.00)
- `credit_amount` (Decimal, default 0.00)
- `line_narration` (String)

---

## 🧮 Financial Calculations & Algorithms

### 1. Loan EMI Calculation (Standard Amortization Formula)
$$\text{EMI} = P \times r \times \frac{(1 + r)^n}{(1 + r)^n - 1}$$
Where:
- $P$ = Principal loan amount
- $r$ = Monthly interest rate ($\text{Annual Rate} / 12 / 100$)
- $n$ = Total tenure in months

**Monthly Split Invariant**:
$$\text{Interest Component} = \text{Outstanding Principal} \times r$$
$$\text{Principal Component} = \text{EMI} - \text{Interest Component}$$

When an EMI is paid, the system automatically writes:
- **Debit**: `Loan Liability Account` (Principal Component)
- **Debit**: `Interest Expense Account` (Interest Component)
- **Credit**: `Bank Account` (Total EMI Paid)

### 2. Trial Balance Computation
For every active account:
$$\text{Debit Balance} = \sum \text{Debit Entries} - \sum \text{Credit Entries} \quad (\text{if } \text{Normal Balance} = \text{Debit})$$
$$\text{Credit Balance} = \sum \text{Credit Entries} - \sum \text{Debit Entries} \quad (\text{if } \text{Normal Balance} = \text{Credit})$$
Verify: $\sum \text{All Debit Balances} == \sum \text{All Credit Balances}$.

### 3. Same-Date Debit & Credit Consolidation Algorithm
To avoid fragmented rows and presentation bloat in the cash ledger (`backend/services/cashLedger.service.ts` & `lib/screens/reports/cash_ledger_screen.dart`), transactions occurring on the same date for the same entity are consolidated:
```typescript
// Cash Ledger Aggregation Routine
const consolidatedMap = new Map<string, ConsolidatedLedgerRow>();

for (const entry of rawTransactions) {
  const dateKey = entry.transaction_date.toISOString().slice(0, 10);
  if (!consolidatedMap.has(dateKey)) {
    consolidatedMap.set(dateKey, {
      date: dateKey,
      debit: 0,
      credit: 0,
      runningBalance: 0,
      entries: []
    });
  }
  const group = consolidatedMap.get(dateKey)!;
  group.debit += Number(entry.debit_amount || 0);
  group.credit += Number(entry.credit_amount || 0);
  group.entries.push(entry);
}
```
In the UI layer, `_CashLedgerScreenState` renders both Debit (charges) and Credit (paid) columns simultaneously in one row when `tx.debit > 0.009 && tx.credit > 0.009`, preserving exact cumulative running balance invariants.

### 4. Tax-Inclusive Flag Synchronization in Receiving
In `backend/controllers/inventory/receiving.controller.ts` and `lib/models/inventory/receive_item_model.dart`:
- When receiving inventory, `is_tax_inclusive` is extracted directly from the joined `item_master` record:
  $$\text{Net Rate} = \begin{cases} \frac{\text{Purchase Rate}}{1 + \frac{\text{Tax \%}}{100}} & \text{if } \text{is\_tax\_inclusive} = \text{true} \\ \text{Purchase Rate} & \text{if } \text{is\_tax\_inclusive} = \text{false} \end{cases}$$
- The resulting cost basis is posted to `stock_ledger.valuation_rate` and input GST accounts without rounding drift.

---

## 📡 REST API Endpoint Specifications

Mounted under `/api/accounting` and `/api/finance`:

- `GET /api/accounting/coa` — Retrieve hierarchical Chart of Accounts tree.
- `POST /api/accounting/coa` — Create new ledger account.
- `POST /api/accounting/coa/seed` — Seed standard retail/restaurant accounts template.
- `GET /api/accounting/vouchers` — Search vouchers with date, type, and pagination filters.
- `POST /api/accounting/vouchers` — Post balanced double-entry voucher.
- `GET /api/accounting/banks` — List bank accounts with live balances.
- `POST /api/accounting/banks` — Register company bank account.
- `GET /api/accounting/loans-assets` — Retrieve loan profiles and capital assets with amortization schedules.
- `POST /api/accounting/loans` — Register new loan facility with automatic EMI calculation.
- `POST /api/accounting/loans/pay-emi` — Post loan installment with automated principal/interest split.
- `GET /api/reports/trial-balance` — Generate real-time Trial Balance report.
- `GET /api/reports/profit-loss` — Generate period Profit & Loss statement.
- `GET /api/reports/balance-sheet` — Generate certified Balance Sheet.

---

*Document Source: `Docs/Developer-Guide-Accounting-Finance.md`*
