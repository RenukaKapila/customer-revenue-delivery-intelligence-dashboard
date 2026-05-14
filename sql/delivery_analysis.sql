-- 1. Delivery performance summary
-- This shows how many delivered orders were late vs on time.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END) AS on_time_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate
FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- Finding:
-- Out of 96,470 delivered orders with valid delivery dates,
-- 7,826 were delivered late.
-- The late delivery rate is 8.11%.

-- 2. Compare review scores for late vs on-time deliveries
-- This shows whether late delivery is connected to lower customer satisfaction.

SELECT
    CASE 
        WHEN is_late = 1 THEN 'Late'
        WHEN is_late = 0 THEN 'On Time'
    END AS delivery_status,

    COUNT(*) AS total_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND avg_review_score IS NOT NULL
GROUP BY is_late
ORDER BY avg_review_score;

-- Finding:
-- Late deliveries have much lower average review scores than on-time deliveries.
-- Late orders average 2.57 stars, while on-time orders average 4.29 stars.
-- This suggests delivery performance is a major driver of customer satisfaction.

-- 3. Review group breakdown by delivery status
-- This shows whether late orders are more likely to receive low reviews.
-- Counts can be misleading because on-time orders are much larger.
-- This shows the percentage of each review group within Late and On Time orders.

SELECT
    delivery_status,
    review_group,
    total_orders,
    ROUND(total_orders * 100.0 / SUM(total_orders) OVER (PARTITION BY delivery_status), 2) AS percentage_within_delivery_status
FROM (
    SELECT
        CASE 
            WHEN is_late = 1 THEN 'Late'
            WHEN is_late = 0 THEN 'On Time'
        END AS delivery_status,

        review_group,
        COUNT(*) AS total_orders

    FROM analysis_orders_master
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND avg_review_score IS NOT NULL
    GROUP BY is_late, review_group
)
ORDER BY delivery_status, percentage_within_delivery_status DESC;

-- Finding:
-- Late deliveries are much more likely to receive low reviews.
-- 53.99% of late delivered orders received low reviews,
-- compared to only 9.19% of on-time delivered orders.
-- On-time delivery is strongly connected to high customer satisfaction.

-- 5. Average delay days by delivery status
-- This shows how many days late or early orders are on average.

SELECT
    CASE 
        WHEN is_late = 1 THEN 'Late'
        WHEN is_late = 0 THEN 'On Time'
    END AS delivery_status,

    COUNT(*) AS total_orders,
    ROUND(AVG(delay_days), 2) AS avg_delay_days,
    ROUND(MIN(delay_days), 2) AS min_delay_days,
    ROUND(MAX(delay_days), 2) AS max_delay_days,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND delay_days IS NOT NULL
  AND avg_review_score IS NOT NULL
GROUP BY is_late
ORDER BY avg_delay_days DESC;

-- Finding:
-- Late orders were delivered an average of 9.45 days after the estimated delivery date.
-- On-time orders were delivered an average of 13.01 days before the estimated delivery date.
-- Late deliveries had much lower review scores than on-time deliveries.

-- 6. Delay severity and review score
-- This groups orders by how early or late they were.
-- Uses decimal-safe ranges so no rows fall into NULL.

SELECT
    CASE
        WHEN delay_days < -7 THEN 'More than 7 Days Early'
        WHEN delay_days >= -7 AND delay_days < 0 THEN '1 to 7 Days Early'
        WHEN delay_days = 0 THEN 'Delivered On Estimated Date'
        WHEN delay_days > 0 AND delay_days <= 3 THEN '1 to 3 Days Late'
        WHEN delay_days > 3 AND delay_days <= 7 THEN '4 to 7 Days Late'
        WHEN delay_days > 7 THEN 'More than 7 Days Late'
    END AS delay_bucket,

    COUNT(*) AS total_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND delay_days IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY delay_bucket
ORDER BY avg_review_score DESC;

-- Finding:
-- Review scores decrease as delivery delays become more severe.
-- Orders delivered more than 7 days early average 4.32 stars.
-- Orders delivered 1 to 3 days late drop to 3.76 stars.
-- Orders delivered more than 7 days late drop sharply to 1.73 stars.
-- This shows that delay severity has a strong negative impact on customer satisfaction.

-- 7. Late delivery rate by customer state
-- This shows which customer states have the highest late delivery rates.

SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND customer_state IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_order_rate DESC;

-- Finding:
-- Some states have much higher late delivery rates than the overall average of 8.11%.
-- AL, MA, PI, CE, and SE show the highest late delivery rates.
-- However, average review scores remain around 3.8 to 4.0 because most orders are still delivered on time.

-- 8. States with the highest number of late orders
-- This helps identify where delivery issues affect the most customers.

SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND customer_state IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY customer_state
ORDER BY late_orders DESC
LIMIT 10;

-- Finding:
-- SP and RJ have the highest number of late orders.
-- SP has a lower late rate than many states, but because it has the largest order volume,
-- it still creates the biggest number of late delivery cases.
-- This shows that both late rate and late order volume are important for operations decisions.

-- 9. Cities with the highest number of late orders
-- This shows which customer cities have the largest delivery issue volume.

SELECT
    customer_state,
    customer_city,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND customer_state IS NOT NULL
  AND customer_city IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY customer_state, customer_city
HAVING COUNT(*) >= 100
ORDER BY late_orders DESC
LIMIT 15;

-- 10. Late order review score by city
-- This shows how customers rated only the late deliveries.

SELECT
    customer_state,
    customer_city,
    COUNT(*) AS late_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_late_order_review_score,
    ROUND(AVG(delay_days), 2) AS avg_delay_days

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND is_late = 1
  AND customer_state IS NOT NULL
  AND customer_city IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY customer_state, customer_city
HAVING COUNT(*) >= 50
ORDER BY late_orders DESC
LIMIT 15;

-- 12. Clean monthly late delivery trend
-- This removes very small months so the trend is more reliable.

SELECT
    purchase_year,
    purchase_month,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND purchase_year IS NOT NULL
  AND purchase_month IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY purchase_year, purchase_month
HAVING COUNT(*) >= 100
ORDER BY purchase_year, purchase_month;

-- Finding:
-- Late delivery rates changed over time.
-- The highest late delivery spikes happened in 2017-11, 2018-02, and 2018-03.
-- March 2018 had the highest late delivery rate at 21.06%.
-- These months should be investigated for operational issues, seasonal demand, or logistics delays.

-- 13. Worst months by late delivery rate
-- This highlights the months with the biggest delivery problems.

SELECT
    purchase_year,
    purchase_month,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND avg_review_score IS NOT NULL

GROUP BY purchase_year, purchase_month
HAVING COUNT(*) >= 100
ORDER BY late_order_rate DESC
LIMIT 10;

-- Finding:
-- The worst delivery months are spread across different periods.
-- This suggests delivery delays were not caused by only one isolated month.
-- The business should investigate recurring operational, logistics, or seasonal issues.

-- 14. Final delivery KPI summary
-- This gives the main delivery metrics for dashboard/report use.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END) AS on_time_orders,

    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,

    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(delay_days), 2) AS avg_delay_days,

    ROUND(AVG(avg_review_score), 2) AS overall_avg_review_score,

    ROUND(AVG(CASE WHEN is_late = 1 THEN avg_review_score END), 2) AS avg_late_order_review_score,
    ROUND(AVG(CASE WHEN is_late = 0 THEN avg_review_score END), 2) AS avg_on_time_order_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND avg_review_score IS NOT NULL;

-- 14. Final delivery KPI summary
-- This gives the main delivery metrics for dashboard/report use.
-- AVG ignores NULL review scores automatically.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,
    SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END) AS on_time_orders,

    ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS late_order_rate,

    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(delay_days), 2) AS avg_delay_days,

    ROUND(AVG(avg_review_score), 2) AS overall_avg_review_score,

    ROUND(AVG(CASE WHEN is_late = 1 THEN avg_review_score END), 2) AS avg_late_order_review_score,
    ROUND(AVG(CASE WHEN is_late = 0 THEN avg_review_score END), 2) AS avg_on_time_order_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- Final Delivery Insight:
-- Delivery performance has a strong relationship with customer satisfaction.
-- Late deliveries average much lower review scores than on-time deliveries.
-- Delay severity also matters: reviews drop sharply as orders become more late.
-- The biggest operational impact appears in high-volume states and cities.