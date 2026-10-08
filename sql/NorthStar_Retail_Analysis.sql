/* ============================================================
   NORTHSTAR RETAIL - SALES & PROFITABILITY ANALYSIS
   ============================================================

   Business Problem:
   NorthStar Retail generates sales across multiple products,
   categories, regions, and customer segments, but management
   needs better visibility into which areas are driving profit
   and which are underperforming.

   The business also wants to understand whether discounting
   is associated with weaker profitability.

   Business Questions:
   1. Where are sales and profit strongest or weakest?
   2. Which categories, regions, or customer segments are
      underperforming?
   3. Are discounts associated with lower profitability?

   Tools:
   SQL Server / SSMS
   ============================================================ */


-- ============================================================
-- 1. DATABASE SETUP & INITIAL DATA PREVIEW
-- ============================================================

USE NorthStarRetail;


-- Preview the first 10 rows to confirm the data imported correctly.
SELECT TOP 10 *
FROM dbo.clean_data;



-- ============================================================
-- 2. DATA VALIDATION & QUALITY CHECKS
-- ============================================================


-- ------------------------------------------------------------
-- 2.1 Dataset Size
-- ------------------------------------------------------------
-- Count total rows and unique customer orders.
-- One order may contain multiple product-line records.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Order_ID) AS total_orders
FROM dbo.clean_data;



-- ------------------------------------------------------------
-- 2.2 Missing Value Check
-- ------------------------------------------------------------
-- Check key analytical fields for NULL values.

SELECT
    SUM(CASE WHEN Order_ID IS NULL THEN 1 ELSE 0 END) AS missing_order_id,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS missing_order_date,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS missing_category,
    SUM(CASE WHEN Region IS NULL THEN 1 ELSE 0 END) AS missing_region,
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS missing_sales,
    SUM(CASE WHEN Discount IS NULL THEN 1 ELSE 0 END) AS missing_discount,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS missing_profit
FROM dbo.clean_data;



-- ------------------------------------------------------------
-- 2.3 Investigate Missing Profit
-- ------------------------------------------------------------
-- One record contains a missing Profit value.
-- Keep the record because Sales and other fields remain valid,
-- but exclude it when a calculation requires known Profit.

SELECT *
FROM dbo.clean_data
WHERE Profit IS NULL;



-- ------------------------------------------------------------
-- 2.4 Duplicate Row Check
-- ------------------------------------------------------------
-- Row_ID should uniquely identify each product-line record.

SELECT
    Row_ID,
    COUNT(*) AS duplicate_count
FROM dbo.clean_data
GROUP BY Row_ID
HAVING COUNT(*) > 1;



-- ------------------------------------------------------------
-- 2.5 Numeric Range / Sanity Check
-- ------------------------------------------------------------
-- Review minimum and maximum values to identify potentially
-- invalid or extreme values.

SELECT
    MIN(Sales) AS min_sales,
    MAX(Sales) AS max_sales,
    MIN(Quantity) AS min_quantity,
    MAX(Quantity) AS max_quantity,
    MIN(Discount) AS min_discount,
    MAX(Discount) AS max_discount,
    MIN(Profit) AS min_profit,
    MAX(Profit) AS max_profit
FROM dbo.clean_data;



-- ------------------------------------------------------------
-- 2.6 Categorical Consistency Checks
-- ------------------------------------------------------------
-- Review unique business categories to identify inconsistent
-- labels, spelling, or formatting.

SELECT DISTINCT Category
FROM dbo.clean_data
ORDER BY Category;


SELECT DISTINCT Region
FROM dbo.clean_data
ORDER BY Region;


SELECT DISTINCT Segment
FROM dbo.clean_data
ORDER BY Segment;



-- ------------------------------------------------------------
-- 2.7 Analysis Time Period
-- ------------------------------------------------------------
-- Identify the date range covered by the dataset.

SELECT
    MIN(Order_Date) AS first_order_date,
    MAX(Order_Date) AS last_order_date
FROM dbo.clean_data;



-- ============================================================
-- 3. EXECUTIVE BUSINESS KPIs
-- ============================================================


-- ------------------------------------------------------------
-- 3.1 Sales, Profit & Profit Margin
-- ------------------------------------------------------------
-- Total Sales uses all valid Sales records.
-- Total Profit ignores the single NULL Profit automatically.
--
-- Profit Margin uses only rows where Profit is known so that
-- Sales and Profit are calculated from the same records.

SELECT
    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN Profit IS NOT NULL THEN Profit
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data;



-- ------------------------------------------------------------
-- 3.2 Orders, Average Order Value & Average Discount
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT Order_ID) AS total_orders,

    ROUND(
        SUM(Sales) / COUNT(DISTINCT Order_ID),
        2
    ) AS average_order_value,

    ROUND(
        AVG(Discount) * 100,
        2
    ) AS average_discount_pct

FROM dbo.clean_data;



-- ============================================================
-- 4. BUSINESS QUESTION 1
-- WHICH PRODUCT AREAS ARE STRONG OR UNDERPERFORMING?
-- ============================================================


-- ------------------------------------------------------------
-- 4.1 Category Performance
-- ------------------------------------------------------------
-- Compare Sales, Profit, and Profit Margin across categories.
-- This identifies categories with strong revenue but weak
-- profitability.

SELECT
    Category,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

GROUP BY Category

ORDER BY total_sales DESC;



-- ------------------------------------------------------------
-- 4.2 Furniture Sub-Category Analysis
-- ------------------------------------------------------------
-- Furniture showed weak profitability at category level.
-- Drill down into Furniture sub-categories to identify which
-- areas are contributing to the weak margin.

SELECT
    Sub_Category,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

WHERE Category = 'Furniture'

GROUP BY Sub_Category

ORDER BY profit_margin_pct ASC;



-- ============================================================
-- 5. BUSINESS QUESTION 2
-- IS DISCOUNTING ASSOCIATED WITH LOWER PROFITABILITY?
-- ============================================================


-- ------------------------------------------------------------
-- 5.1 Table Profitability by Discount Band
-- ------------------------------------------------------------
-- Tables were identified as a major loss-making sub-category.
-- Group Table transactions into discount bands to investigate
-- whether heavier discounts are associated with lower margins.

SELECT
    CASE
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount <= 0.10 THEN '1-10%'
        WHEN Discount <= 0.20 THEN '11-20%'
        WHEN Discount <= 0.30 THEN '21-30%'
        ELSE '30%+'
    END AS discount_band,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

WHERE Sub_Category = 'Tables'

GROUP BY
    CASE
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount <= 0.10 THEN '1-10%'
        WHEN Discount <= 0.20 THEN '11-20%'
        WHEN Discount <= 0.30 THEN '21-30%'
        ELSE '30%+'
    END

ORDER BY profit_margin_pct DESC;



-- ------------------------------------------------------------
-- 5.2 Company-Wide Discount Analysis
-- ------------------------------------------------------------
-- Extend the discount analysis across the entire business to
-- determine whether the relationship between discounting and
-- profitability exists beyond Tables.

SELECT
    CASE
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount <= 0.10 THEN '1-10%'
        WHEN Discount <= 0.20 THEN '11-20%'
        WHEN Discount <= 0.30 THEN '21-30%'
        ELSE '30%+'
    END AS discount_band,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

GROUP BY
    CASE
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount <= 0.10 THEN '1-10%'
        WHEN Discount <= 0.20 THEN '11-20%'
        WHEN Discount <= 0.30 THEN '21-30%'
        ELSE '30%+'
    END

ORDER BY profit_margin_pct DESC;



-- ============================================================
-- 6. BUSINESS QUESTION 3
-- WHICH REGIONS & CUSTOMER SEGMENTS ARE UNDERPERFORMING?
-- ============================================================


-- ------------------------------------------------------------
-- 6.1 Regional Performance
-- ------------------------------------------------------------
-- Compare Sales, Profit, and Profit Margin across regions.

SELECT
    Region,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

GROUP BY Region

ORDER BY profit_margin_pct DESC;



-- ------------------------------------------------------------
-- 6.2 Customer Segment Performance
-- ------------------------------------------------------------
-- Compare profitability across Consumer, Corporate, and
-- Home Office customer segments.

SELECT
    Segment,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

GROUP BY Segment

ORDER BY profit_margin_pct DESC;



-- ============================================================
-- 7. CROSS-DIMENSIONAL ANALYSIS
-- REGION + CATEGORY PERFORMANCE
-- ============================================================

-- Compare each Region and Category combination.
-- This identifies whether weak regional performance is
-- concentrated within particular product categories.

SELECT
    Region,
    Category,

    ROUND(SUM(Sales), 2) AS total_sales,

    ROUND(SUM(Profit), 2) AS total_profit,

    ROUND(
        100.0 * SUM(Profit)
        /
        NULLIF(
            SUM(
                CASE
                    WHEN Profit IS NOT NULL THEN Sales
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS profit_margin_pct

FROM dbo.clean_data

GROUP BY
    Region,
    Category

ORDER BY
    profit_margin_pct ASC;


/* ============================================================
   END OF ANALYSIS
   ============================================================ */