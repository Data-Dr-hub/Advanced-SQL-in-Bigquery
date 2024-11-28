# Advanced-SQL-in-Bigquery
![](images.png)
This is one of the tasking projects I did during my training at [Turing College](https://www.googleadservices.com/pagead/aclk?sa=L&ai=DChcSEwjCiOD22JCIAxWVllAGHWpnLsEYABAAGgJkZw&co=1&ase=2&gclid=Cj0KCQjwrKu2BhDkARIsAD7GBotSHFAQ4ycCQsgFWc_BLqffpJE7djg7oxJRvH9Lk-d737VxQ7xKzvsaApw7EALw_wcB&ohost=www.google.com&cid=CAESVeD26E7GlHarmFCyqmd4isFRidbRZhPORDsHLJJw8MbN4dkZP-1awOj1Hie36TIuzJxXctWHO5Snfpg-P5O8hpyEkVwgdFH_w0SMxSGGvy4VaRcVaFc&sig=AOD64_3beaXtrGfc2vnnLPuslcnOUHLd-Q&q&nis=4&adurl&ved=2ahUKEwjuytn22JCIAxVSQkEAHTvyJfgQ0Qx6BAgKEAE)

The database is the Adventureworks Database and the sql code was written in **BigQuery**.
The project include concepts like: CTEs, Subqueries, Logical Reasoning, and Critical Thinking.

## Tasks
**1.1** I was tasked to create a detailed overview of all individual customers (these are defined by customerType = ‘I’ and/or stored in an individual table).  

I wrote a query that provides:

* Identity information : CustomerId, Firstname, Last Name, FullName (First Name & Last Name).
* An Extra column called addressing_title i.e. (Mr. Achong), if the title is missing - Dear Achong.
* Contact information : Email, phone, account number, CustomerType.
* Location information : City, State & Country, address.
* Sales: number of orders, total amount (with Tax), date of the last order.

_Hint: Few customers have multiple addresses, to avoid duplicate data I took their latest available address by choosing max(AddressId)_

**1.2** Business finds the original query valuable to analyze customers and now want to get the data from the first query for the top 200 customers with the highest total amount (with tax) who have not ordered for the last 365 days.

**1.3** Building on query 1.1, I created a new column in the view that marks active & inactive customers based on whether they have ordered anything during the last 365 days.
![images](https://github.com/user-attachments/assets/a9ae462a-2c27-4dfc-993d-60d4491707bf)

**1.4** Business would like to extract data on all active customers from North America. Only customers that have either ordered no less than 2500 in total amount (with Tax) or ordered 5 + times should be presented.

**2.1**
I created a query of monthly sales numbers in each Country & region. Included in the query a number of orders, customers and sales persons in each month with a total amount with tax earned. Sales numbers from all types of customers are included.

**2.2** I enriched 2.1 query with the cumulative_sum of the total amount with tax earned per country & region.

**2.3** I also built on 2.2 query by adding ‘sales_rank’ column that ranks rows from best to worst for each country based on total amount with tax earned each month. I.e. the month where the (US, Southwest) region made the highest total amount with tax earned will be ranked 1 for that region and vice versa.

**2.4** I further enriched 2.3 query by adding taxes on a country level:

* As taxes can vary in country based on province, the needed column is **‘mean_tax_rate’ -> average tax rate in a country.**
* Also, as not all regions have data on taxes, you also want to be transparent and show the ‘perc_provinces_w_tax’ -> a column representing the percentage of provinces with available tax rates for each country (i.e. If US has 53 provinces, and 10 of them have tax rates, then for US it should show 0,19)
  
Hint1: If a state has multiple tax rates, choose the higher one. Do not double count a state in country average rate calculation if it has multiple tax rates.
Hint2: Ignore the isonlystateprovinceFlag rate mechanic, it is beyond the scope of this exercise. Treat all tax rates as equal.

Here is the [SQL script](AdvancedSql.sql)
