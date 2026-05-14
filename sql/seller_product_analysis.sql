-- 1. Seller performance summary
-- This shows top sellers by item revenue and their review performance.

SELECT
    oi.seller_id,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(DISTINCT oi.product_id) AS unique_products,

    ROUND(SUM(oi.price), 2) AS total_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,

    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY total_item_revenue DESC
LIMIT 15;

-- Finding:
-- Most top revenue sellers have review scores around 4.0 or higher.
-- However, seller 7c67e1448b00f6e969d365cea6b010ab has high item revenue
-- but a low average review score of 3.34.
-- This seller may need further review for product quality, delivery, or service issues.

-- 2. High-revenue sellers with low review scores
-- This finds sellers that generate meaningful revenue but have weaker customer satisfaction.

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(DISTINCT oi.product_id) AS unique_products,

    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,
    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY oi.seller_id, s.seller_city, s.seller_state
HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY avg_review_score ASC, total_item_revenue DESC
LIMIT 15;

-- Finding:
-- Some sellers have meaningful order volume but low review scores.
-- Seller 1ca7077d890b907f89be8c954a02686a has the lowest review score among sellers with 50+ orders.
-- Seller 7c67e1448b00f6e969d365cea6b010ab is a bigger business risk because it has high revenue and high order volume but weak reviews.

-- 3. Seller delivery performance
-- This checks seller delivery performance using one row per seller-order pair.
-- This avoids overcounting orders that have multiple items.

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

    ROUND(AVG(avg_review_score), 2) AS avg_review_score,
    ROUND(SUM(order_seller_revenue), 2) AS total_item_revenue

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
ORDER BY late_order_rate DESC
LIMIT 15;

-- Finding:
-- After correcting for item-level duplication, some sellers still show high late delivery rates.
-- Seller 54965bbe3e4f07ae045b90b0b8541f52 has the highest late rate at 30.14%.
-- Seller 1ca7077d890b907f89be8c954a02686a has both a high late rate and a very low review score.
-- These sellers may need operational review.

-- 4. Combined seller risk view
-- This combines revenue, late delivery rate, and review score.
-- It helps identify sellers that matter financially and may hurt customer experience.

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

-- Finding:
-- The combined seller risk view shows sellers with either low review scores
-- or high late delivery rates.
-- Seller 7c67e1448b00f6e969d365cea6b010ab is the highest business risk
-- because it has the largest revenue among flagged sellers and a weak average review score.
-- Some sellers have acceptable review scores but high late delivery rates,
-- which may become future customer satisfaction risks.


-- 5. Seller and product category performance
-- This shows which product categories each seller is driving.
-- It helps identify whether seller issues are tied to specific product categories.

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    cpc.category_name_clean AS product_category,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,
    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id

LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY 
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    cpc.category_name_clean

HAVING COUNT(DISTINCT oi.order_id) >= 50
ORDER BY total_item_revenue DESC
LIMIT 20;

-- Finding:
-- Seller 7c67e1448b00f6e969d365cea6b010ab generates most of its top revenue
-- from office_furniture.
-- This seller-category pair should be reviewed because office_furniture already showed
-- weaker review performance in earlier category analysis.

-- 6. Risky seller-category pairs
-- This finds seller-category combinations with meaningful order volume
-- but weaker customer review scores.

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    cpc.category_name_clean AS product_category,

    COUNT(*) AS item_rows,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,
    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id

LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id

GROUP BY 
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    cpc.category_name_clean

HAVING COUNT(DISTINCT oi.order_id) >= 50

ORDER BY avg_review_score ASC, total_item_revenue DESC
LIMIT 20;

-- Finding:
-- Risky seller-category pairs show that some issues are tied to specific product categories.
-- The lowest review pair is an Unknown Category seller with an average review score of 1.76.
-- The largest business risk is seller 7c67e1448b00f6e969d365cea6b010ab in office_furniture,
-- because it has high revenue, high order volume, and weak review performance.

-- 7. Final seller and product KPI summary
-- This gives high-level seller and product metrics for the dashboard/report.

SELECT
    COUNT(DISTINCT oi.seller_id) AS active_sellers,
    COUNT(DISTINCT oi.product_id) AS products_sold,
    COUNT(DISTINCT cpc.category_name_clean) AS product_categories,
    COUNT(DISTINCT oi.order_id) AS orders_with_items,

    ROUND(SUM(oi.price), 2) AS total_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_item_revenue,

    ROUND(AVG(cor.avg_review_score), 2) AS avg_review_score

FROM order_items oi
LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id

LEFT JOIN clean_order_reviews cor
    ON oi.order_id = cor.order_id;

-- Final Seller/Product Insight:
-- The marketplace has 3,095 active sellers and 32,951 products sold.
-- Product-level item revenue totals 15,843,553.24 including freight.
-- Most seller/product performance is healthy, but some high-revenue sellers and categories
-- show weaker review scores and should be investigated.
-- Office furniture is a key risk category because it combines strong revenue with lower satisfaction.


