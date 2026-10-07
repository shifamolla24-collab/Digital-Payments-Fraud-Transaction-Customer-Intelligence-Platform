# Data Dictionary

Describes the six tables in `fraud.db` (SQLite), built by `scripts/build_all.py` from the raw CSVs. Cleaned CSV versions are in `data/clean/` as `*_final.csv`.

## Conventions

| Topic | Rule |
|---|---|
| Time zone | All timestamps are **IST**. UTC and epoch values in the raw data were converted. |
| Currency | Indian rupees (₹). 1 lakh = 100,000. |
| Date format | Text in ISO format: `YYYY-MM-DD` and `YYYY-MM-DD HH:MM:SS`. |
| Booleans | Stored as `0` / `1`. |
| IDs | Uppercase text. VPAs and device IDs are lowercase. |
| Period covered | 2026-07-01 to 2026-09-30. |
| Reference date | Ages and account ages use 2026-10-01 or 2026-07-01 as stated in the column. |

### How missing values are represented

| Value | Meaning |
|---|---|
| `UNKNOWN` | Could not be recovered from any other data. |
| `NOT_APPLICABLE` | Not meaningful for this row (for example, a SIM change has no device). |
| `NON_MERCHANT` | Person-to-person payment, no merchant involved. |
| `NOT_PROVIDED` | The customer or system did not provide it (email, transaction reference). |
| Empty (NULL) | Deliberately left empty: `dob`, `age`, `label_reported`, `account_age_days`. Values are never invented. |

### Relationships

| From | To | Join |
|---|---|---|
| `transactions.cust_id` | `customers.cust_id` | Many-to-one |
| `transactions.merchant_id` | `merchants.merchant_id` | Many-to-one (`NON_MERCHANT` has no match) |
| `device_logs.cust_id` | `customers.cust_id` | Many-to-one |
| `complaints.cust_id` | `customers.cust_id` | Many-to-one |
| `complaints.txn_ref` | `transactions.txn_id` | Many-to-one (when provided) |
| `ground_truth.txn_id` | `transactions.txn_id` | One-to-one |

---

## Table: `transactions` (60,953 rows)

One row per payment attempt.

| Column | Type | Description |
|---|---|---|
| `txn_id` | text | Unique transaction ID (uppercase). |
| `timestamp` | text | Transaction time, IST. |
| `amount` | real | Signed amount in ₹. Some reversals and refunds are negative. |
| `amount_abs` | real | Absolute amount. **Use this for sums.** |
| `cust_id` | text | Customer ID after duplicate merging. `UNKNOWN` if unrecoverable (25 rows). |
| `payer_vpa` | text | Paying account: UPI ID, card token (`card-xxxx####`), or `wallet:<phone>`. |
| `payee_vpa` | text | Receiving UPI ID. `UNKNOWN` if missing (12 rows). |
| `merchant_id` | text | Merchant ID, or `NON_MERCHANT` for person-to-person payments. |
| `channel` | text | `UPI`, `CARD`, `WALLET`, `NETBANKING`, `UPI_COLLECT`. |
| `status` | text | `SUCCESS`, `FAILED`, `PENDING`, `REVERSED`, `REFUNDED`. |
| `failure_reason` | text | Reason for a failed payment (for example `Timeout`, `Wrong Pin`). `Not applicable` if not failed; `Unknown` if failed with no reason. |
| `device_id` | text | Device used (lowercase). Emulators start with `emu-`. `UNKNOWN` if missing. |
| `ip_city` | text | City of the payment's IP address. `UNKNOWN` if missing. |
| `label_reported` | real | Fraud label from the raw data: 1 = fraud, 0 = not fraud. **Empty means unknown, not 0.** |
| `date` | text | Transaction date. |
| `hour` | integer | Hour of day, 0–23, IST. |
| `dow` | text | Day of week name. |
| `is_night` | integer | 1 if hour is 22–05. |
| `amount_band` | text | `<=100`, `100-500`, `500-2k`, `2k-10k`, `>10k`. |
| `cust_id_missing` | integer | 1 if customer could not be identified even after recovery. |
| `payee_missing` | integer | 1 if payee could not be identified even after recovery. |
| `device_missing` | integer | 1 if device ID was missing in the source. |
| `ip_city_missing` | integer | 1 if IP city was missing in the source. |
| `label_status` | text | `FRAUD_REPORTED`, `NOT_FRAUD_REPORTED`, `UNLABELLED`. |
| `year_month` | text | `YYYY-MM`. |
| `week_start` | text | Monday of the transaction's week. |
| `is_weekend` | integer | 1 for Saturday and Sunday. |
| `is_salary_day` | integer | 1 on the 1st, 2nd, 30th, and 31st. |
| `time_of_day` | text | `Night` (22–05), `Morning` (06–11), `Afternoon` (12–16), `Evening` (17–21). |
| `is_success` | integer | 1 if status is `SUCCESS`. |
| `is_failed` | integer | 1 if status is `FAILED`. |
| `is_refund_or_reversal` | integer | 1 if status is `REFUNDED` or `REVERSED`. |
| `payee_type` | text | `MERCHANT` or `PERSON_OR_OTHER`. |
| `merchant_name` | text | Merchant name, or `Non-merchant`. |
| `merchant_category` | text | Merchant category (copied from `merchants.category`), or `Non-merchant`. |
| `cust_home_city` | text | Customer's home city. `UNKNOWN` if not available. |
| `ip_city_mismatch` | integer | 1 if `ip_city` differs from `cust_home_city` (both known). |
| `account_age_days` | real | Days between account opening and the transaction. Empty if customer unknown. |

---

## Table: `customers` (5,040 rows)

One row per real person (duplicate records merged using the normalised phone number).

| Column | Type | Description |
|---|---|---|
| `cust_id` | text | Customer ID (the oldest ID of any merged duplicates). |
| `full_name` | text | Name in title case. |
| `phone10` | integer | 10-digit mobile number (matching key for duplicate detection). |
| `email` | text | Email, or `NOT_PROVIDED`. |
| `dob` | text | Date of birth. Empty if unknown. |
| `city` | text | Standardised city. `Unknown` if none. |
| `kyc` | text | KYC level: `full`, `min`, `pending`. |
| `open_date` | text | Account opening date. |
| `upi_vpa` | text | Customer's UPI ID. `UNKNOWN` if none. |
| `city_source` | text | `provided`, `inferred_from_logins`, or `unknown`. |
| `age` | real | Age in years at 2026-10-01. Empty if `dob` missing. |
| `age_band` | text | `18-25`, `26-35`, `36-45`, `46-55`, `56-65`, `65+`, `Unknown`. |
| `dob_missing` | integer | 1 if date of birth is missing. |
| `has_email` | integer | 1 if an email was provided. |
| `account_age_at_start_days` | integer | Days between account opening and 2026-07-01. |
| `is_new_account` | integer | 1 if the account was 30 days old or less on 2026-07-01. |

---

## Table: `merchants` (303 rows)

| Column | Type | Description |
|---|---|---|
| `merchant_id` | text | Merchant ID (`M####`). |
| `merchant_name` | text | Merchant name in title case. |
| `category` | text | `Food`, `Grocery`, `Fuel`, `Telecom`, `Utilities`, `Ecommerce`, `Travel`, `Gaming`, `Gift Cards`. |
| `city` | text | Merchant city. |
| `vpa` | text | Merchant UPI ID. |
| `onboarding_date` | text | Date the merchant was onboarded. |
| `risk_tier` | text | `low`, `medium`, `high`, or `unrated`. |
| `age_at_start_days` | integer | Days between onboarding and 2026-07-01. |
| `is_new_merchant` | integer | 1 if onboarded fewer than 60 days before 2026-07-01. |

---

## Table: `device_logs` (30,401 rows)

Login and security events.

| Column | Type | Description |
|---|---|---|
| `log_id` | text | Unique event ID. |
| `cust_id` | text | Customer ID. `UNKNOWN` if unrecoverable (87 rows). |
| `timestamp` | text | Event time, IST. |
| `event_type` | text | `login_success`, `login_failed`, `otp_requested`, `app_open`, `sim_change`, `pin_reset`, `beneficiary_added`. |
| `device_id` | text | Device used. `NOT_APPLICABLE` for SIM changes; `UNKNOWN` if missing. |
| `device_model` | text | Device model (emulators show as `Android SDK built for x86` or `Generic Emulator`). |
| `ip_address` | text | IP address. |
| `ip_city` | text | City of the IP (VPN exits appear as foreign cities). |
| `is_vpn` | integer | 1 if the login came through a VPN. |
| `os_clean` | text | Operating system, for example `Android 13`, `iOS 17`. |
| `date` | text | Event date. |
| `hour` | integer | Event hour, IST. |
| `is_night` | integer | 1 if hour is 22–05. |
| `is_sim_change` | integer | 1 if the event is a SIM change. |

---

## Table: `complaints` (1,527 rows)

Customer support tickets.

| Column | Type | Description |
|---|---|---|
| `ticket_id` | text | Ticket ID. |
| `created_at` | text | Ticket creation time, IST. |
| `cust_id` | text | Customer ID. `UNKNOWN` if unresolved. |
| `txn_ref` | text | Referenced transaction ID, or `NOT_PROVIDED`. |
| `channel` | text | `app_chat`, `call_center`, `email`, `twitter`, `branch`. |
| `status` | text | `open`, `closed`, `resolved`, `reopened`, `in_progress`. |
| `priority` | text | `low`, `medium`, `high`, `unassigned`. |
| `text` | text | Complaint text, lowercased (English and Hinglish). |
| `phone10` | integer | Customer's 10-digit phone, used to recover missing `cust_id`. |
| `is_fraud_complaint` | integer | 1 if keyword matching flags it as fraud-related. Imperfect; it misses some tickets. |
| `created_date` | text | Ticket creation date. |
| `has_txn_ref` | integer | 1 if a transaction reference was provided. |
| `complaint_category` | text | `Fraud / scam` or `Service issue`. |

---

## Table: `ground_truth` (953 rows)

The answer key, used **only to evaluate** detection rules. It must never be used as an input feature. A transaction that does not appear here is legitimate.

| Column | Type | Description |
|---|---|---|
| `txn_id` | text | Fraudulent transaction ID. |
| `fraud_type` | text | `account_takeover`, `vishing_otp`, `card_testing`, `mule_fanin`, `mule_hop`, `collect_scam`, `refund_abuse_collusion`. |

| Fraud type | Description |
|---|---|
| `account_takeover` | SIM swap, new emulator device, new payees, account drained. |
| `vishing_otp` | Customer tricked into authorising a large payment to a stranger. |
| `card_testing` | Bursts of tiny charges, then a large one. |
| `mule_fanin` | Victims paying into a mule account. |
| `mule_hop` | Stolen money forwarded through mule accounts to cash-out. |
| `collect_scam` | Customer tricked into approving a UPI collect request. |
| `refund_abuse_collusion` | Payments and refunds cycling through fake merchants. |
