use ecommerce
select * from order_details

--renaming the column_names
alter table order_details change 'Sub-Category' sub_category varchar(25);
ALTER TABLE order_details CHANGE COLUMN `Sub-Category` sub_category VARCHAR(25);
ALTER TABLE order_details CHANGE COLUMN `Order ID` order_id  VARCHAR(25);
ALTER TABLE order_list CHANGE COLUMN `Order Date` order_date  VARCHAR(25);
ALTER TABLE sales_target CHANGE COLUMN `Month of Order Date` Month_of_order  VARCHAR(25

-- Combine order details table with order list table
create view combined_order as 
select od.order_id, od.amount, od.profit, od.quantity ,od.category, od.sub_category, ol.order_date, ol.customerName, ol.state, ol.city 
from order_details as od join order_list as ol
on od.order_id = ol.order_id

-- Segment the customer into groups based on RFM model.
select * from customer_grouping 

create view customer_groupings AS
select *,
case 
when (R>=4 and R<=5) and (((F+M)/2)>=4 and ((F+M)/2)<=5) THEN "champions"
when (R>=2 and R<=5) and (((F+M)/2)>=3 and ((F+M)/2)<=5) THEN "Loyal Customers"
when (R>=3 and R<=5) and (((F+M)/2)>=1 and ((F+M)/2)<=3) THEN "Potential Loyelist"
when (R>=4 and R<=5) and (((F+M)/2)>=0 and ((F+M)/2)<=1) THEN "new Customers"
when (R>=3 and R<=4) and (((F+M)/2)>=0 and ((F+M)/2)<=1) THEN "Promising"
when (R>=2 and R<=3) and (((F+M)/2)>=2 and ((F+M)/2)<=3) THEN "Cstomer Needing Attention"
when (R>=2 and R<=3) and (((F+M)/2)>=0 and ((F+M)/2)<=2) THEN "About to sleep"
when (R>=0 and R<=2) and (((F+M)/2)>=2 and ((F+M)/2)<=5) THEN "At risk"
when (R>=0 and R<=1) and (((F+M)/2)>=4 and ((F+M)/2)<=5) THEN "Can't lose them"
when (R>=1 and R<=2) and (((F+M)/2)>=1 and ((F+M)/2)<=2) THEN "Hibernating"
when (R>=0 and R<=2) and (((F+M)/2)>=0 and ((F+M)/2)<=2) THEN "Lost"
end as customer_segment
from(
select
max(str_to_date(order_date,"%d-%m-%y")) as latest_order_date,
customername,
datediff(str_to_date('31-03-2019',"%d-%m-%y"), max(str_to_date(order_date,"%d-%m-%y"))) as recency,
count(distinct order_id) as frequency,
sum(amount) as monetary,
ntile(5) over (order by datediff(str_to_date('31-03-2019',"%d-%m-%y"), max(str_to_date(order_date,"%d-%m-%y"))) desc) as R,
ntile(5) over (order by count(distinct order_id)asc) as F,
ntile(5) over (order by sum(amount)asc) as M
from combined_order
group by customerName) RFM_table	
group by customerName


-- Qn: Show the number and percentage for each customer segment as the final result. Order the results by the percentage of customers.
-- return the number and percentage of each customer segment
create view customer_segment as
select customer_segment, 
count(distinct customername) as num_of_customers,
round (count(distinct customername)/(select count(*) from customer_groupings)*100,2) as per_of_customers
from customer_groupings 
group by customer_segment
order by per_of_customers desc;

-- Qn2: Find the number of orders, customers, cities, and states.
-- Number of orders, customers, cities and states
select count(distinct order_id) as num_of_orders,
count(distinct customername) as num_of_customers,
count(distinct city) as num_of_cities,
count(distinct state) as num_of_states
from combined_order

/* Qn3:Find the new customers who made purchases in the year 2019. 
Only shows the top 5 new customers and their respective cities and states.
Order the result by the amount they spent.
*/
 -- Top 5 new customers
SELECT CustomerName, state, city, sum(amount) as sales
from combined_order
where CustomerName not in (
select distinct CustomerName 
from combined_order 
where year(str_to_date(order_Date, '%d-%m-%Y'))=2018)
and year(str_to_date(order_Date, '%d-%m-%Y'))=2019
group by CustomerName, state, city 
order by sales desc
limit 5;

 /*Find the top 10 profitable states & cities so that the company can expand its business.
 Determine the number of products sold and the number of customers in these top 10 profitable states & cities.
*/
-- number of customers, quantity sold, profit made as per states and city
select state, city, count(distinct customername) as num_of_customers,
sum(profit) as total_profit,
sum(quantity) as total_quantity
from combined_order
group by state, city
order by total_profit desc
limit 10;

/*
Display the details (in terms of “order_date”, “order_id”, “State”, and “CustomerName”) for the first order in each state. 
Order the result by “order_id”.
*/
-- first order in each state
select order_date, order_id, state, customername
from( select *, row_number() over (partition by state order by state, order_id)
as row_num_per_state
from combined_order)as  firstorder
where row_num_per_state =1
order by order_id;

-- Check the monthly profitability and monthly quantity sold to see if there are patterns in the dataset.
select concat (monthname(str_to_date(order_Date,'%d-%m-%Y')),"-", year(str_to_date(order_date,'%d-%m-%Y'))) as month_of_year,
sum(profit) as total_profit, sum(quantity) as total_quantity
from combined_order
group by month_of_year

/*Find the total sales, total profit, and total quantity sold for each category and sub-category. 
Return the maximum cost and maximum price for each sub-category too.*/
create view Final_order_details as
select 
t.category,
t.sub_category,
t.total_order_quantity,
t.total_profit,
t.total_amount,
u.max_cost,
u.max_price
from 
(select 
category ,
sub_category,
sum(quantity) as total_order_quantity,
sum(profit) as total_profit,
sum(amount) as total_amount
from order_details 
group by category, sub_category
order by total_order_quantity desc
) as t
join(
select sub_category, 
max(cost_per_unit) as max_cost,
max(price_per_unit) as max_price
from(select *, round((amount-profit)/quantity, 2) as cost_per_unit, round(amount/quantity,2) as price_per_unit
from order_details) as c
group by sub_category
order by max_cost desc
) as u
on t.sub_category = u.sub_category;



