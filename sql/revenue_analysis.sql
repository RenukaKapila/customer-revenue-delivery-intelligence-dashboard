-- 1. Revenue KPI summary
-- This gives the main revenue numbers for the business.

SELECT
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,
    ROUND(SUM(total_payment_value), 2) AS total_revenue,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(MIN(total_payment_value), 2) AS min_order_value,
    ROUND(MAX(total_payment_value), 2) AS max_order_value

FROM analysis_orders_master;

-- Finding:
-- The dataset contains 99,441 total orders and 99,440 paid orders.
-- Total payment revenue is 16,008,872.12.
-- The average order value is 160.99.
-- Only one order is missing payment data.

-- 2. Revenue by order status
-- This shows how revenue is distributed across delivered, canceled, shipped, and other order statuses.

SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,
    ROUND(SUM(total_payment_value), 2) AS total_revenue,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value

FROM analysis_orders_master
GROUP BY order_status
ORDER BY total_revenue DESC;

-- Finding:
-- Delivered orders account for most payment value.
-- However, some payment value is linked to canceled, unavailable, shipped, and processing orders.
-- Since refund data is not available, this project will use the term "payment value"
-- instead of assuming all payments are final earned revenue.

-- 3. Delivered order revenue summary
-- This focuses only on completed delivered orders.

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(total_payment_value), 2) AS delivered_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_delivered_order_value,
    ROUND(MIN(total_payment_value), 2) AS min_delivered_order_value,
    ROUND(MAX(total_payment_value), 2) AS max_delivered_order_value

FROM analysis_orders_master
WHERE order_status = 'delivered'
  AND total_payment_value IS NOT NULL;

-- Finding:
-- Delivered orders generated 15,422,461.77 in payment value.
-- The average delivered order value is 159.86.
-- One delivered order has no payment record, so delivered paid orders are 96,477.

-- 4. Monthly payment value trend
-- This shows how payment value changed over time.

SELECT
    purchase_year,
    purchase_month,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
GROUP BY purchase_year, purchase_month
HAVING COUNT(*) >= 100
ORDER BY purchase_year, purchase_month;

-- Finding:
-- Monthly payment value increased over time.
-- Revenue became much stronger in late 2017 and throughout 2018.
-- November 2017 and March-May 2018 were among the highest revenue months.

-- 5. Top 10 months by payment value
-- This highlights the strongest revenue months.

SELECT
    purchase_year,
    purchase_month,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
GROUP BY purchase_year, purchase_month
HAVING COUNT(*) >= 100
ORDER BY total_payment_value DESC
LIMIT 10;

-- Finding:
-- November 2017 had the highest payment value.
-- March, April, and May 2018 were also very strong revenue months.
-- Revenue growth appears strongest from late 2017 into 2018.

-- 6. Payment value by customer state
-- This shows which customer states generate the most payment value.

SELECT
    customer_state,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
  AND customer_state IS NOT NULL

GROUP BY customer_state
ORDER BY total_payment_value DESC;

-- Finding:
-- SP generates the highest total payment value because it has the largest order volume.
-- However, some smaller states have higher average order values.
-- This shows that high revenue can come from volume, while high order value can come from smaller but more expensive purchases.

-- 7. Top states by average order value
-- This shows where customers spend more per order on average.
-- We use HAVING COUNT(*) >= 100 to avoid tiny states giving misleading averages.

SELECT
    customer_state,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
  AND customer_state IS NOT NULL

GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY avg_order_value DESC;

-- Finding:
-- PB, RO, AL, PA, and TO have the highest average order values.
-- SP has the highest total payment value, but its average order value is lower.
-- This shows that large markets drive revenue through volume, while smaller markets may have higher-value orders.

-- 8. Payment value by review group
-- This shows whether low, neutral, or high review orders generate different payment value.

SELECT
    review_group,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
  AND review_group IS NOT NULL

GROUP BY review_group
ORDER BY total_payment_value DESC;

-- 8. Payment value by review group
-- This shows whether low, neutral, or high review orders generate different payment value.

SELECT
    review_group,
    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
  AND review_group IS NOT NULL

GROUP BY review_group
ORDER BY total_payment_value DESC;

-- Finding:
-- High-review orders generate the largest total payment value.
-- However, low-review orders have a higher average order value than high-review orders.
-- This means dissatisfied customers can still represent financially important orders.

-- 9. Payment value by delivery status
-- This shows how payment value compares between late and on-time delivered orders.

SELECT
    CASE
        WHEN is_late = 1 THEN 'Late'
        WHEN is_late = 0 THEN 'On Time'
        ELSE 'Not Delivered / Unknown'
    END AS delivery_status,

    COUNT(*) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master
WHERE total_payment_value IS NOT NULL
  AND order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL

GROUP BY delivery_status
ORDER BY total_payment_value DESC;

-- Finding:
-- Late delivered orders have a higher average order value than on-time orders.
-- However, late orders have much lower review scores.
-- This means delivery problems may be affecting financially valuable customers.

-- 10. Top product categories by item revenue
-- This shows which product categories generate the most item-level revenue.
-- We use order_items because product category exists at the item/product level.

SELECT
    cpc.category_name_clean AS product_category,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,

    ROUND(SUM(oi.price), 2) AS total_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,

    ROUND(AVG(oi.price), 2) AS avg_item_price,
    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY cpc.category_name_clean
ORDER BY total_item_revenue DESC
LIMIT 15;

-- Finding:
-- Health beauty, watches gifts, bed bath table, sports leisure, and computers accessories
-- generate the highest item-level revenue.
-- Most top revenue categories have review scores around 4.0 or higher.
-- Office furniture stands out with a lower average review score of 3.49.

-- 11. High revenue categories with lower review scores
-- This finds categories that make good money but may have customer satisfaction issues.

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
ORDER BY avg_review_score ASC, total_item_revenue DESC
LIMIT 15;

-- Finding:
-- Office furniture is the clearest risk category because it has strong revenue
-- but the lowest average review score among categories with 100+ orders.
-- Unknown Category also has meaningful revenue, so missing category labels should be improved.


-- 12. High revenue categories with strong review scores
-- This finds categories that perform well financially and have good customer satisfaction.

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
ORDER BY avg_review_score DESC, total_item_revenue DESC
LIMIT 15;

-- Finding:
-- Books categories have the highest review scores, but smaller revenue.
-- Cool stuff, toys, perfumery, and stationery are stronger business categories
-- because they combine meaningful revenue with good customer satisfaction.

-- 13. Payment value by payment type
-- This shows which payment methods contribute the most payment value.

SELECT
    payment_type,
    COUNT(*) AS payment_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS avg_payment_value

FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- Finding:
-- Credit card is the dominant payment method by both payment rows and total payment value.
-- Boleto is the second-largest payment method.
-- Voucher payments have a lower average value because they are often used in smaller split payments.

-- 14. Final revenue KPI summary
-- This gives the main revenue metrics for dashboard/report use.

SELECT
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN total_payment_value IS NOT NULL THEN 1 END) AS paid_orders,

    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS avg_order_value,

    ROUND(SUM(CASE WHEN order_status = 'delivered' THEN total_payment_value ELSE 0 END), 2) AS delivered_payment_value,

    ROUND(AVG(CASE WHEN order_status = 'delivered' THEN total_payment_value END), 2) AS avg_delivered_order_value,

    ROUND(AVG(avg_review_score), 2) AS avg_review_score

FROM analysis_orders_master;

-- Final Revenue Insight:
-- The marketplace generated 16,008,872.12 in total payment value.
-- Delivered orders account for most of the payment value.
-- Credit card is the dominant payment method.
-- SP is the highest revenue state due to order volume.
-- Some smaller states have higher average order values.
-- High-review orders generate the most total payment value,
-- but low-review orders have higher average order value, meaning dissatisfied customers can still be financially important.
