# Digital-Payments-Fraud-Transaction-Customer-Intelligence-Platform
An end-to-end analytics project on a digital payments dataset (UPI, card, wallet). It takes deliberately messy raw data through cleaning, SQL analysis, and a rule-based fraud detection engine, and finishes with business recommendations.


## Key results

| Metric | Result |
|---|---|
| Raw transactions → clean | 62,292 → **60,953** (1,219 duplicates and 120 sandbox rows removed) |
| Duplicate customers merged | 5,340 → **5,040** (300 merged) |
| Fraud in the data | **953 transactions (1.56%)** across 7 fraud types |
| Customer loss from fraud | **≈ ₹78 lakh** (₹108 lakh gross, including double-counted mule hops) |
| Rule engine (SQL) | **891 flagged, 0 false positives, 93.5% recall** |
| Share of true fraud missing a fraud label in raw data | **44.5%** (38.8% unlabelled, 5.7% wrongly marked not-fraud) |
| Fraud victims who never complained | **94 of 211**, 88 of whom the rules still caught |

---

## Business problem

A payments company loses money to fraud, but blocking genuine customers also costs revenue and trust. This project answers six questions:

1. How big is the fraud problem, by count, by value, and by type?
2. When, where, and through which channels does fraud happen?
3. Which customer and merchant segments carry the most risk?
4. What signals separate fraud from legitimate behaviour?
5. How many frauds can we catch, and how many genuine customers do we annoy?
6. What should the business do next?

---

## Dataset

Generated with `scripts/generate_fraud_data.py` (seeded, reproducible), Jul–Sep 2026.

| File | Rows | Contents |
|---|---|---|
| `transactions_raw.csv` | 62,292 | UPI, card, wallet, netbanking, and UPI-collect payments |
| `customers_raw.csv` | 5,340 | KYC records, including duplicate people |
| `merchants_raw.csv` | 303 | Merchants (3 fake ones hidden among them) |
| `device_logs_raw.csv` | 30,401 | Logins, SIM changes, PIN resets, beneficiary additions |
| `complaints_raw.csv` | 1,527 | Free-text tickets (English and Hinglish) |
| `ground_truth_labels.csv` | 953 | Answer key, used **only for evaluation** |

**Fraud patterns injected:** account takeover (SIM swap → emulator login → drain), vishing/OTP scams, card testing, mule rings (fan-in → hops → cash-out), UPI collect scams, and refund abuse through fake merchants.

---

## Approach

flowchart LR
    A[Raw CSVs] --> B[Python: profile and clean]
    B --> C[Null recovery and feature columns]
    C --> D[(SQLite: 6 tables)]
    D --> E[SQL analysis: 31 questions]
    D --> F[SQL rule engine]
    F --> G[Evaluation vs answer key]
    D --> H[Power BI dashboard]
    E --> I[Insights and recommendations]
  

### 1. Data cleaning (Python / pandas)

| Problem | Fix |
|---|---|
| 5 timestamp formats; ~20% were UTC | Parsed each format; converted UTC to IST |
| Amounts like `Rs. 1,499.00`, `₹49999`, `INR 463` | Stripped symbols; converted to numeric; added `amount_abs` for reversals |
| Status and channel spelled many ways | Mapped to canonical values |
| `NULL`, `N/A`, `unknown`, blank | Converted to real nulls at load |
| Exact duplicates and `TEST-` / `SANDBOX` rows | Removed |
| Same person under several IDs | Matched on normalised 10-digit phone; merged records |
| 2,469 transactions missing `cust_id` | Recovered via UPI ID and device ownership → **25 left** |
| 615 missing `payee_vpa` | Recovered from `merchant_id` → **12 left** |
| Missing values with no source to recover from | Labelled explicitly (`UNKNOWN`, `NOT_APPLICABLE`) and flagged; birthdays and labels left empty rather than invented |

**Design decisions worth noting**
- Unknown fraud labels stay empty. A blank label is *unknown*, not "not fraud".
- A missing device is **not** filled with the customer's usual device, because that would hide account takeover.
- Placeholders live only in the `*_final` tables, so fraud rules never treat "UNKNOWN" as a real account.
- Fixing nulls changed the fraud result: it eliminated all 7 false positives, which came from missing payee IDs that made merchant payments look like transfers to strangers.

### 2. SQL analysis (31 queries)
Business questions, written as queries, with window functions (`LAG`, `NTILE`, `DENSE_RANK`, `FIRST_VALUE`, running sums, `RANGE` windows on epoch time), recursive CTEs, time-window self-joins, and anti-joins. See [`sql/fraud_sql_question_bank.sql`](sql/fraud_sql_question_bank.sql).

### 3. Rule-based fraud detection

| Rule | Logic | Targets |
|---|---|---|
| R1 | Payment ≥ ₹1,000 within 2 h of a SIM change | Account takeover |
| R2 | UPI, first payment to a stranger, ≥ ₹10k and ≥ 5× the customer's own average | Vishing / OTP scam |
| R3 | ≥ 5 charges ≤ ₹10 within 30 min on a card | Card testing |
| R4 | ≥ 8 payers into one personal account in a day, or 85–100% forwarded within 60 min | Mule rings |
| R5 | UPI-collect request to a non-merchant, ≥ ₹1,000 | Collect scam |
| R6 | Merchant with ≥ 15% refund/reversal ratio | Refund abuse |

Thresholds were chosen by inspecting the data (the three fake merchants sit at 34–44% refunds; the next real merchant is at 5.7%).



## Key insights

- **Fraud is concentrated at night.** The fraud rate is **6.2% between 22:00 and 06:00 vs 1.0% in the day (6.4×)**, peaking at 26.5% around 4 AM.
- **Large UPI payments are the riskiest combination.** UPI payments above ₹10k are **74.6% fraud**.
- **Location mismatch is a strong signal.** When the payment's IP city differs from the customer's home city, the fraud rate is **12.8% vs 0.7%**. (City alone is not predictive.)
- **Two fraud types drive customer loss.** Vishing (₹32.4 lakh) and account takeover (₹31.1 lakh) account for most customer loss. Mule hops are the same money moving again, so summing them would overstate losses by about ₹30 lakh.
- **Three merchants stand out.** Gift-card and gaming merchants with **34–44% refund ratios** vs 5.7% for the next-worst merchant.
- **Fraud inflates operational KPIs.** The card failure rate is 6.1%, but 1.4 points of that is card-testing bots, not a payments fault.
- **Salary days are +75% busier** (about 1,004 vs 572 transactions per day), which matters for alert capacity.
- **Revenue is concentrated.** The top 10% of merchants carry 52% of completed value.
- **Labels cannot be trusted alone.** Only 55.5% of true fraud carries a fraud label in the raw data.
- **Complaints are a lagging, incomplete signal.** 94 of 211 victims never complained; the rules caught 88 of them anyway.

### Rule engine performance

| Fraud type | Recall (Python rules) | Note |
|---|---|---|
| Collect scam | 100% | |
| Refund abuse | 100% | |
| Mule fan-in | 98.6% | |
| Account takeover | 98.3% | |
| Mule hops | 88% | Window too short for slow hops |
| Vishing | 80% | A customer's first transaction has no history to compare to |
| Card testing | 78% | The first 4 micro-charges slip through before the window fills |

The SQL version of the mule rule is slightly broader, which lifts overall recall to **93.5%** (91.4% in Python) at 0 false positives.

---

## Dashboard (Power BI)


| Page | Purpose |
|---|---|
| [Transaction Overview]| KPIs: volume, fraud rate, customer loss, rule precision and recall |
|[Fraud & Risk Monitoring]  | Fraud by type, hour × channel heatmap, flagged transactions|
| [Customer & Merchant Intelligence] | RFM segments, merchant refund ranking |
|[Behavioral & Geographic Analysis]  | Daily/hourly volume, channel mix, failures, citys |

![Executive overview](docs/images/dashboard_overview.png)



## Recommendations

1. **Step-up verification for large night-time payments**, since the 22:00–06:00 window carries 6× the fraud rate.
2. **Cooling-off limit after a SIM change** (for example, cap payments for 24 hours).
3. **Review or cap a first payment to a new payee above ₹10k.**
4. **Velocity limits on cards** (for example, block after 5 micro-charges in 30 minutes).
5. **Enhanced due diligence for new gift-card and gaming merchants**, and an automatic refund-ratio alert at 15%.
6. **Proactive outreach to likely victims** the rules flag but who haven't complained.
7. **Improve fraud labelling**: 44.5% of true fraud is unlabelled or mislabelled, which will limit any future model.



