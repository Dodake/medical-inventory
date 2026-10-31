CREATE DATABASE PharmaDB;
USE PharmaDB;
CREATE TABLE FactSales (
    TransactionID INT PRIMARY KEY,
    Patient_ID VARCHAR(50),
    ProductID INT,
    DateID INT,
    DeptID INT,
    Typeofsales VARCHAR(20),
    Quantity INT,
    ReturnQuantity INT,
    Final_Cost DECIMAL(10,2),
    Final_Sales DECIMAL(10,2),
    RtnMRP DECIMAL(10,2)
);

CREATE TABLE DimProduct (
    ProductID INT PRIMARY KEY,
    Formulation VARCHAR(100),
    DrugName VARCHAR(255),
    SubCat VARCHAR(100),
    SubCat1 VARCHAR(100)
);

CREATE TABLE DimDepartment (
    DeptID INT PRIMARY KEY,
    Specialisation VARCHAR(100),
    Dept VARCHAR(100)
);

CREATE TABLE DimDate (
    Dateofbill DATE,
    DateID INT PRIMARY KEY,
    Month INT,
    Year INT,
    DayName VARCHAR(20),
    Day INT
);

Drop table DimDate;
Drop database PharmaDB;
SELECT * FROM FactSales; 
SELECT * FROM dimproduct; 
SELECT * FROM dimdepartment;
SELECT * FROM dimdate;

# 1. Determine the top 15 drugs that account for 80% of total revenue.

WITH DrugRevenue AS (
    SELECT d.DrugName, SUM(f.Final_Sales) AS Revenue
    FROM FactSales f
    JOIN DimProduct d ON f.ProductID = d.ProductID
    GROUP BY d.DrugName
),
TotalRevenue AS (
    SELECT SUM(Revenue) AS TotalRev FROM DrugRevenue
),
Ranked AS (
    SELECT *,
           SUM(Revenue) OVER (ORDER BY Revenue DESC) /
           (SELECT TotalRev FROM TotalRevenue) AS CumPerc
    FROM DrugRevenue
)
SELECT *
FROM Ranked
WHERE CumPerc <= 0.8
LIMIT 15;

# 2. Calculate the rolling 90-day average net sales quantity for the top 5 drugs to set a dynamic reorder point.

WITH TopDrugs AS (
    SELECT ProductID
    FROM FactSales
    GROUP BY ProductID
    ORDER BY SUM(Quantity) DESC
    LIMIT 5
)
SELECT f.ProductID, d.Dateofbill,
       AVG(f.Quantity) OVER (
           PARTITION BY f.ProductID
           ORDER BY d.Dateofbill
           ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
       ) AS RollingAvg
FROM FactSales f
JOIN DimDate d ON f.DateID = d.DateID
WHERE f.ProductID IN (SELECT ProductID FROM TopDrugs);

# 3. Identify the top 10 drug categories (SubCat1) by total RtnMRP (Wastage Value) and their overall percentage of total sales value.

SELECT p.SubCat1,
       SUM(f.RtnMRP) AS TotalWastage,
       SUM(f.RtnMRP) * 100 / SUM(SUM(f.RtnMRP)) OVER() AS Percentage
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
GROUP BY p.SubCat1
ORDER BY TotalWastage DESC
LIMIT 10;

# 4. Calculate the percentage of sales quantity that are returned (ReturnQuantity) for each Specialisation to flag potential quality/prescription issues.

SELECT d.Specialisation,
       SUM(f.ReturnQuantity) * 100.0 / SUM(f.Quantity) AS Return_Percentage
FROM FactSales f
JOIN DimDepartment d ON f.DeptID = d.DeptID
GROUP BY d.Specialisation;

# 5. Calculate the Gross Profit Margin (Final_Sales - Final_Cost) for every Formulation type (e.g., Tablets vs. Syrups).

SELECT p.Formulation,
       SUM(f.Final_Sales - f.Final_Cost) AS Profit
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
GROUP BY p.Formulation;

# 6. Identify specific drugs where the Final_Cost is within 5% of the Final_Sales, indicating minimal profitability.

SELECT p.DrugName, f.Final_Sales, f.Final_Cost
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
WHERE ABS(f.Final_Sales - f.Final_Cost) <= 0.05 * f.Final_Sales; 

# 7. Calculate the Month-over-Month (MoM) and Year-over-Year (YoY) growth in net sales quantity for the entire company.

SELECT Year, Month,
       SUM(Quantity) AS TotalQty,
       LAG(SUM(Quantity)) OVER (ORDER BY Year, Month) AS PrevMonth,
       (SUM(Quantity) - LAG(SUM(Quantity)) OVER (ORDER BY Year, Month)) AS MoM_Growth
FROM FactSales f
JOIN DimDate d ON f.DateID = d.DateID
GROUP BY Year, Month;

# 8. Identify the top 3 months across the last two years with the highest demand for 'ANTI-INFECTIVES' (SubCat1).
SELECT d.Year, d.Month, SUM(f.Quantity) AS TotalQty
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
JOIN DimDate d ON f.DateID = d.DateID
WHERE p.SubCat1 = 'ANTI-INFECTIVES'
GROUP BY d.Year, d.Month
ORDER BY TotalQty DESC
LIMIT 3;

# 9. Rank all Departments by their total net sales value for each month to track shifting customer importance.
SELECT d.Year, d.Month, dept.Dept,
       SUM(f.Final_Sales) AS Revenue,
       RANK() OVER (PARTITION BY d.Year, d.Month ORDER BY SUM(f.Final_Sales) DESC) AS RankDept
FROM FactSales f
JOIN DimDepartment dept ON f.DeptID = dept.DeptID
JOIN DimDate d ON f.DateID = d.DateID
GROUP BY d.Year, d.Month, dept.Dept;

# 10. For every drug, determine the date of its first-ever sale to track introduction and adoption rates.
SELECT p.DrugName, MIN(d.Dateofbill) AS FirstSale
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
JOIN DimDate d ON f.DateID = d.DateID
GROUP BY p.DrugName;

# 11. Calculate the average sales quantity for each DrugName broken down by Quarter (Q1, Q2, Q3, Q4).
SELECT p.DrugName,
       CASE 
           WHEN d.Month IN (1,2,3) THEN 'Q1'
           WHEN d.Month IN (4,5,6) THEN 'Q2'
           WHEN d.Month IN (7,8,9) THEN 'Q3'
           ELSE 'Q4'
       END AS Quarter,
       AVG(f.Quantity) AS AvgQty
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
JOIN DimDate d ON f.DateID = d.DateID
GROUP BY p.DrugName, Quarter;

# 12. Track the sales volume trajectory of the five newest drugs (based on minimum Dateofbill) over their first 90 days.
SELECT p.DrugName, d.Dateofbill, f.Quantity
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
JOIN DimDate d ON f.DateID = d.DateID
WHERE d.Dateofbill <= DATE_ADD(
    (SELECT MIN(Dateofbill) FROM DimDate),
    INTERVAL 90 DAY
);

# 13. Ensure that Quantity is always greater than or equal to ReturnQuantity for any given transaction line item.
SELECT *
FROM FactSales
WHERE ReturnQuantity > Quantity;

# 14. Automate the update of an external FactInventory table by subtracting the sold quantity every time a new row is inserted into FactSales.
CREATE TRIGGER update_inventory
AFTER INSERT ON FactSales
FOR EACH ROW
UPDATE FactInventory
SET Stock = Stock - NEW.Quantity
WHERE ProductID = NEW.ProductID;
update FactSales 
set Stock = Stock - 1;

DROP TRIGGER IF EXISTS update_inventory;



# 15. If a future DimSupplier table is added, use a TRIGGER to log the date and old price every time a Final_Cost value is updated for a specific product.
CREATE TABLE PriceLog (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT,
    OldPrice DECIMAL(10,2),
    NewPrice DECIMAL(10,2),
    ChangeDate DATETIME
);
Drop table PriceLog;
DELIMITER $$

CREATE TRIGGER log_price_change
BEFORE UPDATE ON FactSales
FOR EACH ROW
BEGIN
    IF OLD.Final_Cost <> NEW.Final_Cost THEN
        INSERT INTO PriceLog(ProductID, OldPrice, NewPrice, ChangeDate)
        VALUES (OLD.ProductID, OLD.Final_Cost, NEW.Final_Cost, NOW());
    END IF;
END$$
DELIMITER ;
select * from pricelog;

# 18. Identify the top 5 drugs (by net quantity) sold to the company's single highest-revenue Patient_ID.

WITH TopPatient AS (
    SELECT Patient_ID
    FROM FactSales
    GROUP BY Patient_ID
    ORDER BY SUM(Final_Sales) DESC
    LIMIT 1
)
SELECT p.DrugName, SUM(f.Quantity) AS TotalQty
FROM FactSales f
JOIN DimProduct p ON f.ProductID = p.ProductID
WHERE f.Patient_ID = (SELECT Patient_ID FROM TopPatient)
GROUP BY p.DrugName
ORDER BY TotalQty DESC
LIMIT 5;

# 19. Calculate the average number of days between sales for a high-demand, non-daily medication (e.g., a specific injectable).

SELECT AVG(DATEDIFF(next_date, Dateofbill)) AS AvgDays
FROM (
    SELECT d.Dateofbill,
           LEAD(d.Dateofbill) OVER (ORDER BY d.Dateofbill) AS next_date
    FROM FactSales f
    JOIN DimDate d ON f.DateID = d.DateID
) t;

# 20. For each Specialisation, calculate its contribution to total company sales value and order them.
SELECT dept.Specialisation,
       SUM(f.Final_Sales) AS Revenue,
       SUM(f.Final_Sales) * 100 / SUM(SUM(f.Final_Sales)) OVER() AS Contribution
FROM FactSales f
JOIN DimDepartment dept ON f.DeptID = dept.DeptID
GROUP BY dept.Specialisation
ORDER BY Contribution DESC;