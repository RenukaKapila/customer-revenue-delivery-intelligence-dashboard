-- 1. Clean order reviews
-- Raw reviews has duplicate review_id values and some orders have multiple reviews.
-- This view creates one review row per order_id.

DROP VIEW IF EXISTS clean_order_reviews;

CREATE VIEW clean_order_reviews AS
SELECT 
    order_id,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS review_count,
    MIN(review_creation_date) AS first_review_date,
    MAX(review_answer_timestamp) AS last_review_answer_date
FROM reviews
GROUP BY order_id;


-- Check clean review view
SELECT 
    COUNT(*) AS clean_review_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM clean_order_reviews;

-- 2. Clean order payments
-- Raw payments has multiple rows for some orders.
-- This view creates one payment row per order_id.

DROP VIEW IF EXISTS clean_order_payments;

CREATE VIEW clean_order_payments AS
SELECT 
    order_id,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    COUNT(*) AS payment_row_count,
    COUNT(DISTINCT payment_type) AS payment_type_count,
    MAX(payment_installments) AS max_installments
FROM payments
GROUP BY order_id;

-- Check clean payment view
SELECT 
    COUNT(*) AS clean_payment_rows,
    COUNT(DISTINCT order_id) AS unique_paid_orders,
    ROUND(SUM(total_payment_value), 2) AS total_revenue
FROM clean_order_payments;

-- 3. Clean product categories
-- This view creates clean English category labels for dashboard and analysis.
-- Missing categories become 'Unknown Category'.
-- Two untranslated categories are manually translated.

DROP VIEW IF EXISTS clean_product_categories;

CREATE VIEW clean_product_categories AS
SELECT 
    p.product_id,

    CASE 
        WHEN p.product_category_name IS NULL THEN 'Unknown Category'
        WHEN p.product_category_name = 'pc_gamer' THEN 'PC Gamer'
        WHEN p.product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos' 
            THEN 'Portable Kitchen & Food Prep'
        ELSE ct.product_category_name_english
    END AS category_name_clean,

    p.product_category_name AS original_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm

FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name;

-- Check clean product category view
SELECT 
    COUNT(*) AS clean_product_rows,
    COUNT(DISTINCT product_id) AS unique_products,
    SUM(CASE WHEN category_name_clean IS NULL THEN 1 ELSE 0 END) AS missing_clean_category
FROM clean_product_categories;

-- 4. Clean order items
-- Raw order_items has multiple rows per order because one order can contain multiple products.
-- This view creates one item summary row per order_id.

DROP VIEW IF EXISTS clean_order_items;

CREATE VIEW clean_order_items AS
SELECT 
    oi.order_id,

    COUNT(*) AS item_row_count,
    COUNT(DISTINCT oi.product_id) AS unique_product_count,
    COUNT(DISTINCT oi.seller_id) AS unique_seller_count,

    ROUND(SUM(oi.price), 2) AS total_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_item_value,

    GROUP_CONCAT(DISTINCT cpc.category_name_clean) AS product_categories

FROM order_items oi
LEFT JOIN clean_product_categories cpc
    ON oi.product_id = cpc.product_id
GROUP BY oi.order_id;

-- Check clean order items view
SELECT 
    COUNT(*) AS clean_order_item_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    ROUND(SUM(total_item_price), 2) AS total_item_revenue,
    ROUND(SUM(total_freight_value), 2) AS total_freight_revenue
FROM clean_order_items;

-- 5. Master order analysis view
-- This combines clean order, review, payment, item, and customer data.
-- This will be the main table for analysis, dashboard, and Python later.

DROP VIEW IF EXISTS analysis_orders_master;

CREATE VIEW analysis_orders_master AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,

    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    c.customer_city,
    c.customer_state,

    strftime('%Y', o.order_purchase_timestamp) AS purchase_year,
    strftime('%m', o.order_purchase_timestamp) AS purchase_month,

    -- Delivery calculations
    ROUND(julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp), 2) AS delivery_days,

    ROUND(julianday(o.order_estimated_delivery_date) - julianday(o.order_purchase_timestamp), 2) AS estimated_delivery_days,

    ROUND(julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date), 2) AS delay_days,

    CASE 
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN julianday(o.order_delivered_customer_date) > julianday(o.order_estimated_delivery_date) THEN 1
        ELSE 0
    END AS is_late,

    -- Review data
    cor.avg_review_score,
    cor.review_count,

    CASE
        WHEN cor.avg_review_score IS NULL THEN 'No Review'
        WHEN cor.avg_review_score <= 2 THEN 'Low Review'
        WHEN cor.avg_review_score = 3 THEN 'Neutral Review'
        ELSE 'High Review'
    END AS review_group,

    -- Payment data
    cop.total_payment_value,
    cop.payment_row_count,
    cop.payment_type_count,
    cop.max_installments,

    -- Item data
    coi.item_row_count,
    coi.unique_product_count,
    coi.unique_seller_count,
    coi.total_item_price,
    coi.total_freight_value,
    coi.total_order_item_value,
    coi.product_categories

FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id

LEFT JOIN clean_order_reviews cor
    ON o.order_id = cor.order_id

LEFT JOIN clean_order_payments cop
    ON o.order_id = cop.order_id

LEFT JOIN clean_order_items coi
    ON o.order_id = coi.order_id;

-- Check master analysis view
SELECT 
    COUNT(*) AS master_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_revenue,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score
FROM analysis_orders_master;