# Business Questions

This project supports decisions at a digital payments company that loses money to fraud, but also loses revenue and trust when it blocks genuine customers. Everything in the repository exists to answer the six questions below.

## Overview

| # | Business question | Why it matters | Answered by |
|---|---|---|---|
| 1 | How big is the fraud problem, by count, by value, and by type? | Sizes the problem and sets priorities | SQL Q9, Q11, Q2 |
| 2 | When, where, and through which channels does fraud happen? | Tells us where to add controls | SQL Q10, Q27, Q28, Q29, Q3, Q6 |
| 3 | Which customer and merchant segments carry the most risk? | Lets us focus review effort on a small group | SQL Q30, Q8, Q7, Q15, Q14, Q16, Q23 |
| 4 | What signals separate fraud from legitimate behaviour? | These are the building blocks of every detection rule | SQL Q17–Q21, Q22, Q31 |
| 5 | How many frauds can we catch, and how many genuine customers do we annoy? | The core trade-off for the business | SQL Q24a–c, Q25 |
| 6 | What should the business do next? | Turns analysis into action | Synthesis of 1–5 (see `key_insights.md`) |

---

## 1. How big is the fraud problem, by count, by value, and by type?

**Why it matters:** A control only makes sense if the loss it prevents is larger than its cost. Count shows how often fraud happens, value shows how much it costs, and type shows what to fix.

**Analysis:** Join the answer key (`ground_truth`) to the transactions and group by fraud type. Separate customer loss from "gross fraud value" so the same stolen money is not counted twice as it moves between mule accounts.

**Headline answer:**
- 953 fraud transactions out of 60,953 (1.56%), across 7 fraud types.
- Customer loss is about ₹78 lakh. Vishing (₹32.4 lakh) and account takeover (₹31.1 lakh) make up most of it.
- Gross fraud value is ₹108 lakh, but ₹30 lakh of that is mule hops and refund-abuse payments, which are not customer loss.
- 38.8% of true fraud has no label in the raw data, and another 5.7% is wrongly labelled not-fraud.

**Decision supported:** Where to invest first (vishing and account takeover), and why a label-only view of fraud would understate the problem.

---

## 2. When, where, and through which channels does fraud happen?

**Why it matters:** Controls such as step-up verification or limits cost friction. They should only apply where the risk is high.

**Analysis:** Fraud rate by hour, time of day, channel × amount band, city, and IP-city mismatch. Normal behaviour (channel performance, salary-day load) is shown for comparison.

**Headline answer:**
- **Time:** 6.2% fraud rate from 22:00 to 06:00 vs 1.0% in the day (6.4×). It peaks around 4 AM at 26.5%.
- **Channel and amount:** UPI payments above ₹10k are 74.6% fraud.
- **Place:** IP city differing from the customer's home city gives 12.8% fraud vs 0.7%. Home city alone is not predictive.
- **Load:** Salary days are 75% busier, so alert capacity must scale.

**Decision supported:** Night-time step-up verification, review of large UPI payments, geo-mismatch checks.

---

## 3. Which customer and merchant segments carry the most risk?

**Why it matters:** Fraud is concentrated. Finding the risky pockets lets a small team cover a large share of the loss.

**Analysis:** Merchant refund/reversal ratio ranking, category performance, revenue concentration, RFM customer segments, top spenders per city, and cohort retention.

**Headline answer:**
- Three gift-card and gaming merchants have refund ratios of 34–44%. The next-worst merchant is at 5.7%.
- The top 10% of merchants carry 52% of completed value.
- Customer risk is better explained by behaviour (device, timing, payee) than by segment. See question 4.

**Decision supported:** Enhanced due diligence on new gift-card and gaming merchants, and an automatic alert on refund ratio.

---

## 4. What signals separate fraud from legitimate behaviour?

**Why it matters:** A good signal appears often in fraud and rarely in normal activity. These become the detection rules.

**Analysis:** Each fraud type has a signature that is translated into SQL.

| Signal | Fraud type |
|---|---|
| Payments soon after a SIM change, from a new or emulator device | Account takeover |
| First payment to a stranger, large and ≥ 5× the customer's own average | Vishing / OTP scam |
| Many tiny card charges in a short window | Card testing |
| Many payers into one account, then quick forwarding | Mule rings |
| Collect request to a non-merchant | Collect scam |
| High refund/reversal ratio at a merchant | Refund abuse |

Each customer's own "normal" (typical amount, hour, device, city) is the baseline these signals are measured against.

**Decision supported:** Which rules to deploy, and which data (device, SIM events, payee history) must be available in real time.

---

## 5. How many frauds can we catch, and how many genuine customers do we annoy?

**Why it matters:** Catching more fraud usually means blocking more genuine payments. The business needs both numbers.

**Analysis:** Run the six rules, compare them to the answer key, and report precision (how many flags are real), recall (how much fraud is caught), and what is missed.

**Headline answer:**
- The SQL rule engine flags 891 transactions, all of them real fraud (0 false positives), for 93.5% recall.
- The weakest areas are card testing and vishing (about 78–80% recall).
- Of 211 fraud victims, the rules caught 198, including 88 who filed no fraud-related complaint.

**Decision supported:** Whether the rules are good enough to deploy, and which gaps to close first.

**Caveat:** The zero false positives reflect this synthetic dataset, which has no ambiguous look-alike behaviour. Real data would show a lower precision.

---

## 6. What should the business do next?

**Why it matters:** Analysis only has value if it changes a decision.

**Recommended actions (detail in `key_insights.md`):**
1. Step-up verification for large night-time payments.
2. A cooling-off limit after a SIM change.
3. Review or cap a first payment to a new payee above ₹10k.
4. Card velocity limits on micro-charges.
5. Enhanced due diligence on new gift-card and gaming merchants, with a refund-ratio alert.
6. Proactive outreach to victims the rules flag who have not complained.
7. Better fraud labelling, which is a prerequisite for any future machine-learning model.
