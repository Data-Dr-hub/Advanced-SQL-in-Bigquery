
/*
1.1 You’ve been tasked to create a detailed overview of all individual customers (these are defined by customerType = ‘I’ and/or stored in an individual table). 
Write a query that provides:Identity information : CustomerId, Firstname, Last Name, FullName (First Name & Last Name).
An Extra column called addressing_title i.e. (Mr. Achong), if the title is missing - Dear Achong.
Contact information : Email, phone, account number, CustomerType.
Location information : City, State & Country, address.
Sales: number of orders, total amount (with Tax), date of the last order.
Copy only the top 200 rows from your written select ordered by total amount (with tax).

Hint: Few customers have multiple addresses, to avoid duplicate data take their latest available address by choosing max(AddressId)
*/

WITH
  customer_identity  --creating a  cte to hold the personal info of individual customers
      AS (
      SELECT
            individual.CustomerID AS CustomerID,
            contact.Firstname,
            contact.LastName,
            CONCAT(contact.Firstname, ' ',contact.LastName) AS FullName,-- combining first and last name into Full Name
            --creating a column that attaches title to last name if available, else uses 'Dear' as the default title:
            CASE
              WHEN contact.Title IS NULL THEN CONCAT('Dear', ' ', contact.LastName)
              ELSE CONCAT(contact.Title, '. ', contact.LastName)
              END AS addressing_title,
            contact.Emailaddress,
            contact.Phone,
            customer.AccountNumber,
            customer.CustomerType
      FROM
        `adwentureworks_db.individual` AS individual
      LEFT JOIN
        `adwentureworks_db.contact` AS contact
      ON
        individual.ContactID = contact.ContactId
      LEFT JOIN
        `adwentureworks_db.customer` AS customer
      ON
        individual.CustomerID = customer.CustomerID),
        
  latest_location AS -- creating another cte to hold the maximum location of individual customers
      (SELECT
            individual.customerID AS customerID,
            sub.max_AddressID AS latest_addressID
      FROM
            `adwentureworks_db.individual` AS individual
      LEFT JOIN 
          -- This subquery specifically extracts the maximum addressID against each customer
          (SELECT
              CustomerID,
              MAX(AddressID) AS max_AddressID
            FROM
              `tc-da-1.adwentureworks_db.customeraddress`
            GROUP BY
              1) sub
      ON
        individual.CustomerID = sub.CustomerID),
  
  sales AS -- creating another cte to hold aggregations
      (SELECT
        salesorder.CustomerID AS customerID,
        COUNT(SalesOrderID) AS number_of_orders,
        ROUND(SUM(TotalDue), 3) AS total_amount,
        MAX(OrderDate) AS date_last_order
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `tc-da-1.adwentureworks_db.individual`
      ON
        salesorder.CustomerID = `tc-da-1.adwentureworks_db.individual`.CustomerID
      GROUP BY 1)
SELECT
    customer_identity.*, -- selecting every column from the first cte (customer idenity)
    address.City,
    address.AddressLine1,
    address.AddressLine2,
    state_province.Name AS State,
    territory.Name AS Country,
    sales.number_of_orders,
    sales.total_amount,
    sales.date_last_order
FROM
  customer_identity
JOIN
  latest_location
ON
  customer_identity.CustomerID = latest_location.customerID
JOIN
  `adwentureworks_db.address` address
ON
  address.AddressID = latest_location.latest_addressID
JOIN
  `adwentureworks_db.stateprovince` AS state_province
ON
  address.StateProvinceID = state_province.StateProvinceID
JOIN
  `adwentureworks_db.salesterritory` AS territory
ON
  state_province.TerritoryID = territory.TerritoryID
JOIN
  sales
ON
  customer_identity.CustomerID = sales.customerID
ORDER BY
  sales.total_amount DESC -- sorting the result in descending order of sales amount
LIMIT
  200 -- extracting the top 200 rows


/*
1.2 Business finds the original query valuable to analyze customers and now want to get the data from the first query for the top 200 customers with the highest total amount (with tax) who have not ordered for the last 365 days. How would you identify this segment?

Hints:

You can use temp table, cte and/or subquery of the 1.1 select.
Note that the database is old and the current date should be defined by finding the latest order date in the orders table.
*/
WITH
  customer_identity  --creating a  cte to hold the personal info of individual customers
      AS (SELECT
        individual.CustomerID AS CustomerID,
        contact.Firstname,
        contact.LastName,
        CONCAT(contact.Firstname, ' ',contact.LastName) AS FullName,-- combining first and last name into Full Name
        --creating a column that attaches title to last name if available, else uses 'Dear' as the default title
        CASE
          WHEN contact.Title IS NULL THEN CONCAT('Dear', ' ', contact.LastName)
          ELSE CONCAT(contact.Title, '. ', contact.LastName)
      END
        AS addressing_title,
        contact.Emailaddress,
        contact.Phone,
        customer.AccountNumber,
        customer.CustomerType
      FROM
        `adwentureworks_db.individual` AS individual
      LEFT JOIN
        `adwentureworks_db.contact` AS contact
      ON
        individual.ContactID = contact.ContactId
      LEFT JOIN
        `adwentureworks_db.customer` AS customer
      ON
        individual.CustomerID = customer.CustomerID),
latest_location AS -- creating another cte to hold the maximum location of individual customers
      (SELECT
            individual.customerID AS customerID,
            sub.max_AddressID AS latest_addressID
          FROM
            `adwentureworks_db.individual` AS individual
          LEFT JOIN 
          -- This subquery specifically extracts the maximum addressID against each customer
          (SELECT
              CustomerID,
              MAX(AddressID) AS max_AddressID
            FROM
              `tc-da-1.adwentureworks_db.customeraddress`
            GROUP BY
              1) sub
          ON
            individual.CustomerID = sub.CustomerID),
  
  sales AS 
    (SELECT 
      DISTINCT customerID,
      number_of_orders,
      total_amount,
      date_last_order,
      currentdate
    FROM
        (SELECT
          salesorder.CustomerID AS customerID,
          -- aggregations are updated to window functions for easy selection by the outer query
          COUNT(salesorder.SalesOrderID) OVER(PARTITION BY salesorder.CustomerID) AS number_of_orders,
          SUM(salesorder.TotalDue) OVER(PARTITION BY salesorder.CustomerID) AS total_amount, 
          MAX(salesorder.OrderDate) OVER(PARTITION BY salesorder.CustomerID) AS date_last_order,-- calculating latest orderdate for each customer
          MAX(salesorder.OrderDate) OVER() AS currentdate -- calculating the most recent order date of the businsess
        FROM
          `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
        JOIN
          `tc-da-1.adwentureworks_db.individual`
        ON
          salesorder.CustomerID = `tc-da-1.adwentureworks_db.individual`.CustomerID) AS sub2)
SELECT
      customer_identity.*,
      address.City,
      address.AddressLine1,
      address.AddressLine2,
      state_province.Name AS State,
      territory.Name AS Country,
      sales.number_of_orders,
      ROUND(sales.total_amount, 3) total_amount,
      sales.date_last_order,
      sales.currentdate,
      DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) days_diff -- calculating how many days past a customer made the last order
FROM
  customer_identity
JOIN
  latest_location
ON
  customer_identity.CustomerID = latest_location.customerID
JOIN
  `adwentureworks_db.address` address
ON
  address.AddressID = latest_location.latest_addressID
JOIN
  `adwentureworks_db.stateprovince` AS state_province
ON
  address.StateProvinceID = state_province.StateProvinceID
JOIN
  `adwentureworks_db.salesterritory` AS territory
ON
  state_province.TerritoryID = territory.TerritoryID
JOIN
  sales
ON
  customer_identity.CustomerID = sales.customerID
  -- filtering for customers who have not ordered for the past 365 days or more
WHERE DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) >= 365
ORDER BY
  sales.total_amount DESC
LIMIT 200

/*
1.3 Enrich your original 1.1 SELECT by creating a new column in the view that marks active & inactive customers based on whether they have ordered anything during the last 365 days.

Copy only the top 500 rows from your written select ordered by CustomerId desc.
*/
WITH
  customer_identity --creating a  cte to hold the personal info of individual customers
      AS (SELECT
        individual.CustomerID AS CustomerID,
        contact.Firstname,
        contact.LastName,
        CONCAT(contact.Firstname, ' ',contact.LastName) AS FullName,-- combining first and last name into Full Name
        --creating a column that attaches title to last name if available, else uses 'Dear' as the default title
        CASE
          WHEN contact.Title IS NULL THEN CONCAT('Dear', ' ', contact.LastName)
          ELSE CONCAT(contact.Title, '. ', contact.LastName)
      END
        AS addressing_title,
        contact.Emailaddress,
        contact.Phone,
        customer.AccountNumber,
        customer.CustomerType
      FROM
        `adwentureworks_db.individual` AS individual
      LEFT JOIN
        `adwentureworks_db.contact` AS contact
      ON
        individual.ContactID = contact.ContactId
      LEFT JOIN
        `adwentureworks_db.customer` AS customer
      ON
        individual.CustomerID = customer.CustomerID),
latest_location AS -- creating another cte to hold the maximum location of individual customers
      (SELECT
            individual.customerID AS customerID,
            sub.max_AddressID AS latest_addressID
          FROM
            `adwentureworks_db.individual` AS individual 
          LEFT JOIN ( 
          -- This subquery specifically extracts the maximum addressID against each customer
            SELECT
              CustomerID,
              MAX(AddressID) AS max_AddressID
            FROM
              `tc-da-1.adwentureworks_db.customeraddress`
            GROUP BY
              1) sub
          ON
            individual.CustomerID = sub.CustomerID),
  
  sales AS 
      (SELECT
        DISTINCT salesorder.CustomerID AS customerID,
        COUNT(salesorder.SalesOrderID) OVER(PARTITION BY salesorder.CustomerID) AS number_of_orders,
        SUM(salesorder.TotalDue) OVER(PARTITION BY salesorder.CustomerID) AS total_amount,
        MAX(salesorder.OrderDate) OVER(PARTITION BY salesorder.CustomerID) AS date_last_order, -- calculating latest orderdate for each customer
        MAX(salesorder.OrderDate) OVER() AS currentdate -- calculating the most recent order date of the businsess
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `tc-da-1.adwentureworks_db.individual`
      ON
        salesorder.CustomerID = `tc-da-1.adwentureworks_db.individual`.CustomerID)
SELECT
      customer_identity.*,
      address.City,
      address.AddressLine1,
      address.AddressLine2,
      state_province.Name AS State,
      territory.Name AS Country,
      sales.number_of_orders,
      ROUND(sales.total_amount, 3) total_amount,
      sales.date_last_order,
      sales.currentdate,
      DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) days_diff,
      -- Assigning Activity Status to Customers based on whether they have ordered anything during the last 365 days.
      CASE WHEN DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) >= 365 THEN 'INACTIVE' ELSE 'ACTIVE' END AS ActivityStatus
FROM
  customer_identity
JOIN
  latest_location
ON
  customer_identity.CustomerID = latest_location.customerID
JOIN
  `adwentureworks_db.address` address
ON
  address.AddressID = latest_location.latest_addressID
JOIN
  `adwentureworks_db.stateprovince` AS state_province
ON
  address.StateProvinceID = state_province.StateProvinceID
JOIN
  `adwentureworks_db.salesterritory` AS territory
ON
  state_province.TerritoryID = territory.TerritoryID
JOIN
  sales
ON
  customer_identity.CustomerID = sales.customerID
ORDER BY
  CustomerID DESC
LIMIT 500 --Only Top 500 rows

/*
1.4 Business would like to extract data on all active customers from North America. 
Only customers that have either ordered no less than 2500 in total amount (with Tax) or ordered 5 + times should be presented.
*/
WITH
  customer_identity --creating a  cte to hold the personal info of individual customers
      AS (SELECT
        individual.CustomerID AS CustomerID,
        contact.Firstname,
        contact.LastName,
        CONCAT(contact.Firstname, ' ',contact.LastName) AS FullName,-- combining first and last name into Full Name
        --creating a column that attaches title to last name if available, else uses 'Dear' as the default title
        CASE
          WHEN contact.Title IS NULL THEN CONCAT('Dear', ' ', contact.LastName)
          ELSE CONCAT(contact.Title, '. ', contact.LastName)
      END
        AS addressing_title,
        contact.Emailaddress,
        contact.Phone,
        customer.AccountNumber,
        customer.CustomerType
      FROM
        `adwentureworks_db.individual` AS individual
      LEFT JOIN
        `adwentureworks_db.contact` AS contact
      ON
        individual.ContactID = contact.ContactId
      LEFT JOIN
        `adwentureworks_db.customer` AS customer
      ON
        individual.CustomerID = customer.CustomerID),
latest_location AS -- creating another cte to hold the maximum location of individual customers
      (SELECT
            individual.customerID AS customerID,
            sub.max_AddressID AS latest_addressID
          FROM
            `adwentureworks_db.individual` AS individual
          LEFT JOIN (
            SELECT
              CustomerID,
              MAX(AddressID) AS max_AddressID
            FROM
              `tc-da-1.adwentureworks_db.customeraddress`
            GROUP BY
              1) sub
          ON
            individual.CustomerID = sub.CustomerID),
  
  sales AS 
      (SELECT
        DISTINCT salesorder.CustomerID AS customerID,
        COUNT(salesorder.SalesOrderID) OVER(PARTITION BY salesorder.CustomerID) AS number_of_orders,
        SUM(salesorder.TotalDue) OVER(PARTITION BY salesorder.CustomerID) AS total_amount,
        MAX(salesorder.OrderDate) OVER(PARTITION BY salesorder.CustomerID) AS date_last_order,
        MAX(salesorder.OrderDate) OVER() AS currentdate
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `tc-da-1.adwentureworks_db.individual`
      ON
        salesorder.CustomerID = `tc-da-1.adwentureworks_db.individual`.CustomerID)
SELECT
      customer_identity.*,
      address.City,
      address.AddressLine1,
      LEFT(address.AddressLine1,STRPOS(address.AddressLine1, ' ')-1) AS address_no, -- extracting address no
      SUBSTR(address.AddressLine1,STRPOS(address.AddressLine1, ' ')+1 ) AS address_str,--extracting address street
      address.AddressLine2,
      state_province.Name AS State,
      territory.Name AS Country,
      sales.number_of_orders,
      ROUND(sales.total_amount, 2) total_amount,
      sales.date_last_order,
      sales.currentdate,
      DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) days_diff,
      -- Assigning Activity Status to Customers based on whether they have ordered anything during the last 365 days.
      CASE WHEN DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) >= 365 THEN 'INACTIVE' ELSE 'ACTIVE' END AS ActivityStatus
FROM
  customer_identity
JOIN
  latest_location
ON
  customer_identity.CustomerID = latest_location.customerID
JOIN
  `adwentureworks_db.address` address
ON
  address.AddressID = latest_location.latest_addressID
JOIN
  `adwentureworks_db.stateprovince` AS state_province
ON
  address.StateProvinceID = state_province.StateProvinceID
JOIN
  `adwentureworks_db.salesterritory` AS territory
ON
  state_province.TerritoryID = territory.TerritoryID
JOIN
  sales
ON
  customer_identity.CustomerID = sales.customerID
WHERE 
    NOT DATETIME_DIFF(sales.currentdate, sales.date_last_order, day) >= 365 -- filtering for active customers
    AND 
    territory.Name LIKE 'North%' -- filtering for north America
    AND
    ((total_amount >= 2500)  OR (number_of_orders > 5) )
ORDER BY
Country, State, date_last_order

/*
2.1 Create a query of monthly sales numbers in each Country & region. 
Include in the query a number of orders, customers and sales persons in each month with a total amount with tax earned. Sales numbers from all types of customers are required.
*/
SELECT 
  DATE(datetime_trunc(OrderDate, month)) AS order_month,
  salesterritory.CountryRegionCode,
  salesterritory.Name as Region,
  count(SalesOrderID) as number_of_orders,
  count(DISTINCT CustomerID) as number_customers,
  count(DISTINCT SalesPersonID) no_salesPerson,
  ROUND(sum(TotalDue), 2) as total_w_tax
FROM `tc-da-1.adwentureworks_db.salesorderheader` as salesorder
JOIN `adwentureworks_db.salesterritory` as salesterritory
ON salesorder.TerritoryID = salesterritory.TerritoryID
group by 1,2,3

/*
2.2 Enrich 2.1 query with the cumulative_sum of the total amount with tax earned per country & region.

Hint: use CTE or subquery.
*/
WITH
  cte AS -- coverts query 2.1 to cte
      (SELECT
        DATE(DATETIME_TRUNC(OrderDate, month)) AS order_month,
        salesterritory.CountryRegionCode,
        salesterritory.Name AS Region,
        COUNT(SalesOrderID) AS number_of_orders,
        COUNT(DISTINCT CustomerID) AS number_customers,
        COUNT(DISTINCT SalesPersonID) no_salesPerson,
        ROUND(SUM(TotalDue), 2) AS total_w_tax,
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `adwentureworks_db.salesterritory` AS salesterritory
      ON
        salesorder.TerritoryID = salesterritory.TerritoryID
      GROUP BY 1,2,3)
      
SELECT
  cte.*,
  SUM(cte.total_w_tax) OVER(PARTITION BY cte.Region ORDER BY cte.order_month) AS cumulative_sum --calculates running totals per country
FROM
  cte

/*
2.3 Enrich 2.2 query by adding ‘sales_rank’ column that ranks rows from best to worst for each country 
based on total amount with tax earned each month. I.e. the month where the (US, Southwest) region made the highest total amount with tax earned will be ranked 1 for that region and vice versa.
*/
WITH
  cte AS 
      (SELECT
        DATE(DATETIME_TRUNC(OrderDate, month)) AS order_month,
        salesterritory.CountryRegionCode,
        salesterritory.Name AS Region,
        COUNT(SalesOrderID) AS number_of_orders,
        COUNT(DISTINCT CustomerID) AS number_customers,
        COUNT(DISTINCT SalesPersonID) no_salesPerson,
        ROUND(SUM(TotalDue), 2) AS total_w_tax,
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `adwentureworks_db.salesterritory` AS salesterritory
      ON
        salesorder.TerritoryID = salesterritory.TerritoryID
      GROUP BY 1,2,3)
SELECT
      cte.*,
      RANK() OVER(PARTITION BY cte.CountryRegionCode ORDER BY cte.total_w_tax DESC) AS sales_rank, -- ranking countries by total amt with tax
      SUM(cte.total_w_tax) OVER(PARTITION BY cte.Region ORDER BY cte.order_month) AS cumulative_sum
      
FROM
  cte
--WHERE cte.CountryRegionCode = 'FR'
ORDER BY
  sales_rank

/*
2.4 Enrich 2.3 query by adding taxes on a country level:

As taxes can vary in country based on province, the needed column is ‘mean_tax_rate’ -> average tax rate in a country.
Also, as not all regions have data on taxes, you also want to be transparent and show the ‘perc_provinces_w_tax’ -> a column representing the percentage of provinces with available tax rates for each country 
(i.e. If US has 53 provinces, and 10 of them have tax rates, then for US it should show 0,19)
Hint: If a state has multiple tax rates, choose the higher one. Do not double count a state in country average rate calculation if it has multiple tax rates.

Hint: Ignore the isonlystateprovinceFlag rate mechanic, it is beyond the scope of this exercise. Treat all tax rates as equal.
*/
WITH
  cte AS 
      (SELECT
            DATE(DATETIME_TRUNC(OrderDate, month)) AS order_month,
            salesterritory.CountryRegionCode,
            salesterritory.Name AS Region,
            COUNT(SalesOrderID) AS number_of_orders,
            COUNT(DISTINCT CustomerID) AS number_customers,
            COUNT(DISTINCT SalesPersonID) no_salesPerson,
            ROUND(SUM(TotalDue), 2) AS total_w_tax,
      FROM
        `tc-da-1.adwentureworks_db.salesorderheader` AS salesorder
      JOIN
        `adwentureworks_db.salesterritory` AS salesterritory
      ON
        salesorder.TerritoryID = salesterritory.TerritoryID
      GROUP BY 1,2,3),
  CTE_TaxRate AS 
      (SELECT 
              stateprovince.CountryRegionCode as CountryRegionCode, --selecting all countries
              ROUND(AVG(TaxRate ), 1) AS mean_tax_rate, -- calculating the average tax rate in a country(i.e 'sub_MaxTaxRate.TaxRate')
              -- below calculates the percentage of provinces with available tax rates for each country
              ROUND(COUNT(sub_MaxTaxRate.TaxRate)/COUNT(stateprovince.StateProvinceID), 2) AS perc_provinces_w_tax 
      FROM 
              (SELECT StateProvinceID, MAX(TaxRate) AS TaxRate --This selects the higher TaxRate for provinces with multiple TaxRates
              FROM `adwentureworks_db.salestaxrate` 
              GROUP BY 1) sub_MaxTaxRate
      RIGHT JOIN 
              `adwentureworks_db.stateprovince` as stateprovince --Right Join includes states without taxrate as null
            ON sub_MaxTaxRate.StateProvinceID = stateprovince.StateProvinceID
      GROUP BY 1) --Groups by each country
            
SELECT
      cte.*,
      RANK() OVER(PARTITION BY cte.CountryRegionCode ORDER BY cte.total_w_tax DESC) AS country_sales_rank,
      SUM(cte.total_w_tax) OVER(PARTITION BY cte.Region ORDER BY cte.order_month) AS cumulative_sum,
      CTE_TaxRate.mean_tax_rate ,
      CTE_TaxRate.perc_provinces_w_tax
      
FROM
  cte
JOIN 
    CTE_TaxRate ON cte.CountryRegionCode = CTE_TaxRate.CountryRegionCode
--WHERE cte.CountryRegionCode = 'US'--region filtered on US
