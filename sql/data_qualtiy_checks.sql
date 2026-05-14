-- DATA QUALITY CHECKS
-- Project: Customer Revenue & Delivery Intelligence Dashboard

-- 1. Check all table names
SELECT name 
FROM sqlite_master
WHERE type = 'table';

-- 2. Count rows in each table
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation;

-- 3. Check order status distribution
SELECT 
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- 4. Check orders with no customer delivery date
SELECT 
    COUNT(*) AS missing_delivery_dates
FROM orders
WHERE order_delivered_customer_date IS NULL;

-- 5. Check review score distribution
SELECT 
    review_score,
    COUNT(*) AS review_count
FROM reviews
GROUP BY review_score
ORDER BY review_score;

-- 6. Check payment type distribution
SELECT 
    payment_type,
    COUNT(*) AS payment_count
FROM payments
GROUP BY payment_type
ORDER BY payment_count DESC;

-- 7. Check missing values in important order date columns

SELECT 
    COUNT(*) AS total_orders,

    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS missing_purchase_date,

    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS missing_approved_date,

    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS missing_carrier_delivery_date,

    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_customer_delivery_date,

    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS missing_estimated_delivery_date

FROM orders;

-- 8. Check missing customer delivery dates by order status
-- This helps us see if missing delivery dates are caused by canceled,
-- unavailable, or incomplete orders.

SELECT 
    order_status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_customer_delivery_date
FROM orders
GROUP BY order_status
ORDER BY missing_customer_delivery_date DESC;

-- 9. Find delivered orders with missing customer delivery date
-- These are data-quality issues because the order says delivered,
-- but the actual customer delivery date is missing.

SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Data Quality Decision:
-- Most missing customer delivery dates are linked to orders that were not completed
-- such as shipped, canceled, unavailable, invoiced, processing, created, or approved.
-- However, 8 delivered orders are missing customer delivery dates.
-- These 8 rows will be excluded from delivery-time calculations.


-- 10. Check duplicate order IDs in the orders table
-- order_id should be unique in the orders table.
-- If total_rows and unique_orders are the same, there are no duplicate order IDs.

SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids
FROM orders;

-- 11. Check duplicate IDs in main dimension tables
-- These ID columns should be unique because each row represents one main record.

SELECT 
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_ids
FROM customers

UNION ALL

SELECT 
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT 
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM sellers;

-- 12. Check duplicate reviews by order_id
-- We want to see if any order has more than one review.

SELECT 
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT order_id) AS unique_reviewed_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_review_orders
FROM reviews;

-- 13. Summarize duplicate reviews
-- This gives us the main numbers without printing hundreds of rows.

SELECT 
    COUNT(*) AS orders_with_multiple_reviews,
    SUM(review_count - 1) AS extra_review_rows,
    MAX(review_count) AS max_reviews_for_one_order
FROM (
    SELECT 
        order_id,
        COUNT(*) AS review_count
    FROM reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
);

-- 14. Preview only the first 20 orders with duplicate reviews
-- LIMIT prevents the output from becoming too large.

SELECT 
    order_id,
    COUNT(*) AS review_count
FROM reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC
LIMIT 20;

-- 15. Check duplicate review IDs
-- review_id should usually be unique.
-- This checks if the same review_id appears more than once.

SELECT 
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(*) - COUNT(DISTINCT review_id) AS duplicate_review_ids
FROM reviews;

-- Data Quality Decision:
-- The reviews table has duplicate review_id values and some orders have multiple reviews.
-- We will not delete raw records.
-- For analysis, we will create a clean review view with one row per order_id.

-- 17. Check payment rows by order
-- One order can have multiple payment rows, so this is not automatically bad.
-- We are checking how common split payments are.

SELECT 
    COUNT(*) AS total_payment_rows,
    COUNT(DISTINCT order_id) AS unique_paid_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS extra_payment_rows
FROM payments;

-- 18. Find orders with no payment record
-- This checks if every order has a matching payment row.

SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp
FROM orders o
LEFT JOIN payments p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- Data Quality Decision:
-- Only 1 order does not have a payment record.
-- Raw data will not be deleted.
-- Revenue analysis will use the payments table, so this order will naturally be excluded from revenue totals.

-- 19. Check how many payment rows each order has
-- This shows split payments or multiple payment records per order.

SELECT 
    payment_row_count,
    COUNT(*) AS number_of_orders
FROM (
    SELECT 
        order_id,
        COUNT(*) AS payment_row_count
    FROM payments
    GROUP BY order_id
)
GROUP BY payment_row_count
ORDER BY payment_row_count;

-- 20. Check payment value quality
-- Payment values should not be missing or negative.

SELECT 
    COUNT(*) AS total_payment_rows,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS missing_payment_value,
    SUM(CASE WHEN payment_value < 0 THEN 1 ELSE 0 END) AS negative_payment_value,
    SUM(CASE WHEN payment_value = 0 THEN 1 ELSE 0 END) AS zero_payment_value,
    ROUND(MIN(payment_value), 2) AS min_payment_value,
    ROUND(MAX(payment_value), 2) AS max_payment_value,
    ROUND(AVG(payment_value), 2) AS avg_payment_value
FROM payments;

-- 21. Inspect zero payment values
-- These payments have value 0, so we check their payment type and order status.

SELECT 
    p.order_id,
    o.order_status,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM payments p
LEFT JOIN orders o
    ON p.order_id = o.order_id
WHERE p.payment_value = 0;

-- Data Quality Decision:
-- There are 9 payment rows with payment_value = 0.
-- Most are voucher payments, and the not_defined payments are linked to canceled orders.
-- These rows will not be deleted because they do not affect revenue totals.

-- 22. Find orders with the highest number of payment rows
-- This helps us inspect split payments or many voucher payments.

SELECT 
    order_id,
    COUNT(*) AS payment_row_count,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments
GROUP BY order_id
ORDER BY payment_row_count DESC
LIMIT 10;

-- 23. Inspect payment details for the order with 29 payment rows
-- This helps us understand why one order has so many payment records.

SELECT 
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM payments
WHERE order_id = 'fa65dad1b0e818e3ccc5cb0e39231352'
ORDER BY payment_sequential;

-- Data Quality Decision:
-- The order with 29 payment rows used multiple voucher payments.
-- This explains the high payment row count.
-- Payments should be summarized by order_id before revenue analysis.

-- 24. Check order_items value quality
-- Price and freight_value should not be missing or negative.

SELECT 
    COUNT(*) AS total_item_rows,

    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS missing_price,
    SUM(CASE WHEN price < 0 THEN 1 ELSE 0 END) AS negative_price,
    SUM(CASE WHEN price = 0 THEN 1 ELSE 0 END) AS zero_price,

    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS missing_freight,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight,
    SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END) AS zero_freight,

    ROUND(MIN(price), 2) AS min_price,
    ROUND(MAX(price), 2) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,

    ROUND(MIN(freight_value), 2) AS min_freight,
    ROUND(MAX(freight_value), 2) AS max_freight,
    ROUND(AVG(freight_value), 2) AS avg_freight

FROM order_items;

-- Data Quality Decision:
-- order_items has no missing, negative, or zero prices.
-- 383 rows have freight_value = 0, which may represent free shipping or promotions.
-- These rows will not be deleted.

-- 25. Check duplicate item records
-- In order_items, one order can have multiple products.
-- The combination of order_id and order_item_id should usually identify each item row.

SELECT 
    COUNT(*) AS total_item_rows,
    COUNT(DISTINCT order_id || '-' || order_item_id) AS unique_order_item_rows,
    COUNT(*) - COUNT(DISTINCT order_id || '-' || order_item_id) AS duplicate_order_item_rows
FROM order_items;

-- Data Quality Decision:
-- order_items has no duplicate order item records.
-- The combination of order_id and order_item_id is unique.
-- This table is safe to use for product and revenue analysis.

-- 26. Check missing product category names
-- Product category is important for category-level revenue analysis.

SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS missing_category_name
FROM products;

-- 27. Check products without English category translation
-- We need English category names for dashboard labels.

SELECT 
    COUNT(*) AS products_without_translation
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name_english IS NULL;


-- 28. Check if missing-category products appear in orders
-- This tells us whether missing product categories affect real sales analysis.

SELECT 
    COUNT(DISTINCT p.product_id) AS missing_category_products,
    COUNT(oi.order_id) AS item_rows_using_missing_category_products,
    ROUND(SUM(oi.price), 2) AS revenue_from_missing_category_products
FROM products p
LEFT JOIN order_items oi
    ON p.product_id = oi.product_id
WHERE p.product_category_name IS NULL;

-- 29. Check order status for missing-category products
-- This shows whether these products were delivered, canceled, etc.

SELECT 
    o.order_status,
    COUNT(*) AS item_count,
    ROUND(SUM(oi.price), 2) AS total_price
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE p.product_category_name IS NULL
GROUP BY o.order_status
ORDER BY item_count DESC;

-- Data Quality Decision:
-- 610 products are missing product_category_name.
-- These products appear in real orders and most are delivered.
-- They generated 1,603 item rows and 179,535.28 in item price revenue.
-- These rows will not be deleted.
-- For category analysis, missing categories will be labeled as 'Unknown Category'.

-- 30. Inspect category names that do not have English translation
-- These categories exist in products but are missing from the translation table.

SELECT 
    p.product_category_name,
    COUNT(*) AS product_count
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name_english IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;

-- 31. Check sales impact of products without English translation
-- This tells us if the missing translations affect revenue analysis.

SELECT 
    p.product_category_name,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(oi.order_id) AS item_rows,
    ROUND(SUM(oi.price), 2) AS total_item_revenue
FROM products p
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name
LEFT JOIN order_items oi
    ON p.product_id = oi.product_id
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name_english IS NULL
GROUP BY p.product_category_name
ORDER BY total_item_revenue DESC;


-- Data Quality Decision:
-- Only 13 products are missing English category translation.
-- These products generated a small amount of revenue.
-- They will not be deleted.
-- For dashboard labels, we will manually translate these two categories.

-- 32. Check missing customer location fields
-- Customer state and city are important for location-based analysis.

SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END) AS missing_customer_city,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS missing_customer_state,
    COUNT(DISTINCT customer_state) AS unique_customer_states
FROM customers;

-- Data Quality Decision:
-- Customer state data is complete.
-- There are 27 unique customer states, which matches Brazil's state/federal district structure.
-- Customer location data is safe for state-level analysis.

-- 33. Check missing seller location fields
-- Seller location is important for delivery and seller performance analysis.

SELECT 
    COUNT(*) AS total_sellers,
    SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END) AS missing_seller_city,
    SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END) AS missing_seller_state,
    COUNT(DISTINCT seller_state) AS unique_seller_states
FROM sellers;

-- Data Quality Decision:
-- Seller city and seller state are complete.
-- There are 23 unique seller states.
-- Seller location data is safe for seller and delivery analysis.