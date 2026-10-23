USE METRO_DW;

-- ==========================================================================================
-- Q1. Top Revenue-Generating Products on Weekdays and Weekends with Monthly Drill-Down
-- Requirement: Find the top 5 products that generated the highest revenue, separated by 
-- weekday and weekend sales, with results grouped by month for a specified year (2019).
-- Technique: Slicing by Year, Dicing by Month and Weekday/Weekend, Window Ranking (DENSE_RANK).
-- ==========================================================================================
WITH MonthlyRankedProducts AS (
    SELECT 
        MONTH(sf.Order_Date) AS Sales_Month,
        CASE 
            WHEN DAYOFWEEK(sf.Order_Date) IN (1, 7) THEN 'Weekend' 
            ELSE 'Weekday' 
        END AS Day_Type,
        p.Product_ID,
        p.Product_Name,
        SUM(sf.Total_Sale) AS Total_Revenue,
        DENSE_RANK() OVER (
            PARTITION BY MONTH(sf.Order_Date), 
                         CASE WHEN DAYOFWEEK(sf.Order_Date) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END 
            ORDER BY SUM(sf.Total_Sale) DESC
        ) AS Revenue_Rank
    FROM SalesFact sf
    JOIN Products p ON sf.Product_ID = p.Product_ID
    WHERE YEAR(sf.Order_Date) = 2019
    GROUP BY Sales_Month, Day_Type, p.Product_ID, p.Product_Name
)
SELECT 
    Sales_Month,
    Day_Type,
    Revenue_Rank,
    Product_ID,
    Product_Name,
    Total_Revenue
FROM MonthlyRankedProducts
WHERE Revenue_Rank <= 5
ORDER BY Sales_Month, Day_Type, Revenue_Rank;


-- ==========================================================================================
-- Q2. Trend Analysis of Store Revenue Growth Rate Quarterly for 2017 (or Dataset Year 2019)
-- Requirement: Calculate the revenue growth rate for each store on a quarterly basis.
-- Note: The dataset transactions are from 2019. We query 2019 with a parameter note for 2017.
-- Technique: Slicing by Year, Drill-down to Quarter, LAG() Window Function for Growth Rate.
-- ==========================================================================================
WITH StoreQuarterlyRevenue AS (
    SELECT 
        st.Store_ID,
        st.Store_Name,
        QUARTER(sf.Order_Date) AS Sales_Quarter,
        SUM(sf.Total_Sale) AS Current_Quarter_Revenue
    FROM SalesFact sf
    JOIN Stores st ON sf.Store_ID = st.Store_ID
    WHERE YEAR(sf.Order_Date) = 2019 -- Change to 2017 if running against historical dataset
    GROUP BY st.Store_ID, st.Store_Name, Sales_Quarter
)
SELECT 
    Store_ID,
    Store_Name,
    Sales_Quarter,
    Current_Quarter_Revenue,
    LAG(Current_Quarter_Revenue) OVER (
        PARTITION BY Store_ID ORDER BY Sales_Quarter
    ) AS Previous_Quarter_Revenue,
    ROUND(
        ((Current_Quarter_Revenue - LAG(Current_Quarter_Revenue) OVER (PARTITION BY Store_ID ORDER BY Sales_Quarter)) / 
         NULLIF(LAG(Current_Quarter_Revenue) OVER (PARTITION BY Store_ID ORDER BY Sales_Quarter), 0)) * 100, 
        2
    ) AS Quarterly_Growth_Rate_Pct
FROM StoreQuarterlyRevenue
ORDER BY Store_ID, Sales_Quarter;


-- ==========================================================================================
-- Q3. Detailed Supplier Sales Contribution by Store and Product Name
-- Requirement: For each store, show total sales contribution of each supplier broken down
-- by product name. Results grouped by store, then supplier, and then product name.
-- Technique: Multi-level aggregation (Store -> Supplier -> Product) and Window Share-of-Store.
-- ==========================================================================================
SELECT 
    st.Store_ID,
    st.Store_Name,
    sup.Supplier_ID,
    sup.Supplier_Name,
    p.Product_ID,
    p.Product_Name,
    SUM(sf.Quantity_Ordered) AS Units_Sold,
    SUM(sf.Total_Sale) AS Sales_Contribution,
    ROUND(
        (SUM(sf.Total_Sale) / SUM(SUM(sf.Total_Sale)) OVER (PARTITION BY st.Store_ID)) * 100, 
        2
    ) AS Pct_Of_Store_Sales
FROM SalesFact sf
JOIN Stores st ON sf.Store_ID = st.Store_ID
JOIN Suppliers sup ON sf.Supplier_ID = sup.Supplier_ID
JOIN Products p ON sf.Product_ID = p.Product_ID
GROUP BY st.Store_ID, st.Store_Name, sup.Supplier_ID, sup.Supplier_Name, p.Product_ID, p.Product_Name
ORDER BY st.Store_Name, sup.Supplier_Name, p.Product_Name;


-- ==========================================================================================
-- Q4. Seasonal Analysis of Product Sales Using Dynamic Drill-Down
-- Requirement: Present total sales for each product, drilled down by seasonal periods
-- (Spring, Summer, Fall, Winter).
-- Technique: Temporal Drill-down (Month -> Meteorological Season Mapping).
-- ==========================================================================================
SELECT 
    p.Product_ID,
    p.Product_Name,
    CASE 
        WHEN MONTH(sf.Order_Date) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(sf.Order_Date) IN (3, 4, 5) THEN 'Spring'
        WHEN MONTH(sf.Order_Date) IN (6, 7, 8) THEN 'Summer'
        WHEN MONTH(sf.Order_Date) IN (9, 10, 11) THEN 'Fall'
    END AS Season,
    SUM(sf.Quantity_Ordered) AS Total_Units_Sold,
    SUM(sf.Total_Sale) AS Total_Sales_Revenue
FROM SalesFact sf
JOIN Products p ON sf.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name, Season
ORDER BY p.Product_Name, FIELD(Season, 'Spring', 'Summer', 'Fall', 'Winter');


-- ==========================================================================================
-- Q5. Store-Wise and Supplier-Wise Monthly Revenue Volatility
-- Requirement: Calculate month-to-month revenue volatility for each store and supplier pair,
-- defined as percentage change in revenue from one month to the next.
-- Technique: Multi-dimensional partitioning with LAG() Window Function.
-- ==========================================================================================
WITH MonthlyStoreSupplierRevenue AS (
    SELECT 
        st.Store_ID,
        st.Store_Name,
        sup.Supplier_ID,
        sup.Supplier_Name,
        YEAR(sf.Order_Date) AS Sales_Year,
        MONTH(sf.Order_Date) AS Sales_Month,
        SUM(sf.Total_Sale) AS Monthly_Revenue
    FROM SalesFact sf
    JOIN Stores st ON sf.Store_ID = st.Store_ID
    JOIN Suppliers sup ON sf.Supplier_ID = sup.Supplier_ID
    GROUP BY st.Store_ID, st.Store_Name, sup.Supplier_ID, sup.Supplier_Name, Sales_Year, Sales_Month
)
SELECT 
    Store_ID,
    Store_Name,
    Supplier_ID,
    Supplier_Name,
    Sales_Year,
    Sales_Month,
    Monthly_Revenue,
    LAG(Monthly_Revenue) OVER (
        PARTITION BY Store_ID, Supplier_ID 
        ORDER BY Sales_Year, Sales_Month
    ) AS Previous_Month_Revenue,
    ROUND(
        ((Monthly_Revenue - LAG(Monthly_Revenue) OVER (
            PARTITION BY Store_ID, Supplier_ID 
            ORDER BY Sales_Year, Sales_Month
        )) / NULLIF(LAG(Monthly_Revenue) OVER (
            PARTITION BY Store_ID, Supplier_ID 
            ORDER BY Sales_Year, Sales_Month
        ), 0)) * 100, 
        2
    ) AS Revenue_Volatility_Pct
FROM MonthlyStoreSupplierRevenue
ORDER BY Store_Name, Supplier_Name, Sales_Year, Sales_Month;


-- ==========================================================================================
-- Q6. Top 5 Products Purchased Together Across Multiple Orders (Product Affinity Analysis)
-- Requirement: Identify top 5 products frequently bought together within a transaction/order.
-- Note: In this retail dataset, items bought in the same shopping session share Customer_ID 
-- and Order_Date timestamp. Self-join on (Customer_ID, Order_Date) pairs co-purchased items.
-- ==========================================================================================
SELECT 
    sf1.Product_ID AS Product_1_ID,
    p1.Product_Name AS Product_1_Name,
    sf2.Product_ID AS Product_2_ID,
    p2.Product_Name AS Product_2_Name,
    COUNT(*) AS Co_Purchase_Frequency
FROM SalesFact sf1
JOIN SalesFact sf2 
    ON sf1.Customer_ID = sf2.Customer_ID 
   AND sf1.Order_Date = sf2.Order_Date 
   AND sf1.Product_ID < sf2.Product_ID
JOIN Products p1 ON sf1.Product_ID = p1.Product_ID
JOIN Products p2 ON sf2.Product_ID = p2.Product_ID
GROUP BY sf1.Product_ID, p1.Product_Name, sf2.Product_ID, p2.Product_Name
ORDER BY Co_Purchase_Frequency DESC
LIMIT 5;


-- ==========================================================================================
-- Q7. Yearly Revenue Trends by Store, Supplier, and Product with ROLLUP
-- Requirement: Aggregate revenue data hierarchically by Store -> Supplier -> Product using ROLLUP.
-- Technique: Hierarchical Aggregation (CUBE/ROLLUP) with subtotal and grand total identification.
-- ==========================================================================================
SELECT 
    COALESCE(st.Store_Name, '--> ALL STORES (GRAND TOTAL)') AS Store,
    COALESCE(sup.Supplier_Name, '--> ALL SUPPLIERS TOTAL') AS Supplier,
    COALESCE(p.Product_Name, '--> ALL PRODUCTS TOTAL') AS Product,
    SUM(sf.Quantity_Ordered) AS Total_Units,
    SUM(sf.Total_Sale) AS Total_Revenue
FROM SalesFact sf
JOIN Stores st ON sf.Store_ID = st.Store_ID
JOIN Suppliers sup ON sf.Supplier_ID = sup.Supplier_ID
JOIN Products p ON sf.Product_ID = p.Product_ID
GROUP BY st.Store_Name, sup.Supplier_Name, p.Product_Name WITH ROLLUP;


-- ==========================================================================================
-- Q8. Revenue and Volume-Based Sales Analysis for Each Product for H1 and H2
-- Requirement: For each product, calculate total revenue and quantity sold in H1 and H2,
-- along with yearly totals.
-- Technique: Conditional Aggregation (Pivoting time periods).
-- ==========================================================================================
SELECT 
    p.Product_ID,
    p.Product_Name,
    -- Revenue Split
    SUM(CASE WHEN MONTH(sf.Order_Date) BETWEEN 1 AND 6 THEN sf.Total_Sale ELSE 0 END) AS H1_Revenue,
    SUM(CASE WHEN MONTH(sf.Order_Date) BETWEEN 7 AND 12 THEN sf.Total_Sale ELSE 0 END) AS H2_Revenue,
    SUM(sf.Total_Sale) AS Total_Yearly_Revenue,
    -- Volume Split
    SUM(CASE WHEN MONTH(sf.Order_Date) BETWEEN 1 AND 6 THEN sf.Quantity_Ordered ELSE 0 END) AS H1_Quantity,
    SUM(CASE WHEN MONTH(sf.Order_Date) BETWEEN 7 AND 12 THEN sf.Quantity_Ordered ELSE 0 END) AS H2_Quantity,
    SUM(sf.Quantity_Ordered) AS Total_Yearly_Quantity
FROM SalesFact sf
JOIN Products p ON sf.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name
ORDER BY Total_Yearly_Revenue DESC;


-- ==========================================================================================
-- Q9. Identify High Revenue Spikes in Product Sales and Highlight Outliers
-- Requirement: Calculate daily average sales for each product and flag days where sales exceed
-- twice the daily average (> 2x Avg).
-- Technique: Two-stage aggregation (Daily total -> Product window average -> Anomaly filter).
-- ==========================================================================================
WITH DailyProductSales AS (
    -- Step 1: Calculate actual daily sales per product
    SELECT 
        sf.Product_ID,
        p.Product_Name,
        DATE(sf.Order_Date) AS Sale_Date,
        SUM(sf.Total_Sale) AS Daily_Sales,
        SUM(sf.Quantity_Ordered) AS Daily_Units
    FROM SalesFact sf
    JOIN Products p ON sf.Product_ID = p.Product_ID
    GROUP BY sf.Product_ID, p.Product_Name, DATE(sf.Order_Date)
),
ProductDailyAverages AS (
    -- Step 2: Compute average daily sales across all active sales days for that product
    SELECT 
        Product_ID,
        Product_Name,
        Sale_Date,
        Daily_Sales,
        Daily_Units,
        AVG(Daily_Sales) OVER (PARTITION BY Product_ID) AS Avg_Daily_Sales
    FROM DailyProductSales
)
-- Step 3: Flag outliers where Daily_Sales > 2 * Avg_Daily_Sales
SELECT 
    Product_ID,
    Product_Name,
    Sale_Date,
    ROUND(Daily_Sales, 2) AS Daily_Sales,
    ROUND(Avg_Daily_Sales, 2) AS Avg_Daily_Sales,
    ROUND(Daily_Sales / NULLIF(Avg_Daily_Sales, 0), 2) AS Spike_Ratio,
    'OUTLIER (> 2x Daily Average)' AS Anomaly_Flag
FROM ProductDailyAverages
WHERE Daily_Sales > (2 * Avg_Daily_Sales)
ORDER BY Spike_Ratio DESC, Product_ID, Sale_Date;


-- ==========================================================================================
-- Q10. Create a View STORE_QUARTERLY_SALES for Optimized Sales Analysis
-- Requirement: Create view named STORE_QUARTERLY_SALES that aggregates total quarterly sales
-- by store, ordered by store name.
-- Technique: Materialized/Virtual View for BI and executive dashboards.
-- ==========================================================================================
DROP VIEW IF EXISTS STORE_QUARTERLY_SALES;

CREATE VIEW STORE_QUARTERLY_SALES AS
SELECT 
    st.Store_ID,
    st.Store_Name,
    YEAR(sf.Order_Date) AS Sales_Year,
    QUARTER(sf.Order_Date) AS Sales_Quarter,
    SUM(sf.Quantity_Ordered) AS Total_Units_Sold,
    SUM(sf.Total_Sale) AS Total_Quarterly_Sales
FROM SalesFact sf
JOIN Stores st ON sf.Store_ID = st.Store_ID
GROUP BY st.Store_ID, st.Store_Name, Sales_Year, Sales_Quarter
ORDER BY st.Store_Name, Sales_Year, Sales_Quarter;

-- Query to verify the created view:
SELECT * FROM STORE_QUARTERLY_SALES LIMIT 10;
