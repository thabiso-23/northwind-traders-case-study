# 🏢 Northwind Traders: B2B Sales & Supply Chain Optimisation
**Author:** Thabiso Letlala | **Location:** Johannesburg, South Africa

## 1. Business Case Study Background
Northwind Traders is a global import/export organisation specialising in B2B food distribution. While the company has experienced steady order volume growth, the executive board has raised concerns regarding stagnating profit margins, customer retention, and supply chain reliability. 

I conducted a data-driven audit of their historical database to investigate operational inefficiencies, evaluate sales team performance, and understand customer purchasing behaviour. The insights derived from this case study aim to pivot the business from reactive operations to proactive, data-informed decision-making.

## 2. Executive Summary & Project Objectives
My objective was to conduct a comprehensive historical audit of the company's database to identify top-performing sales personnel, pinpoint supply chain bottlenecks, and segment high-value VIP customers. 

Rather than just presenting raw data, my goal was to extract actionable business insights to help leadership optimise logistics, refine pricing strategies, and reduce customer churn. I utilised a dual-stack approach: backend data extraction and logic were handled via SQL, while frontend data visualisation was engineered using Python.

## 3. Tech Stack & Tools
* **Database & Querying:** PostgreSQL, DBeaver
* **Data Manipulation & Visualisation:** Python, Pandas, Matplotlib, Seaborn, Jupyter Notebooks (VS Code)
* **Advanced SQL Techniques:** Common Table Expressions (CTEs), Window Functions (`DENSE_RANK`, `LAG`), Aggregations, Conditional Logic (`CASE WHEN`), Self-Joins.

---

## 4. Data Modelling (Database Architecture)
Before diving into the analysis, I exported the relational database schema to visualise the flow of information between employees, customers, product inventory, and shipping vendors. Understanding these relationships dictated the architecture of my `JOIN` clauses throughout the analysis.

*A complete PDF of the Entity Relationship Diagram (ERD) is available in the repository files.
The case study was adapted from the file(s) in this GitHub repository - https://raw.githubusercontent.com/pthom/northwind_psql/master/northwind.sql*

---

## 5. Analytical Process & Business Insights

### 5.1. Identifying the Top-Performing Sales Representatives
**Objective:** Identify the top three revenue drivers on the sales team to inform upcoming bonus structures and training programmes.

**Methodology:** To calculate accurate revenue, I factored the `unit_price` by the `quantity` sold, while applying the specific `discount` for each transaction. I joined the `employees` table to the `orders` table to track attribution, and then joined the `order_details` table to access the line-item financial data.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** Margaret Peacock is our leading sales representative, outperforming the runner-up by nearly $30,000. Leadership should consider analysing her sales tactics to build a targeted training programme for underperforming representatives.

---

### 5.2. Analysing Supply Chain Bottlenecks
**Objective:** Evaluate shipping vendor reliability by identifying which companies are responsible for the highest volume of late shipments.

**Methodology:** I compared the agreed-upon `required_date` against the actual `shipped_date` recorded in the `orders` table. By filtering the data with a `WHERE` clause to only include rows where the shipped date occurred *after* the required date, I isolated the late deliveries and grouped them by vendor.

```sql
SELECT
    s.company_name AS shipper_name,
    COUNT(o.order_id) AS late_deliveries
FROM orders o
JOIN shippers s ON o.ship_via = s.shipper_id
WHERE o.shipped_date > o.required_date
GROUP BY s.company_name
ORDER BY late_deliveries DESC;
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** "Speedy Express" is ironically responsible for our highest number of late deliveries, closely followed by Federal Shipping. United Package is our most reliable vendor. Supply chain leadership should renegotiate SLAs (Service Level Agreements) with the top two offenders or shift more volume to United Package.

---

### 5.3. VIP Customer Segmentation
**Objective:** Segment the customer base to find "VIPs" (defined as clients with a lifetime spend exceeding $10,000) to assist the marketing team with targeted retention campaigns.

**Methodology:** I utilised the `HAVING` clause to filter customers based on their aggregated lifetime revenue, demonstrating the distinction between pre-aggregation filtering (`WHERE`) and post-aggregation filtering.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** A significant portion of our VIP clientele is based in Europe (specifically Germany and Austria, led by QUICK-Stop). Marketing should consider localised loyalty programmes or exclusive corporate events in these regions to maintain high retention.

---

### 5.4. Month-over-Month Revenue Volatility
**Objective:** Calculate historical Month-over-Month (MoM) revenue growth to track company momentum and identify seasonal trends.

**Methodology:** I utilised a Common Table Expression (CTE) to establish baseline monthly revenue. I then applied the `LAG()` window function to look back at the previous month's performance, enabling the calculation of percentage growth or decline.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** Historical data indicates significant volatility, with sharp dips often followed by immediate corrections. Identifying these historical dips allows leadership to anticipate seasonal slumps and adjust operational budgets accordingly before cash flow tightens.

---

### 5.5. Pricing Strategy: Discount Effectiveness
**Objective:** Determine if offering product discounts actually encourages customers to purchase higher quantities per order, or if it unnecessarily erodes profit margins.

**Methodology:** I utilised a `CASE WHEN` statement to bucket individual line items into distinct "Discount Tiers". I then calculated the average quantity purchased within each tier to observe behavioural shifts.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** The data proves that discounting *does* drive volume. Customers purchasing items at a "High Discount" bought an average of 34 units per order, compared to just 21 units when no discount was offered. 

---

### 5.6. Customer Churn & Retention Overview
**Objective:** Categorise the customer base into active and at-risk cohorts based on their most recent purchase date to trigger win-back marketing campaigns.

**Methodology:** I utilised a subquery to establish the date of the most recent order in the entire database (simulating the "current date"). I then calculated the difference in days between that date and each customer's last purchase, categorising them via a `CASE` statement.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** While a strong portion of our base remains active, nearly a quarter of our clients have slipped into the "At Risk" category. Marketing should immediately deploy automated win-back emails offering a targeted discount (which we know drives volume) to re-engage this cohort before they fully churn.

---

### 5.7. Market Basket Analysis (Cross-Selling)
**Objective:** Identify which two products are most frequently purchased together in the exact same order to inform digital cross-selling algorithms.

**Methodology:** I executed a "Self-Join" on the `order_details` table, linking line items that shared an `order_id` but possessed different `product_id`s, aggregating the results to find the most common pairings.

```sql
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
```

<img src="https://github.com/ThabisoLetlala/Northwind_Portfolio/assets/..." width="800">)

💡 **Actionable Insight:** We see strong correlations in specific product pairings (e.g., Sir Rodney's Scones and Sirop d'érable). E-commerce teams should implement an automated "Frequently Bought Together" recommendation widget at checkout featuring these pairs to organically increase Average Order Value (AOV).

---

## 6. Overall Strategic Recommendations
Based on the comprehensive data audit, I recommend the executive board action the following three initiatives:
1. **Supply Chain Optimisation:** Immediately review the SLA with Speedy Express or divert 20% of their current freight volume to United Package to decrease late delivery complaints.
2. **Targeted Retention:** Deploy an automated win-back campaign offering high-tier discounts (>20%) specifically to the 23.6% of the customer base currently categorised as "At Risk".
3. **Sales Enablement:** Institute a mentorship programme pairing Margaret Peacock with bottom-quartile sales representatives to codify and scale her successful conversion tactics.

---

## 7. About the Author
**Thabiso Letlala**  
Data Analyst based in Johannesburg, South Africa.  
Passionate about extracting actionable business insights from complex datasets using SQL, Python, and data visualisation.

**Email:** [rhythmicsecurity@gmail.com](mailto:rhythmicsecurity@gmail.com)
