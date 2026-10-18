# Pizza-Sales-Analysis-using-SQL
# A SQL project that analyzes pizza sales data to find out which pizzas, days, and hours bring in the most orders and revenue. Built with MySQL
##📌 Project Overview

The goal of this project is to turn raw sales data into business insights using SQL. It covers aggregation, window functions, CTEs, subqueries, and joins to answer real business questions about pizza sales.

## 🛠️ Tools & Skills Used
MySQL 8+
Aggregate functions: SUM, COUNT, AVG, ROUND
Date and time functions: YEAR, MONTH, MONTHNAME, WEEK, DAYNAME, HOUR, CEIL
Window functions: RANK, ROW_NUMBER, LEAD, LAG, PERCENT_RANK, running totals with SUM() OVER
CTEs, subqueries, HAVING, LEFT JOIN, NOT EXISTS

## 🗂️ Dataset

The analysis is done on a table named summary_table.

| Column | Description |
|---|---|
| `order_id` | Unique ID of each order |
| `name` | Pizza name |
| `category` | Pizza category |
| `date` | Order date |
| `time` | Order time |
| `quantity` | Number of pizzas sold |
| `price` | Price of one pizza |
| `amount` | Total amount for the row |

## ❓ Business Questions Answered

# Sales and Revenue
- Which pizza generated the highest revenue?
  ```sql
   select name , round(sum(amount),2) as total_revenue from summary_table group by name  order by total_revenue desc limit 1 ; 
 
- Which pizzas earn more than the average pizza revenue?
``` sql
SELECT name,
       ROUND(SUM(amount), 2) AS total_revenue
FROM summary_table
GROUP BY name
HAVING total_revenue > (
    SELECT round(AVG(total_amount),2) as avg_amount
    FROM (
        SELECT name,round(SUM(amount),2) AS total_amount
        FROM summary_table
        GROUP BY name
) AS avg_table
)
ORDER BY total_revenue DESC;
```
- Which pizzas have high revenue but low sales quantity?
``` sql
 with t1 as 
  (select name , 
   round(sum(quantity),2) as total_quantity ,
   round(sum(amount),2) as revenue
   from summary_table 
   group by name ) ,
   t2 as 
   ( select * from t1 
   where total_quantity < (select avg(total_quantity) as avg_quantity from t1)
  and revenue > (select avg(revenue) as avg_revenue from t1)) 
  select * from t2
ORDER BY revenue DESC;
```
- Which pizza is the most profitable for the business (revenue share, Pareto analysis)?
``` sql
WITH pizza_revenue AS (
    SELECT
        name,
        SUM(amount) AS total_revenue
    FROM summary_table
    GROUP BY name
),
pareto AS (
    SELECT
        name,
        ROUND(total_revenue, 2) AS total_revenue,
        ROUND(
            total_revenue * 100.0 /
            SUM(total_revenue) OVER (),
            2
        ) AS revenue_share_pct,
        ROUND(
            SUM(total_revenue) OVER (
                ORDER BY total_revenue DESC
                ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
            ) * 100.0 /
            SUM(total_revenue) OVER (),
            2
        ) AS cumulative_revenue_pct
    FROM pizza_revenue
)
SELECT *
FROM pareto
ORDER BY total_revenue DESC;
```
- Which pizzas were never sold?

# Time-Based Analysis
- Which hour of the day gets the most orders?
``` sql
select date, hour(time) as TIME  , 
sum(quantity) as no_of_pizza
from summary_table 
group by date,
hour(time) 
order by no_of_pizza  desc  ;
```
- How much revenue is generated in each hour?
``` sql
select date, hour(time) as TIME  , 
round(sum(amount),2) as revenue
from summary_table 
group by date,
hour(time) 
order by revenue desc  ;
```
- Which day of the week gets the most orders and the most revenue?

- Daily, weekly, and monthly quantity ranking (rank restarts every month and every week).
``` sql
  WITH t1 AS (
    SELECT
        MONTH(date) AS month_no,
        MONTHNAME(date) AS month_name,
        FLOOR((DAY(date) - 1) / 7) + 1 AS week_no,
        name,
        SUM(quantity) AS total
    FROM summary_table
    GROUP BY
        MONTH(date),
        MONTHNAME(date),
        FLOOR((DAY(date) - 1) / 7) + 1,
        name
),
weekly_rank AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY month_no, week_no
            ORDER BY total DESC
        ) AS weekly_rank
    FROM t1
),
monthly_total AS (
    SELECT
        month_no,
        month_name,
        name,
        SUM(total) AS monthly_quantity
    FROM t1
    GROUP BY month_no, month_name, name
),
monthly_rank AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY month_no
            ORDER BY monthly_quantity DESC
        ) AS monthly_rank
    FROM monthly_total
)
SELECT
    w.month_name,
    w.week_no,
    w.name,
    w.total AS weekly_quantity,
    w.weekly_rank,
    m.monthly_quantity,
    m.monthly_rank
FROM weekly_rank AS w
JOIN monthly_rank AS m
    ON w.month_no = m.month_no
    AND w.name = m.name
ORDER BY
    w.month_no,
    w.week_no,
    w.weekly_rank;
```
- Daily cumulative (running total) revenue.
``` sql
with t1 as ( select date , 
round(sum(amount),2) as revenue,
lag (round(sum(amount),2),1,'not found' ) 
  over(order by date ) as next_day_revenue
    from summary_table 
group by 
 date ) ,
 t2 as 
 ( select * , round((revenue+next_day_revenue),2)as Cumulative_revenue from t1) 
 select * from t2 
  ;
```
- Next-day and next-month revenue comparison using LEAD.

# Ranking
- Pizza ranking by orders and by revenue.
- Top-selling pizza of every month (rank = 1).
``` sql
WITH t1 AS (
    SELECT
        MONTH(date) AS month_no,
        MONTHNAME(date) AS m,
        name,
        SUM(quantity) AS no
    FROM summary_table
    GROUP BY MONTH(date), MONTHNAME(date), name
),
t2 AS (
    SELECT *,
           RANK() OVER (
               PARTITION BY month_no
               ORDER BY no DESC
           ) AS pizza_rank
    FROM t1
)
SELECT m, name, no, pizza_rank
FROM t2
WHERE pizza_rank = 1
ORDER BY month_no;
``` 
- Pizza ranking inside each category.

## 🔍 Key Insights

- The top pizza is **The Thai Chicken Pizza**, contributing **5.3%** of total revenue 43434.25
- The busiest hour is **12:00**, with the highest number of orders 2520.
- **Friday** has the highest orders 3538 and revenue 136073.9 	
- The top ** 11 pizzas** bring in 80% of the revenue.
- **The Greek Pizza** has high revenue but low quantity, so it is a premium item worth promoting.


# ⚠️ Limitations

This is a revenue-based analysis. The dataset has no cost data, so true profit could not be calculated. With cost data, profit can be found using revenue - (cost × quantity).


# 👩‍💻 Author

Anuradha Ghosh B.Sc. in Biosciences | Aspiring Data Analyst Skills: SQL, Excel, Power BI

📫 Connect with me on LinkedIn - https://www.linkedin.com/in/anuradha-ghosh-analyst/

  
