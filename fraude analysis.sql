CREATE DATABASE digital_payments_analytics;
USE digital_payments_analytics;
SELECT *FROM payment_transactions;
-- 1. What share of transactions succeed, fail, pend or reverse? 
SELECT status,
       COUNT(*)                                             AS total,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)   AS pct_total,
       ROUND(SUM(amount_abs))                               AS value
FROM payment_transactions
GROUP BY status
ORDER BY total DESC;

-- Q2. How does each payment channel perform?
-- Volume, completed value, average ticket size, and failure rate
SELECT
    channel,
    COUNT(*) AS total,
    SUM(
        CASE WHEN status = 'SUCCESS' THEN amount_abs
            ELSE 0
        END ) AS completed_value,
ROUND(
        AVG(CASE WHEN status = 'SUCCESS' THEN amount_abs
            END),2) AS avg_ticket_size,

ROUND(100.0 * SUM(CASE WHEN status <> 'SUCCESS' THEN 1
                ELSE 0
            END) / COUNT(*),2) AS failure_rate_pct

FROM payment_transactions
GROUP BY channel
ORDER BY failure_rate_pct DESC;

-- 3 What is the monthly trend and month-over-month growth?       [LAG]
WITH m AS (
  SELECT date , COUNT(*) AS total, SUM(amount_abs) AS value
  FROM payment_transactions
  WHERE status='success' 
  GROUP BY date)
SELECT date, total, ROUND(value) AS value,
       ROUND(100.0 * (total - LAG(total) OVER (ORDER BY date))
                    / LAG(total) OVER (ORDER BY date), 1) AS txn_growth_pct
FROM m ;

-- 4. Why do payments fail?
SELECT failure_reason,
       COUNT(*) AS total_failed,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM payment_transactions
GROUP BY failure_reason
ORDER BY total_failed DESC;

-- Q5. How much busier are salary days (1st, 2nd, 30th, 31st)?

WITH daily AS (
    SELECT DATE(date) AS transaction_date,
        CASE WHEN DAY(date) IN (1, 2, 30, 31)
            THEN 1
            ELSE 0 END AS is_salary_day,
COUNT(*) AS total
    FROM payment_transactions
    WHERE status = 'SUCCESS'
    GROUP BY DATE(date), CASE
            WHEN DAY(date) IN (1, 2, 30, 31)
            THEN 1
            ELSE 0
	 END)
SELECT
    CASE
        WHEN is_salary_day = 1 THEN 'Salary day'
        ELSE 'Other day'
    END AS day_type,

    COUNT(*) AS days,

    ROUND(AVG(total), 0) AS avg_txns_per_day
FROM daily
GROUP BY is_salary_day
ORDER BY is_salary_day DESC;

-- Q6. Which merchants generate the most transaction value?

WITH merchant_value AS (
    SELECT
        merchant_id,
        SUM(amount_abs) AS total_value
    FROM payment_transactions
    WHERE merchant_id <> 'NON_MERCHANT'
      AND status = 'SUCCESS'
    GROUP BY
        merchant_id)

SELECT
    merchant_id,
    ROUND(total_value, 2) AS total_value,
    ROUND(
        100.0 * total_value /
        SUM(total_value) OVER (),
        2
    ) AS share_pct,
    ROUND(
        100.0 *
        SUM(total_value) OVER (
            ORDER BY total_value DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
        / SUM(total_value) OVER (),2) AS cumulative_share_pct
FROM merchant_value
ORDER BY total_value DESC
LIMIT 15;
 
 
-- 7. Which merchant ids have the most failures and refunds?
SELECT
    merchant_id,
    COUNT(*) AS total_transactions,
    ROUND(SUM(CASE WHEN status = 'SUCCESS' THEN amount_abs
                ELSE 0
            END),2) AS completed_value,
    ROUND(100.0 * SUM(CASE WHEN status <> 'SUCCESS' THEN 1
                ELSE 0
            END) / COUNT(*),2) AS failure_rate_pct,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(COALESCE(status, '')) IN
                     ('refund', 'refunded', 'reversal', 'reversed')
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS refund_reversal_rate_pct
    
FROM payment_transactions
WHERE merchant_id <> 'NON_MERCHANT'
GROUP BY merchant_id
ORDER BY completed_value DESC;

-- Q8. How big is the fraud problem by type?

SELECT
    fraud_label,
    COUNT(*) AS fraud_transactions,
    ROUND(SUM(CASE
                WHEN status = 'SUCCESS'
                     AND amount_abs > 0
                THEN amount_abs
                ELSE 0
            END
        ),2) AS successful_value,

    ROUND(100.0 * COUNT(*) /SUM(COUNT(*)) OVER (),
    2) AS pct_of_all_fraud

FROM payment_transactions
WHERE fraud_label IS NOT NULL
  AND fraud_label <> ''
GROUP BY fraud_label
ORDER BY fraud_transactions DESC;

-- Q9. When does fraud happen?

SELECT
    date (timestamp) AS hour_of_day,
    COUNT(*) AS total_transactions,
    SUM(CASE
            WHEN fraud_label IS NOT NULL
                 AND fraud_label <> ''
            THEN 1
            ELSE 0
        END
    ) AS fraud_transactions,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN fraud_label IS NOT NULL
                     AND fraud_label <> ''
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS fraud_rate_pct

FROM payment_transactions
GROUP BY date(timestamp)
ORDER BY fraud_rate_pct DESC;

-- Q11. How much fraud is reported versus not reported?

SELECT
   CASE
        WHEN label_reported IS NULL
             OR label_reported = ''
        THEN 'Not Reported'
        ELSE 'Reported'
    END AS reporting_status,

    COUNT(*) AS fraud_transactions,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM payment_transactions
WHERE fraud_label IS NOT NULL
  AND fraud_label <> ''

GROUP BY
    CASE
        WHEN label_reported IS NULL
             OR label_reported = ''
        THEN 'Not Reported'
        ELSE 'Reported'
    END

ORDER BY fraud_transactions DESC;


-- Q10. 7-day moving average and running total of daily transaction volume

WITH daily AS (

    SELECT
        DATE(date) AS transaction_date,
        COUNT(*) AS total_transactions

    FROM payment_transactions
    WHERE status = 'SUCCESS'
    GROUP BY DATE(date)
)
SELECT
    transaction_date,
    total_transactions,

    ROUND(
        AVG(total_transactions) OVER (
            ORDER BY transaction_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        1
    ) AS moving_avg_7d,

    SUM(total_transactions) OVER (
        ORDER BY transaction_date
    ) AS running_total
FROM daily
ORDER BY transaction_date;

-- Q11. Are there any calendar days with no transaction data?

WITH RECURSIVE date_spine AS (
    SELECT MIN(DATE(date)) AS transaction_date
    FROM payment_transactions
    UNION ALL
    SELECT transaction_date + INTERVAL 1 DAY
    FROM date_spine
    WHERE transaction_date < (
        SELECT MAX(DATE(date))
        FROM payment_transactions
    )
),
daily AS (
    SELECT
        DATE(date) AS transaction_date,
        COUNT(*) AS transactions
    FROM payment_transactions
    GROUP BY DATE(date)
)
SELECT
    COUNT(*) AS days_in_period,
    SUM(
        CASE
            WHEN daily.transactions IS NULL THEN 1
            ELSE 0
        END
    ) AS days_with_no_data
FROM date_spine
LEFT JOIN daily
    ON date_spine.transaction_date = daily.transaction_date;
    
    
    -- Q13. RFM customer segmentation

WITH base AS (
    SELECT
        customer_id,
        DATEDIFF(
            (SELECT MAX(DATE(date)) FROM payment_transactions),
            MAX(DATE(date))
        ) AS recency,
        COUNT(*) AS frequency,
        SUM(amount_abs) AS monetary
    FROM payment_transactions
    WHERE status = 'SUCCESS'
      AND customer_id IS NOT NULL
    GROUP BY customer_id
),
scored AS (
    SELECT
        *,NTILE(5) OVER (ORDER BY recency DESC
        ) AS r_score,
        NTILE(5) OVER (
            ORDER BY frequency
        ) AS f_score,
        NTILE(5) OVER (
		ORDER BY monetary
        ) AS m_score
    FROM base)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4
            THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3
            THEN 'Loyal'
        WHEN r_score <= 2 AND f_score >= 3
            THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2
            THEN 'Hibernating'
        ELSE 'Promising'
    END AS customer_segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_spend,
    ROUND(100.0 * SUM(monetary) /
        SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_share_pct
FROM scored
GROUP BY
    CASE
        WHEN r_score >= 4 AND f_score >= 4
            THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3
            THEN 'Loyal'

        WHEN r_score <= 2 AND f_score >= 3
            THEN 'At Risk'

        WHEN r_score <= 2 AND f_score <= 2
            THEN 'Hibernating'

        ELSE 'Promising'
    END

ORDER BY revenue_share_pct DESC;

-- Q14. Top 3 Merchants by Transaction Value

WITH merchant_value AS (
    SELECT
        merchant_id,
        SUM(amount_abs) AS total_value
    FROM payment_transactions
    WHERE status = 'SUCCESS'
      AND merchant_id IS NOT NULL
      AND merchant_id <> 'NON_MERCHANT'
    GROUP BY merchant_id
),

ranked AS (
    SELECT
        merchant_id,
        total_value,

        DENSE_RANK() OVER (
            ORDER BY total_value DESC
        ) AS merchant_rank

    FROM merchant_value
)

SELECT
    merchant_id,
    merchant_rank,
    ROUND(total_value, 2) AS total_value

FROM ranked
WHERE merchant_rank <= 3
ORDER BY merchant_rank, total_value DESC;

-- 15 city wise 

WITH customer_spend AS (

    SELECT
        cust_id,
        ip_city AS city,
        SUM(amount_abs) AS spend

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND cust_id IS NOT NULL
      AND ip_city IS NOT NULL

    GROUP BY
        cust_id,
        ip_city
),

ranked AS (

    SELECT
        cust_id,
        city,
        spend,

        -- Average customer spending within each city
        AVG(spend) OVER (
            PARTITION BY city
        ) AS city_average,

        -- Rank customers within each city
        RANK() OVER (
            PARTITION BY city
            ORDER BY spend DESC
        ) AS city_rank

    FROM customer_spend
)

SELECT
    city,
    city_rank,
    cust_id,

    ROUND(spend, 2) AS spend,

    ROUND(city_average, 2) AS city_average,

    ROUND(
        spend / NULLIF(city_average, 0),
        2
    ) AS multiple_of_city_average

FROM ranked

WHERE city_rank <= 2

ORDER BY
    city_rank;


-- -- Q16. Which customers transact twice within 60 seconds?

WITH transaction_history AS (

    SELECT
        txn_id,
        cust_id,
        timestamp,
        amount_abs,

        -- Get the previous transaction time for each customer
        LAG(timestamp) OVER (
            PARTITION BY cust_id
            ORDER BY timestamp
        ) AS previous_timestamp

    FROM payment_transactions

    WHERE cust_id IS NOT NULL
),

rapid_transactions AS (

    SELECT
        txn_id,
        cust_id,
        timestamp,
        amount_abs,
        previous_timestamp,

        -- Calculate time difference in seconds
        TIMESTAMPDIFF(
            SECOND,
            previous_timestamp,
            timestamp
        ) AS seconds_since_previous

    FROM transaction_history

    WHERE previous_timestamp IS NOT NULL
)

SELECT
    txn_id,
    cust_id,
    timestamp,
    amount_abs,
    previous_timestamp,
    seconds_since_previous

FROM rapid_transactions

WHERE seconds_since_previous < 60

ORDER BY
    seconds_since_previous ASC,
    cust_id

LIMIT 20;

-- Q17. Potential vishing candidates
-- First payment to a stranger that is >= 5x the customer's historical average


WITH transaction_history AS (

    SELECT
        txn_id,
        cust_id,
        payee_vpa,
        timestamp,
        amount_abs,

        -- Identify the customer's first payment to each payee
        ROW_NUMBER() OVER (
            PARTITION BY cust_id, payee_vpa
            ORDER BY timestamp
        ) AS payment_number,

        -- Calculate the customer's historical average
        -- before the current transaction
        AVG(amount_abs) OVER (
            PARTITION BY cust_id
            ORDER BY timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_average

    FROM payment_transactions

    WHERE cust_id IS NOT NULL
      AND payee_vpa IS NOT NULL
      AND payee_vpa <> 'UNKNOWN'
)

SELECT
    txn_id,
    cust_id,
    payee_vpa,
    timestamp,
    amount_abs,

    ROUND(previous_average, 2) AS previous_average,

    ROUND(
        amount_abs / NULLIF(previous_average, 0),
        2
    ) AS multiple_of_previous_average

FROM transaction_history

WHERE payment_number = 1
  AND amount_abs >= 10000
  AND previous_average > 0
  AND amount_abs >= 5 * previous_average

ORDER BY
    multiple_of_previous_average DESC

LIMIT 10;

-- Q18. Card-testing candidates
-- 5 or more micro-transactions within 30 minutes

WITH card_transactions AS (

    SELECT
        txn_id,
        payer_vpa AS card_identifier,
        timestamp,

        CASE
            WHEN amount_abs <= 10 THEN 1
            ELSE 0
        END AS micro_transaction,

        UNIX_TIMESTAMP(timestamp) AS transaction_seconds

    FROM payment_transactions

    WHERE channel = 'CARD'
      AND payer_vpa IS NOT NULL
),

rolling AS (

    SELECT
        txn_id,
        card_identifier,
        timestamp,
        micro_transaction,

        SUM(micro_transaction) OVER (
            PARTITION BY card_identifier
            ORDER BY transaction_seconds
            RANGE BETWEEN 1800 PRECEDING AND CURRENT ROW
        ) AS micro_transactions_30m

    FROM card_transactions
)

SELECT
    card_identifier,

    COUNT(*) AS flagged_transactions,

    MIN(timestamp) AS first_seen,

    MAX(micro_transactions_30m) AS peak_micro_transactions

FROM rolling

WHERE micro_transactions_30m >= 5

GROUP BY card_identifier

ORDER BY flagged_transactions DESC

LIMIT 10;

-- Q19. Account takeover candidates
-- Transactions occurring within 2 hours of a SIM change

SELECT
    txn_id,
    cust_id,
    timestamp,
    amount_abs,
    device_id,
    sim_change_2h,

    CASE
        WHEN sim_change_2h = 1
        THEN 'SIM change within 2 hours'
        ELSE 'No recent SIM change'
    END AS risk_indicator

FROM payment_transactions

WHERE sim_change_2h = 1
  AND amount_abs >= 1000

ORDER BY timestamp

LIMIT 10;

-- Q20. Mule fan-in
-- Accounts receiving money from 8 or more
-- different payers in one day

SELECT
    payee_vpa,

    DATE(date) AS transaction_date,

    COUNT(DISTINCT payer_vpa) AS distinct_payers,

    ROUND(
        SUM(amount_abs),
        2
    ) AS total_received

FROM payment_transactions

WHERE status = 'SUCCESS'
  AND payee_vpa IS NOT NULL
  AND payee_vpa <> 'UNKNOWN'
  AND payer_vpa IS NOT NULL
  AND payer_vpa <> 'UNKNOWN'

GROUP BY
    payee_vpa,
    DATE(date)

HAVING COUNT(DISTINCT payer_vpa) >= 8

ORDER BY
    distinct_payers DESC,
    total_received DESC;
    
    -- Q21. Mule pass-through
-- An account receives money and sends a similar amount
-- to another account within 60 minutes

WITH incoming AS (

    SELECT
        txn_id AS incoming_txn_id,
        payee_vpa AS account,
        timestamp AS incoming_time,
        amount_abs AS incoming_amount

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND payee_vpa IS NOT NULL
      AND payee_vpa <> 'UNKNOWN'
),

outgoing AS (

    SELECT
        txn_id AS outgoing_txn_id,
        payer_vpa AS account,
        timestamp AS outgoing_time,
        amount_abs AS outgoing_amount

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND payer_vpa IS NOT NULL
      AND payer_vpa <> 'UNKNOWN'
)

SELECT
    o.account,

    COUNT(DISTINCT o.outgoing_txn_id)
        AS pass_through_transactions,

    ROUND(
        SUM(o.outgoing_amount),
        2
    ) AS value_moved

FROM outgoing o

JOIN incoming i
    ON i.account = o.account

    AND i.incoming_time < o.outgoing_time

    AND TIMESTAMPDIFF(
        MINUTE,
        i.incoming_time,
        o.outgoing_time
    ) <= 60

    AND o.outgoing_amount
        BETWEEN
        0.85 * i.incoming_amount
        AND i.incoming_amount

GROUP BY o.account

ORDER BY
    pass_through_transactions DESC

LIMIT 10;

-- Q22. Median successful transaction amount by channel

WITH ranked AS (

    SELECT
        channel,
        amount_abs,

        ROW_NUMBER() OVER (
            PARTITION BY channel
            ORDER BY amount_abs
        ) AS row_num,

        COUNT(*) OVER (
            PARTITION BY channel
        ) AS channel_count

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND amount_abs IS NOT NULL
),

median_values AS (

    SELECT
        channel,
        amount_abs,
        channel_count

    FROM ranked

    WHERE row_num IN (
        FLOOR((channel_count + 1) / 2),
        FLOOR((channel_count + 2) / 2)
    )
)

SELECT
    channel,

    ROUND(
        AVG(amount_abs),
        2
    ) AS median_amount,

    MAX(channel_count) AS total_transactions

FROM median_values

GROUP BY channel

ORDER BY median_amount DESC;

-- Q23. Customer cohort retention

WITH first_seen AS (

    SELECT
        cust_id,

        DATE_FORMAT(
            MIN(DATE(date)),
            '%Y-%m'
        ) AS cohort

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND cust_id IS NOT NULL

    GROUP BY cust_id
),

active AS (

    SELECT DISTINCT
        cust_id,

        DATE_FORMAT(
            DATE(date),
            '%Y-%m'
        ) AS active_month

    FROM payment_transactions

    WHERE status = 'SUCCESS'
      AND cust_id IS NOT NULL
),

cohort_activity AS (

    SELECT
        f.cohort,
        a.active_month,

        COUNT(DISTINCT a.cust_id)
            AS active_customers

    FROM first_seen f

    JOIN active a
        ON f.cust_id = a.cust_id

    GROUP BY
        f.cohort,
        a.active_month
)

SELECT
    cohort,
    active_month,
    active_customers,

    ROUND(
        100.0 * active_customers /
        FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort
            ORDER BY active_month
        ),
        2
    ) AS retention_pct
FROM cohort_activity
ORDER BY
    cohort,
    active_month;
    
    -- Q24. Fraud Rule Engine
-- Creates multiple risk indicators from the available columns

SELECT
    txn_id,
    cust_id,
    timestamp,
    amount_abs,
    channel,
    ip_city,
    device_id,
    fraud_label,

    -- Rule 1: High-value transaction
    CASE
        WHEN amount_abs >= 10000 THEN 1
        ELSE 0
    END AS high_value_flag,

    -- Rule 2: SIM change within 2 hours
    CASE
        WHEN sim_change_2h = 1 THEN 1
        ELSE 0
    END AS sim_change_flag,

    -- Rule 3: Night-time transaction
    CASE
        WHEN is_night = 1 THEN 1
        ELSE 0
    END AS night_transaction_flag,

    -- Rule 4: Micro transaction
    CASE
        WHEN amount_abs <= 10 THEN 1
        ELSE 0
    END AS micro_transaction_flag,

    -- Rule 5: Known fraud label
    CASE
        WHEN fraud_label IS NOT NULL
             AND fraud_label <> ''
        THEN 1
        ELSE 0
    END AS fraud_label_flag,

    -- Overall rule score
    (
        CASE WHEN amount_abs >= 10000 THEN 1 ELSE 0 END
        +
        CASE WHEN sim_change_2h = 1 THEN 1 ELSE 0 END
        +
        CASE WHEN is_night = 1 THEN 1 ELSE 0 END
        +
        CASE WHEN amount_abs <= 10 THEN 1 ELSE 0 END
        +
        CASE
            WHEN fraud_label IS NOT NULL
                 AND fraud_label <> ''
            THEN 1
            ELSE 0
        END
    ) AS risk_score
FROM payment_transactions
ORDER BY risk_score DESC
LIMIT 10;

-- Q25. Fraud rate by channel and amount band

SELECT
    channel,
    amount_band,
    COUNT(*) AS total_transactions,
    SUM(
        CASE
            WHEN fraud_label IS NOT NULL
                 AND fraud_label <> ''
            THEN 1
            ELSE 0
        END
    ) AS fraud_transactions,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN fraud_label IS NOT NULL
                     AND fraud_label <> ''
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS fraud_rate_pct
FROM payment_transactions
WHERE channel IS NOT NULL
  AND amount_band IS NOT NULL
GROUP BY
    channel,
    amount_band
HAVING COUNT(*) >= 50
ORDER BY
    fraud_rate_pct DESC

LIMIT 10;

-- Q26. Fraud rate by hour of day
-- Compared with the overall fraud rate

WITH hourly AS (

    SELECT
        hour AS hour_of_day,

        COUNT(*) AS total_transactions,

        SUM(
            CASE
                WHEN fraud_label IS NOT NULL
                     AND fraud_label <> ''
                THEN 1
                ELSE 0
            END
        ) AS fraud_transactions

    FROM payment_transactions

    GROUP BY hour
)

SELECT
    hour_of_day,
    total_transactions,
    fraud_transactions,
    ROUND(
        100.0 * fraud_transactions
        / NULLIF(total_transactions, 0),
        2
    ) AS fraud_rate_pct,
    ROUND(
        (
            100.0 * fraud_transactions
            / NULLIF(total_transactions, 0)
        )
        -
        (
            100.0 * SUM(fraud_transactions) OVER ()
            / NULLIF(SUM(total_transactions) OVER (), 0)
        ),
        2
    ) AS vs_overall_percentage_points
FROM hourly
ORDER BY hour_of_day;

-- Q27. Fraud rate by IP city

SELECT
    ip_city AS city,
    COUNT(*) AS total_transactions,
    SUM(
        CASE
            WHEN fraud_label IS NOT NULL
                 AND fraud_label <> ''
            THEN 1
            ELSE 0
        END
    ) AS fraud_transactions,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN fraud_label IS NOT NULL
                     AND fraud_label <> ''
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS fraud_rate_pct
FROM payment_transactions
WHERE ip_city IS NOT NULL
  AND ip_city <> 'UNKNOWN'
GROUP BY ip_city
HAVING COUNT(*) >= 20
ORDER BY fraud_rate_pct DESC;

-- Q28. Merchants ranked by refund/reversal ratio

WITH merchant_stats AS (
    SELECT
        merchant_id,
        COUNT(*) AS total_transactions,
        SUM(
            CASE
                WHEN LOWER(COALESCE(status, ''))
                     IN (
                         'REFUND',
                         'REFUNDED',
                         'REVERSAL',
                         'REVERSED'
                     )
                THEN 1
                ELSE 0
            END
        ) AS refund_reversal_transactions
    FROM payment_transactions
    WHERE merchant_id IS NOT NULL
      AND merchant_id <> 'NON_MERCHANT'
    GROUP BY merchant_id
    HAVING COUNT(*) >= 20
),
ranked AS (
    SELECT
        merchant_id,
        total_transactions,
        refund_reversal_transactions,

        ROUND(
            100.0 *
            refund_reversal_transactions
            / NULLIF(total_transactions, 0),
            2
        ) AS refund_rate_pct,
        RANK() OVER (
            ORDER BY
                refund_reversal_transactions
                / NULLIF(total_transactions, 0) DESC
        ) AS risk_rank
    FROM merchant_stats
)
SELECT
    merchant_id,
    total_transactions,
    refund_reversal_transactions,
    refund_rate_pct,
    risk_rank
    FROM ranked
ORDER BY risk_rank
LIMIT 15;

-- Q29. Customer Behaviour Baseline
-- Typical amount, typical hour, usual device and usual city

WITH successful_transactions AS (
    SELECT
        cust_id,
        amount_abs,
        hour AS transaction_hour,
        device_id,
        ip_city
    FROM payment_transactions
    WHERE status = 'SUCCESS'
      AND cust_id IS NOT NULL
),
amount_stats AS (
    SELECT
        cust_id,
        COUNT(*) AS total_transactions,
        ROUND(
            AVG(amount_abs),2) AS average_amount,
        ROUND(
            MAX(amount_abs),
            2
        ) AS maximum_amount
    FROM successful_transactions
    GROUP BY cust_id
),
hour_ranked AS (
    SELECT
        cust_id,
        transaction_hour,
        ROW_NUMBER() OVER (
            PARTITION BY cust_id
            ORDER BY COUNT(*) DESC, transaction_hour
        ) AS ranking
    FROM successful_transactions
    GROUP BY
        cust_id,
        transaction_hour
),
device_ranked AS (
    SELECT
        cust_id,
        device_id,
        ROW_NUMBER() OVER (
            PARTITION BY cust_id
            ORDER BY COUNT(*) DESC
        ) AS ranking
    FROM successful_transactions
    WHERE device_id IS NOT NULL
      AND device_id <> 'UNKNOWN'
    GROUP BY
        cust_id,
        device_id
),
city_ranked AS (
    SELECT
        cust_id,
        ip_city,
        ROW_NUMBER() OVER (
            PARTITION BY cust_id
            ORDER BY COUNT(*) DESC
        ) AS ranking
    FROM successful_transactions
    WHERE ip_city IS NOT NULL
      AND ip_city <> 'UNKNOWN'
    GROUP BY
        cust_id,
        ip_city
)
SELECT
    a.cust_id,
    a.total_transactions,
    a.average_amount,
    a.maximum_amount,
    h.transaction_hour AS typical_hour,
    d.device_id AS usual_device,
    c.ip_city AS usual_city
FROM amount_stats a
LEFT JOIN hour_ranked h
    ON a.cust_id = h.cust_id
    AND h.ranking = 1
LEFT JOIN device_ranked d
    ON a.cust_id = d.cust_id
    AND d.ranking = 1
LEFT JOIN city_ranked c
    ON a.cust_id = c.cust_id
    AND c.ranking = 1
ORDER BY
    a.total_transactions DESC
LIMIT 10;