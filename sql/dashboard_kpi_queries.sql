-- 1. Main dashboard KPI cards
-- These are the main numbers for the top of the Power BI dashboard.

SELECT
    COUNT(*) AS total_orders,

    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,

    ROUND(SUM(total_payment_value), 2) AS total_payment_value,

    ROUND(AVG(total_payment_value), 2) AS avg_order_value,

    ROUND(AVG(avg_review_score), 2) AS avg_review_score,

    SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,

    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders

FROM analysis_orders_master;

-- Dashboard Use:
-- These values should be used as the main KPI cards at the top of the Power BI dashboard.

-- 2. Delivery KPI cards
-- These are the main delivery performance numbers for the dashboard.

SELECT
    COUNT(*) AS delivered_orders_with_valid_dates,

    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,

    SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END) AS on_time_orders,

    ROUND(
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS late_order_rate,

    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,

    ROUND(AVG(delay_days), 2) AS avg_delay_days,

    ROUND(AVG(CASE WHEN is_late = 1 THEN avg_review_score END), 2) AS avg_late_order_review_score,

    ROUND(AVG(CASE WHEN is_late = 0 THEN avg_review_score END), 2) AS avg_on_time_order_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- 3. Monthly revenue trend
-- Use this for a Power BI line chart.

SELECT
    purchase_year,
    purchase_month,
    purchase_year || '-' || purchase_month AS year_month,

    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
GROUP BY purchase_year, purchase_month
HAVING COUNT(*) >= 100
ORDER BY purchase_year, purchase_month;

-- 4. State revenue performance
-- Best states by orders, revenue, and review score.

SELECT
    customer_state,

    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE customer_state IS NOT NULL
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY total_payment_value DESC;

-- 5. Product category performance
-- Use this for a category revenue and review visual.

SELECT
    cpc.category_name_clean AS product_category,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,

    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price,
    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY cpc.category_name_clean
HAVING COUNT(DISTINCT oi.order_id) >= 100
ORDER BY total_item_revenue DESC;

-- 6. Delay severity and review score
-- Use delay_sort_order in Power BI to sort the delay buckets correctly.

SELECT
    CASE
        WHEN delay_days < -7 THEN 1
        WHEN delay_days >= -7 AND delay_days < 0 THEN 2
        WHEN delay_days = 0 THEN 3
        WHEN delay_days > 0 AND delay_days <= 3 THEN 4
        WHEN delay_days > 3 AND delay_days <= 7 THEN 5
        WHEN delay_days > 7 THEN 6
    END AS delay_sort_order,

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

GROUP BY delay_sort_order, delay_bucket
ORDER BY delay_sort_order;

-- 7. Seller risk table
-- Use this for a dashboard table showing sellers with weak reviews or high late rates.

SELECT
    seller_id,
    seller_city,
    seller_state,
    delivered_orders,
    late_orders,
    late_order_rate,
    total_item_revenue,
    avg_review_score

FROM (
    SELECT
        seller_id,
        seller_city,
        seller_state,

        COUNT(*) AS delivered_orders,
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,

        ROUND(
            SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ) AS late_order_rate,

        ROUND(SUM(order_seller_revenue), 2) AS total_item_revenue,
        ROUND(AVG(avg_review_score), 2) AS avg_review_score

    FROM (
        SELECT
            oi.seller_id,
            s.seller_city,
            s.seller_state,
            oi.order_id,
            aom.is_late,
            aom.avg_review_score,
            SUM(oi.price + oi.freight_value) AS order_seller_revenue

        FROM order_items oi
        LEFT JOIN sellers s
            ON oi.seller_id = s.seller_id

        LEFT JOIN analysis_orders_master aom
            ON oi.order_id = aom.order_id

        WHERE aom.order_status = 'delivered'
          AND aom.order_delivered_customer_date IS NOT NULL

        GROUP BY 
            oi.seller_id,
            s.seller_city,
            s.seller_state,
            oi.order_id,
            aom.is_late,
            aom.avg_review_score
    )

    GROUP BY seller_id, seller_city, seller_state
    HAVING COUNT(*) >= 50
)

WHERE avg_review_score < 3.8
   OR late_order_rate >= 15

ORDER BY total_item_revenue DESC
LIMIT 15;

-- 8. Review group distribution
-- Use this for a dashboard bar or donut chart.

SELECT
    review_group,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage_of_orders

FROM analysis_orders_master
WHERE review_group IS NOT NULL

GROUP BY review_group
ORDER BY total_orders DESC;

-- 9. Order status distribution
-- Use this for a dashboard bar chart showing order completion status.

SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage_of_orders

FROM analysis_orders_master
GROUP BY order_status
ORDER BY total_orders DESC;

-- 10. Payment type distribution
-- Use this for a payment method dashboard chart.

SELECT
    payment_type,

    COUNT(*) AS payment_rows,
    COUNT(DISTINCT order_id) AS unique_orders,

    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS avg_payment_value

FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 11. State delivery performance
-- Use this for a map or state-level delivery risk table.

SELECT
    customer_state,

    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,

    ROUND(
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS late_order_rate,

    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND customer_state IS NOT NULL

GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_order_rate DESC;

-- 12. City delivery risk
-- Use this for a city-level delivery risk table.

SELECT
    customer_state,
    customer_city,

    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) AS late_orders,

    ROUND(
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS late_order_rate,

    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND customer_state IS NOT NULL
  AND customer_city IS NOT NULL

GROUP BY customer_state, customer_city
HAVING COUNT(*) >= 100
ORDER BY late_orders DESC
LIMIT 15;

-- 13. Final executive summary
-- Use this as a quick final dashboard/report summary.

SELECT
    COUNT(*) AS total_orders,

    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,

    ROUND(SUM(total_payment_value), 2) AS total_payment_value,

    ROUND(AVG(total_payment_value), 2) AS avg_order_value,

    ROUND(AVG(avg_review_score), 2) AS avg_review_score,

    SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,

    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,

    ROUND(
        SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END) * 100.0 
        / SUM(CASE WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END),
        2
    ) AS late_order_rate

FROM analysis_orders_master;
