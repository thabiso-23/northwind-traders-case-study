/* 
NORTHWIND TRADERS: B2B SALES & SUPPLY CHAIN OPTIMISATION
Author: Thabiso Letlala
Tool used: PostgreSQL
Description: Comprehensive data extraction and analysis covering sales 
performance, logistics, pricing strategy, and customer retention.
*/

-- 1. TOP PERFORMING SALES REPRESENTATIVES
-- Objective: Identify the top 3 sales representatives based on total revenue.

SELECT
    e.first_name || ' ' || e.last_name AS employee_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::NUMERIC, 2) AS total_revenue
FROM employees e
JOIN orders o ON e.employee_id = o.employee_id
JOIN order_details od ON o.order_id = od.order_id
GROUP BY employee_name
ORDER BY total_revenue DESC
LIMIT 3;


-- 2. SUPPLY CHAIN BOTTLENECKS (LATE SHIPMENTS)
-- Objective: Evaluate shipping vendor performance by counting late deliveries.

SELECT
    s.company_name AS shipper_name,
    COUNT(o.order_id) AS late_deliveries
FROM orders o
JOIN shippers s ON o.ship_via = s.shipper_id
WHERE o.shipped_date > o.required_date
GROUP BY s.company_name
ORDER BY late_deliveries DESC;


-- 3. HIGH-VALUE INVENTORY (WINDOW FUNCTION)
-- Objective: Find the top 2 highest-grossing products within each category.

WITH ProductRevenue AS (
    SELECT
        c.category_name,
        p.product_name,
        ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::NUMERIC, 2) AS product_revenue
    FROM categories c
    JOIN products p ON c.category_id = p.category_id
    JOIN order_details od ON p.product_id = od.product_id
    GROUP BY c.category_name, p.product_name
),
RankedProducts AS (
    SELECT
        category_name,
        product_name,
        product_revenue,
        DENSE_RANK() OVER (PARTITION BY category_name ORDER BY product_revenue DESC) AS revenue_rank
    FROM ProductRevenue
)
SELECT 
    category_name, 
    product_name, 
    product_revenue
FROM RankedProducts
WHERE revenue_rank <= 2;


-- 4. VIP CUSTOMER SEGMENTATION
-- Objective: Identify customers with a lifetime spend exceeding $10,000.

SELECT
    c.company_name,
    c.country,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::NUMERIC, 2) AS lifetime_spend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
GROUP BY c.company_name, c.country
HAVING SUM(od.unit_price * od.quantity * (1 - od.discount)) > 10000
ORDER BY lifetime_spend DESC;


-- 5. MONTH-OVER-MONTH REVENUE GROWTH
-- Objective: Track revenue momentum month-over-month using LAG functions.

WITH MonthlyRevenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS order_month,
        ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::NUMERIC, 2) AS current_month_revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY DATE_TRUNC('month', o.order_date)
),
GrowthCalculation AS (
    SELECT
        order_month,
        current_month_revenue,
        LAG(current_month_revenue) OVER (ORDER BY order_month) AS previous_month_revenue
    FROM MonthlyRevenue
)
SELECT
    order_month,
    current_month_revenue,
    previous_month_revenue,
    ROUND(((current_month_revenue - previous_month_revenue) / previous_month_revenue) * 100, 2) AS mom_growth_percentage
FROM GrowthCalculation
WHERE previous_month_revenue IS NOT NULL
ORDER BY order_month;


-- 6. PRICING STRATEGY: DISCOUNT EFFECTIVENESS
-- Objective: Determine if higher discounts drive larger order quantities.

SELECT 
    CASE 
        WHEN discount = 0 THEN '1. No Discount'
        WHEN discount > 0 AND discount <= 0.10 THEN '2. Low Discount (1-10%)'
        WHEN discount > 0.10 AND discount <= 0.20 THEN '3. Medium Discount (11-20%)'
        ELSE '4. High Discount (>20%)'
    END AS discount_tier,
    COUNT(order_id) AS total_line_items,
    ROUND(AVG(quantity), 2) AS avg_quantity_purchased,
    ROUND(SUM(unit_price * quantity * (1 - discount))::NUMERIC, 2) AS total_revenue
FROM order_details
GROUP BY 
    CASE 
        WHEN discount = 0 THEN '1. No Discount'
        WHEN discount > 0 AND discount <= 0.10 THEN '2. Low Discount (1-10%)'
        WHEN discount > 0.10 AND discount <= 0.20 THEN '3. Medium Discount (11-20%)'
        ELSE '4. High Discount (>20%)'
    END
ORDER BY discount_tier;


-- 7. INVENTORY STOCKOUT RISK
-- Objective: Identify active products critically low on stock requiring immediate reorder.

SELECT 
    p.product_name, 
    s.company_name AS supplier_name, 
    p.units_in_stock, 
    p.units_on_order, 
    p.reorder_level
FROM products p
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE (p.units_in_stock + p.units_on_order) <= p.reorder_level
  AND p.discontinued = 0
ORDER BY p.units_in_stock ASC;


-- 8. CUSTOMER RETENTION & CHURN RISK
-- Objective: Identify customers who have not ordered recently to trigger win-back campaigns.

WITH LastOrderDate AS (
    SELECT MAX(order_date) AS max_date FROM orders
)
SELECT 
    c.company_name,
    MAX(o.order_date) AS last_purchase_date,
    (SELECT max_date FROM LastOrderDate) - MAX(o.order_date) AS days_since_last_purchase,
    CASE 
        WHEN ((SELECT max_date FROM LastOrderDate) - MAX(o.order_date)) <= 90 THEN '1. Active (0-90 days)'
        WHEN ((SELECT max_date FROM LastOrderDate) - MAX(o.order_date)) <= 180 THEN '2. At Risk (91-180 days)'
        ELSE '3. Churned (>180 days)'
    END AS customer_status
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.company_name
ORDER BY days_since_last_purchase DESC;


-- 9. MARKET BASKET ANALYSIS (CROSS-SELLING)
-- Objective: Identify which two products are most frequently purchased together.

SELECT 
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    COUNT(od1.order_id) AS times_bought_together
FROM order_details od1
JOIN order_details od2 ON od1.order_id = od2.order_id AND od1.product_id < od2.product_id
JOIN products p1 ON od1.product_id = p1.product_id
JOIN products p2 ON od2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY times_bought_together DESC
LIMIT 10;


-- 10. FREIGHT COST MARGIN EROSION
-- Objective: Identify orders where shipping costs consume more than 15% of the total order value.

WITH OrderValues AS (
    SELECT 
        o.order_id,
        c.company_name,
        o.freight,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_value
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY o.order_id, c.company_name, o.freight
)
SELECT 
    order_id,
    company_name,
    ROUND(order_value::NUMERIC, 2) AS order_value,
    ROUND(freight::NUMERIC, 2) AS freight_cost,
    ROUND((freight / order_value * 100)::NUMERIC, 2) AS freight_percentage
FROM OrderValues
WHERE order_value > 0 AND (freight / order_value) > 0.15 
ORDER BY freight_percentage DESC;
