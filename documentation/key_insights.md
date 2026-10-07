# Key Insights

Each insight follows the same format: **finding → evidence → why it matters → action**. Numbers come from the SQL question bank (`sql/fraud_sql_question_bank.sql`) and the Python cleaning pipeline. The data is synthetic, so treat the *method* as the takeaway and the exact numbers as illustrations.

## Top 5 at a glance

| # | Insight | Number |
|---|---|---|
| 1 | Fraud is heavily concentrated at night | 6.2% vs 1.0% (6.4×) |
| 2 | Large UPI payments are the riskiest combination | 74.6% fraud above ₹10k |
| 3 | Two fraud types drive customer loss | Vishing + takeover ≈ 82% of ₹78 lakh |
| 4 | Three merchants stand out on refunds | 34–44% vs 5.7% next-worst |
| 5 | Raw fraud labels are unreliable | 44.5% of true fraud unlabelled or mislabelled |

---

## A. Size and shape of the problem

### A1. Fraud is 1.56% of transactions but unevenly spread
- **Evidence:** 953 fraud transactions across 7 types: mule hops 219, refund abuse 209, card testing 185, account takeover 177, mule fan-in 73, vishing 60, collect scam 30 (Q9).
- **Why it matters:** The types behave differently and need different controls.
- **Action:** Treat each type with its own rule instead of one generic score.

### A2. Customer loss is about ₹78 lakh, and it is concentrated
- **Evidence:** Vishing ₹32.4 lakh, account takeover ₹31.1 lakh, mule fan-in ₹8.0 lakh, collect scam ₹4.1 lakh, card testing ₹2.4 lakh (Q9).
- **Why it matters:** Together vishing and takeover make up about 82% of loss.
- **Action:** Prioritise controls for these two first.

### A3. Gross fraud value overstates the loss
- **Evidence:** Gross value is ₹108 lakh. About ₹30 lakh of that is mule-hop and refund-abuse payments, where the same stolen money moves again or merchants abuse incentives.
- **Why it matters:** Reporting ₹108 lakh as "customer loss" would inflate the business case by about 39%.
- **Action:** Always report customer loss and gross value separately.

---

## B. Timing, channel, amount, and place

### B1. Night-time carries about 6× the fraud rate
- **Evidence:** 6.22% from 22:00 to 05:59 vs 0.97% in the day; about 26.5% around 4 AM (Q10, Q28).
- **Why it matters:** Account takeover and card testing cluster at night, when customers are asleep and not watching alerts.
- **Action:** Step-up verification and lower limits for large payments at night.

### B2. UPI payments above ₹10k are the riskiest segment
- **Evidence:** 74.6% of UPI payments above ₹10k are fraud (Q27).
- **Why it matters:** A narrow rule on one channel and one amount band catches a large share of loss with little friction for everyday payments.
- **Action:** Review or cap first-time large UPI payments.

### B3. IP-city mismatch is a strong location signal
- **Evidence:** Fraud rate is 12.78% when the IP city differs from the customer's home city vs 0.73% when it matches (Q29b).
- **Why it matters:** Takeover attacks often come through VPNs and foreign locations.
- **Action:** Use mismatch as one input to a risk score.
- **Caution:** Fraud rate by home city (Q29a) varies between cities, but this is random in the synthetic data. Do not read it as "some cities are riskier".

### B4. Fraud contaminates operational metrics
- **Evidence:** Card failure rate is 6.13%, but it drops to 4.74% once card-testing is excluded.
- **Why it matters:** Operations could chase a payments-infrastructure problem that is really a bot attack.
- **Action:** Report failure rates with and without flagged fraud.

### B5. Salary days are 75% busier
- **Evidence:** About 1,004 completed transactions per day on the 1st, 2nd, 30th, and 31st vs 572 on other days (Q6).
- **Why it matters:** Alert volumes and manual-review capacity must scale with it, and a normal spike must not be mistaken for an attack.
- **Action:** Plan staffing and alert thresholds around salary days.

---

## C. Merchants and customers

### C1. Three merchants have abnormal refund behaviour
- **Evidence:** Refund/reversal ratios of 43.8%, 37.3%, and 33.9% vs 5.7% for the next-worst merchant (Q30). All three are gift-card or gaming merchants onboarded recently.
- **Why it matters:** This pattern is consistent with collusion or incentive abuse.
- **Action:** Enhanced due diligence for new gift-card and gaming merchants, and an automatic alert when refund ratio passes 15%.

### C2. Revenue is concentrated in few merchants
- **Evidence:** The top 10% of merchants carry about 52% of completed value (Q7).
- **Why it matters:** Problems at a handful of merchants have an outsized business impact.
- **Action:** Monitor top merchants more closely.

### C3. Customers can be compared to their own history
- **Evidence:** A vishing payment is typically 25× or more a customer's own average (Q18); a baseline of typical amount, hour, device, and city is available per customer (Q31).
- **Why it matters:** "Unusual for this customer" is a stronger signal than "large in absolute terms".
- **Action:** Build per-customer baselines into real-time scoring.

---

## D. Detection performance

### D1. Six simple rules catch most fraud
- **Evidence:** The SQL engine flags 891 transactions, all fraud (0 false positives), for 93.5% recall (Q24b). The Python version, with a slightly narrower pass-through check, reaches 91.4% recall.
- **Why it matters:** Explainable rules give a strong starting point before any machine-learning model.
- **Action:** Deploy the rules in monitoring mode first, then tune.

### D2. Card testing and vishing are the gaps
- **Evidence:** Recall of about 78% for card testing and about 80% for vishing (Python rules).
- **Why:** The velocity window needs several charges before it fires, so the first micro-charges slip through. A customer's first transaction has no history to compare against.
- **Action:** Add faster velocity checks and a rule for brand-new accounts.

### D3. Data quality changed the fraud result
- **Evidence:** Recovering missing payee IDs removed all 7 false positives (precision 99.2% → 100%).
- **Why it matters:** Missing data made merchant payments look like transfers to strangers.
- **Action:** Treat data completeness as part of fraud-control quality.

---

## E. Labels and complaints

### E1. Fraud labels in the raw data cannot be trusted
- **Evidence:** Of true fraud, 55.5% carries a fraud label, 38.8% is unlabelled, and 5.7% is wrongly marked not-fraud (Q11).
- **Why it matters:** A report based on labels alone would understate fraud by almost half, and any model trained on them would learn from wrong answers.
- **Action:** Invest in labelling (chargebacks, investigator reviews) before building a model.

### E2. Many victims do not file a fraud complaint
- **Evidence:** Of 211 victims, 117 have a fraud-related complaint and 94 do not. Of those 94, 60 filed no ticket at all (Q25 and follow-up check).
- **Why it matters:** Complaint-based detection is slow and incomplete. The rules caught 88 of the 94 without a fraud-related complaint.
- **Action:** Proactive outreach to customers the rules flag, not only those who complain.
- **Caveat:** The fraud-related complaint flag comes from keyword matching, which missed about a third of fraud-linked tickets that had a transaction reference (37 of 110). Some of the 94 may therefore have complained.

---

## F. How far to trust these insights

- The dataset is **synthetic**. Fraud patterns were injected, so detection numbers are optimistic. Real data adds look-alike behaviour such as legitimate person-to-person transfers.
- Rule **thresholds were tuned on the same data** used to evaluate them. A real project would tune on one period and test on another.
- The **fraud rate (1.56%) is inflated** to provide enough examples. Real rates are typically 0.1–0.5%.
- Complaint timestamps are not linked to transaction times, so time-to-complaint is not analysed.
