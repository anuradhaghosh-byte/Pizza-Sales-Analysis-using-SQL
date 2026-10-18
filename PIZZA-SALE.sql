USE  PIZZA_SALE ;
SHOW tables;
SELECT * FROM  order_details;
SELECT * FROM  orderS ;
SELECT * FROM  PIZZA_TYPES;
SELECT * FROM PIZZAS ;
create view summary_table as
(with t1 as 
(select order_details_id,o.order_id, pizza_id, quantity, date, time
 from order_details oi
join orders o
on oi.order_id=o.order_id ) ,
t2 as 
(select date, time,
order_details_id,order_id, t.pizza_id, pizza_type_id, quantity,size, price
 from t1 t 
join 
pizzas p
on 
p.pizza_id=t.pizza_id),
t3 as 
( select date, time,
order_details_id,order_id, pizza_id, t2.pizza_type_id,
quantity,size, price,
name, category
 from t2 
join 
pizza_types pt
on
t2.pizza_type_id=pt.pizza_type_id),
t4 as 
( select * , (quantity*price) as amount from t3)
select date, time,  order_id, order_details_id, pizza_id, pizza_type_id,  name, category,size,quantity, price,amount
 from t4);

select * from summary_table;

-- Q1-Which pizza generated the highest revenue?

 select name ,
 round(sum(amount),2) as total_revenue
 from summary_table 
 group by 
 name 
 order by total_revenue desc
 limit 1 ;

-- The highest revenue and pizza name is The Thai Chicken Pizza = 43434.25

-- Q2- Which pizzas earn more than the average pizza revenue? 

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

-- Q3- Which pizzas have high revenue but low sales quantity? 

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
  
-- Q4 - Which pizza is the most profitable for the business (revenue share, Pareto analysis)?

SELECT
    name,
    ROUND(SUM(amount), 2) AS total_revenue,
    ROUND(
        SUM(amount) * 100.0 /
        (SELECT SUM(amount) FROM summary_table),
        2
    ) AS revenue_share_pct
FROM summary_table
GROUP BY name
ORDER BY total_revenue DESC;

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

-- Q5 - Which pizzas were never sold?

SELECT p.name
FROM PIZZA_TYPES AS p
LEFT JOIN summary_table AS s
    ON p.name = s.name;

-- Time-Based Analysis

-- Q6 - Which hour of the day gets the most orders?

select date , hour(time) as time ,
sum(quantity) as no ,
rank () over (order by sum(quantity) desc ) as rank_
from summary_table 
group by 
date , hour(time)
order by no desc ; 

select date, hour(time) as TIME  , 
sum(quantity) as no_of_pizza
from summary_table 
group by date,
hour(time) 
order by no_of_pizza  desc  ;

-- Q7 - How much revenue is generated in each hour?

select date, hour(time) as TIME  , 
round(sum(amount),2) as revenue
from summary_table 
group by date,
hour(time) 
order by revenue desc  ;

-- overall 

SELECT
    HOUR(time) AS order_hour,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(amount), 2) AS total_revenue
FROM summary_table
GROUP BY HOUR(time)
ORDER BY total_orders DESC;

-- Q8 - Which day of the week gets the most orders and the most revenue?
SELECT
    DAYNAME(date) AS day_name,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(amount), 2) AS total_revenue
FROM summary_table
GROUP BY DAYNAME(date), WEEKDAY(date)
ORDER BY WEEKDAY(date);

-- Day with the most orders
SELECT DAYNAME(date) AS day_name, COUNT(DISTINCT order_id) AS total_orders
FROM summary_table
GROUP BY DAYNAME(date)
ORDER BY total_orders DESC
LIMIT 1;

-- Day with the most revenue
SELECT DAYNAME(date) AS day_name, ROUND(SUM(amount), 2) AS total_revenue
FROM summary_table
GROUP BY DAYNAME(date)
ORDER BY total_revenue DESC
LIMIT 1;

-- Q9 - Daily, weekly, and monthly quantity ranking (rank restarts every month and every week).
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

-- Q10 - Daily cumulative (running total) revenue.

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
 
-- Q11- Next-day and next-month revenue comparison using LEAD.

  create or replace  view  monthly_comp as (  WITH daily AS (
    SELECT
        DATE(date) AS sale_date,
        ROUND(SUM(amount), 2) AS daily_revenue
    FROM summary_table
    GROUP BY DATE(date)
),
t1 AS (
    SELECT
        MONTH(date) AS no,
        MONTHNAME(date) AS month,
        ROUND(SUM(amount), 2) AS amount
    FROM summary_table
    GROUP BY MONTH(date), MONTHNAME(date)
),
t2 AS (
    SELECT *,
        LEAD(amount) OVER (ORDER BY no) AS next_month_revenue
    FROM t1
),
t3 AS (
    SELECT *,
        ROUND(next_month_revenue - amount, 2) AS monthly_growth
    FROM t2
)
SELECT *
FROM t3 ) ;
 
   create view  daily_comp as (  WITH daily AS (
    SELECT
        DATE(date) AS sale_date,
        ROUND(SUM(amount), 2) AS daily_revenue
    FROM summary_table
    GROUP BY DATE(date)
),
t1 AS (
    SELECT
        MONTH(date) AS no,
        MONTHNAME(date) AS month,
        ROUND(SUM(amount), 2) AS amount
    FROM summary_table
    GROUP BY MONTH(date), MONTHNAME(date)
),
t2 AS (
    SELECT *,
        LEAD(amount) OVER (ORDER BY no) AS next_month_revenue
    FROM t1
),
t3 AS (
    SELECT *,
        ROUND(next_month_revenue - amount, 2) AS monthly_growth
    FROM t2
),
t4 AS (
    SELECT *,
        LEAD(daily_revenue) OVER (ORDER BY sale_date)
            AS next_day_revenue
    FROM daily
)
SELECT *
FROM t4 ) ;

select * from monthly_comp;
select * from daily_comp;

-- Ranking

-- Q12 - Pizza ranking by category and by revenue.
select category ,name ,
round(sum(amount),2) as revenue ,
rank () over
 (partition by category order by sum(amount) desc ) as rank_
from summary_table 
group by 
category , name
order by revenue desc ;

-- Q13 - Top-selling pizza of every month (rank = 1).

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
  
-- Q14 - Pizza ranking by order .

select order_id,
sum(quantity) as no ,
rank () over
 ( order by sum(quantity) desc ) as rank_
from summary_table 
group by 
order_id
order by no desc ;

-- EVERY DAY TOTAL ORDER QUANTITY 

select date,
round(sum(quantity),2) as total_no_of_order 
from summary_table 
group by 
date order by date asc ;

-- DAILY REVENUE 

select date,
round(sum(amount),2) as total_amount
from summary_table 
group by 
date order by date asc ;

-- MONTHLY REVENUE 

select month(date) as month_no ,
monthname(date) as month_name,
round(sum(amount),2) as total_amount
from summary_table 
group by 
month(date),monthname(date)
 order by month(date) asc ;
 
 -- TOP 5 MONTHLY REVENUE
 
 select month(date) as month_no ,
monthname(date) as month_name,
round(sum(amount),2) as total_amount
from summary_table 
group by 
month(date),monthname(date)
 order by total_amount desc limit 5  ;
 
 -- WHICH DAY MOSTLY QUANTITY SOLD
 
 SELECT
    YEAR(date) AS yr,
    MONTH(date) AS month,
    CEIL(DAY(date) / 7) AS week_of_month,
    date,
    SUM(quantity) AS daily_total_quantity,
    RANK() OVER (
        PARTITION BY YEAR(date), MONTH(date), CEIL(DAY(date) / 7)
        ORDER BY SUM(quantity) DESC
    ) AS daily_rank
FROM summary_table
GROUP BY YEAR(date), MONTH(date), CEIL(DAY(date) / 7), date
ORDER BY yr, month, week_of_month, daily_rank;

-- WHICH DAY MOSTLY GAIN REVENUE

select year(date) as yr , 
monthname(date) as month ,
ceil(day(date)/7) as wk_of_month ,
date , 
round(sum(amount),2) as revenue ,
rank () over 
( partition by
year(date) , 
monthname(date)  ,
ceil(day(date)/7) 
order by 
sum(amount) desc ) as  daily_rank 
from 
summary_table 
group by 
year(date)  , 
monthname(date) ,
ceil(day(date)/7) ,
date 
order by yr , month , wk_of_month,daily_rank;

SELECT
    name,
    ROUND(SUM(amount), 2) AS revenue,
    ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER (), 2) AS revenue_pct
FROM summary_table
GROUP BY name
ORDER BY revenue DESC
LIMIT 1;

SELECT HOUR(time) AS order_hour, COUNT(DISTINCT order_id) AS total_orders
FROM summary_table
GROUP BY HOUR(time)
ORDER BY total_orders DESC
LIMIT 1;

SELECT
    DAYNAME(date) AS day_name,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(amount), 2) AS total_revenue
FROM summary_table
GROUP BY DAYNAME(date)
ORDER BY total_revenue DESC;

WITH pizza_rev AS (
    SELECT name, SUM(amount) AS revenue
    FROM summary_table
    GROUP BY name
)
SELECT
    name,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY revenue DESC) * 100.0
          / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM pizza_rev
ORDER BY revenue DESC;

-- total order and unique order 
select count(order_id) as total_no_of_order from summary_table;
select count(distinct(order_id)) as unique_no_of_order from summary_table;
-- total pizza type 
select count(distinct(pizza_id)) as unique_no_OF_pizza_id from summary_table;
-- মোট কত রকমের পিৎজা রয়েছে?
select count(distinct(name)) as unique_no_of_pizza_name from summary_table;

SELECT COUNT(DISTINCT (category)) AS unique_no_of_category FROM summary_table;
-- কত রকমের পিৎজা সাইজ রয়েছে?
select count(distinct (size)) as type_of_size from summary_table ;
-- total no of revenue 
select round(sum(amount),2) as revenue from summary_table ;

-- costly pizza 
select name , price  from summary_table 
where price = 
( select max(price) as highest_price 
from summary_table) limit 1 ;
-- cheap pizza 
select name , price  from summary_table 
where price = 
( select min(price) as lowest_price 
from summary_table) limit 1 ;

-- top 10 order with no of order 

with t1 as (select order_id , 
sum(quantity) as no_of_order
 from summary_table 
 group by order_id 
 order by order_id asc),
 t2 as 
 ( select * from t1 
 order by no_of_order desc
 limit 10)
 select * from t2 ;
 
 -- which catagory most sold 
 select category,
 sum(quantity) as no_of_quantity 
 from summary_table 
 group by 
 category
 order by no_of_quantity desc ;
 
 -- top  pizza category 
 
 select category ,
 round(sum(quantity),2) as total_quantity 
 from summary_table 
 group by 
 category 
 order by total_quantity  desc limit 1 ;
 
  -- which pizza most order // 
 
 select name ,
 sum(quantity) as no_of_quantity 
 from summary_table 
 group by
 name
 order by no_of_quantity  desc  ;
 
 -- each pizza total amount 
   select name ,
 round(sum(amount),2) as total_amount
 from summary_table 
 group by
 name
 order by total_amount desc  ;
 
 -- order by total amount 

select order_id,
sum(amount) as total_amount 
from summary_table 
group by 
order_id 
order by order_id asc ;

-- size wise pizza sale 

select size , sum(quantity) as no_of_pizza
from summary_table
group by 
size ;


select name , 
count(distinct(order_id)) as qt ,
rank () over (order by  count(distinct(order_id)) desc ) as rank_od
from summary_table 
group by 
name 
order by qt desc 
limit 5 ;

select name ,
sum(quantity) as revenue 
from summary_table 
group by 
name 
order by revenue desc 
limit 5 ; 

select name ,
round(sum(amount),2) as revenue 
from summary_table 
group by 
name 
order by revenue desc 
limit 5 ;

select name , 
count(distinct(order_id)) as od ,
round(sum(amount),2) as revenue ,
rank () over (order by  count(distinct(order_id)) desc ) as rank_od,
 rank() over ( order by sum(amount) desc ) as rank__re
from summary_table 
group by 
name 
order by od desc ,
 revenue desc ;
-- top category and pizza name 
select category ,name ,
round(sum(amount),2) as revenue 
from summary_table 
group by 
category , name
order by revenue desc limit 10  ;

-- order more than 3 

 SELECT 
    order_id, SUM(quantity) AS no
FROM
    summary_table
GROUP BY order_id
HAVING no > 3;

-- most intersted cayegory 

select category , name ,
sum(quantity) as q 
from summary_table 
group by 
category ,name
order by 
q desc ;

-- which size mostly wanted

select name , size ,
sum(quantity) as q 
from summary_table 
group by 
name , size 
order by 
q  desc ;

