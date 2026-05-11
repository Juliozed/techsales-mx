
-- reference
select * from sales_orders; --order_id, customer_id, rep_id, product_id
select * from products; -- product_id, product_name, supplier_id
select * from reps; -- rep_id, rep_name, 
select * from customers; -- customer_id, tier, name
select * from suppliers; -- supplier_id



--Q:1
"I need a full sales report — every order with the rep's name, 
the actual product name, and the customer's name and tier. I want to see our VIP customers 
highlighted so I know which orders came from our most important accounts."
-- add the annual quota

SELECT
	r.rep_name,
	p.product_name,
	c.tier,
	c.name,
	so.units,
	r.annual_quota
FROM
	sales_orders as so
		left join reps as r on so.rep_id = r.rep_id
		left join customers as c on so.customer_id = c.customer_id
		left join products as p on so.product_id = p.product_id
order by tier desc;
-- in this case less is more, we dont have to use a GROUP BY 
-- when you have a lot going on its best not to GROUP BY 


-- Q:2 Then answer this question from the 
-- results: which rep is handling the most VIP customers?
-- just the names of reps and how many VIPs 
SELECT
	r.rep_name,
	count(c.tier) as total_VIPs
from
	sales_orders as so 
	left join customers as c on so.customer_id = c.customer_id
	left join reps as r on so.rep_id = r.rep_id
where 
	tier = 'VIP'
group by r.rep_name
order by total_VIPs desc;
	

-- Q:3
"If Diego makes more total revenue with fewer orders than Carlos, 
his average order value will be higher. That means
he's closing bigger deals per transaction even if Carlos has more VIP accounts."
-- write a query for each rep: 
-- total rev
-- tota orders
-- average

SELECT
	rep_name,
	count(*) as total_orders,
	ROUND(AVG(revenue),2) as avg_rev_per_rep
FROM
	reps as r 
left join sales_orders as so on r.rep_id = so.rep_id
group by
	rep_name
order by
	avg_rev_per_rep desc;
	


"Exactly right — quantity over quality. Diego is a volume 
seller, Carlos is a value seller.
Now prove it with data. 
--Q:4 Add total orders to your comparison and show me side by side"
-- add total revenue to see it 

SELECT
	r.rep_name,
	so.region,
	count(*) as total_orders,
	ROUND(AVG(revenue),2) as avg_rev_per_rep,
	sum(revenue) as total_revenue
FROM
	reps as r 
left join sales_orders as so on r.rep_id = so.rep_id
group by
	so.region, r.rep_name
order by
	total_revenue desc;

-- carlos averages 7K more, and in the long run over 3 years
-- its 3 million, so carlos does better. 



-- Q:5 cancellation rates by region

SELECT
	so.region,
	round(count(case when status = 'Cancelled' then 1 end) * 100.0 /count(*), 2) as cancel_pct
From
	sales_orders so
left join reps r on so.rep_id = r.rep_id 
group by so.region
order by cancel_pct desc;




-- CTEs
-- subquery version here: 
-- reps with total revenue over 18000000

SELECT rep_name, total_revenue
FROM (
	select r.rep_name, sum(so.revenue) as total_revenue
	from sales_orders so
	left join reps r on so.rep_id = r.rep_id
	group by r.rep_name

) as rep_summary
where total_revenue > 18000000;

-- cte version
with rep_summary as (
	select r.rep_name, sum(so.revenue) as total_revenue
	from sales_orders so
	left join reps r on so.rep_id = r.rep_id
	group by r.rep_name
)
select rep_name, total_revenue
from rep_summary
where total_revenue > 18000000;


-- Q:6 "For each rep, show their total revenue, their cancellation rate,
--and flag whether they are above or below the company average revenue."
-- compnay avg : 45,641.12
with rep_summary as (
	select 
			r.rep_name,
			sum(so.revenue) as total_revenue,
			round(count(case when so.status = 'Cancelled' then 1 end) * 100.0 / count(*),2) as cancel_pct
		from sales_orders so
		left join reps r on so.rep_id = r.rep_id
		group by r.rep_name		
),
company_avg as ( 
	select avg(total_revenue) as avg_rep_revenue
	from rep_summary

)
select
		r.rep_name,
		r.total_revenue,
		r.cancel_pct,
		round(c.avg_rep_revenue) as company_avg,
		case 
			when r.total_revenue > c.avg_rep_revenue
				then 'Above Average'
				else 'Below Average'
		end as performance_flag
from rep_summary r
cross join company_avg as c
order by r.total_revenue desc;




-- Window functions
-- over() , partition by.

select
	r.rep_name,
	so.region,
	sum(so.revenue) as total_revenue,
	rank() over (order by sum(so.revenue) desc) as overall_rank
from sales_orders so 
left join reps r on so.rep_id = r.rep_id
group by r.rep_name, so.region
order by overall_rank;


--Q:7 "Rank each product by total revenue within each category — so I can see which product is 
-- number 1 in Computers, number 1 in Peripherals, number 1 in Audio, etc."
--That's where PARTITION BY becomes essential — you need a separate ranking for each category group.

select 
	p.product_name,
	p.category,
	sum(so.revenue) as total_revenue,
	rank() over(partition by p.category order by sum(so.revenue)) as product_rank,
	ROUND(SUM(so.revenue) * 100.0 / sum(sum(so.revenue))over (partition by p.category),1) as pct_of_category
from
	products as p 
left join sales_orders as so on p.product_id = so.product_id
group by p.product_name, p.category
order by p.category, product_rank ;

-- LAG backwards, LEAD forward , DATE_TRUNC()
--These answer questions like:

--"How did this month's revenue compare to last month?"
--"What was the growth rate month over month?"
--"Which months were declining?"

--You cannot do this with GROUP BY alone. LAG and LEAD look backwards and forwards across rows.
--LAG — looks at the previous row
--LEAD — looks at the next row

select 
	DATE_TRUNC('month', order_date) as month,
	sum(revenue) as monthly_revenue
FROM
	sales_orders
where status = 'Completed'
group by DATE_TRUNC('month', order_date)
order by month;
-- sales records for 3 years

-- now we'll get the sales from the last 3 years, 
-- and predict 

with monthly as (
	select 
		DATE_TRUNC('month', order_date) as month,
		sum(revenue) as monthly_revenue
	from sales_orders
	where status = 'Completed'
	group by DATE_TRUNC('month', order_date)
), 
with_flags as ( 

select
	month,
	monthly_revenue,
	coalesce(LAG(monthly_revenue) over (order by month),0) as prev_month_revenue,
	coalesce( 
	round((monthly_revenue - LAG(monthly_revenue) over (order by month)) 
	/ LAG(monthly_revenue) over (order by month) * 100, 1),0) as mom_growth_pct,
	case
		when lag(monthly_revenue) over (order by month) is null then 'First Month'
		when monthly_revenue > lag(monthly_revenue) over (order by month) then 'Growth'
		when monthly_revenue < lag(monthly_revenue) over (order by month) then 'Decline'
		else 'Flat'
	end as Growth_Flag
from monthly
)
SELECT
	growth_flag,
	count(*) as total_months,
	EXTRACT(YEAR from month) as month_num
from with_flags
group by growth_flag, EXTRACT(YEAR from month)
order by total_months desc;



--Q:8
--Give me the top 3 customers by
--total revenue in each region, but only include completed orders.
--I want to see their name, tier, region, total revenue, and their rank within that region.

-- totla revenue each region, only completed
-- top 3 customers
-- name, tier, region, total rev, and rank within region

with customer_ranked as (
	SELECT
		sum(so.revenue) as total_revenue,
		c.name,
		c.tier,
		c.region,
		rank() over (partition by c.region  order by sum(so.revenue) desc) as rank_region
FROM
	sales_orders so
left join customers c on so.customer_id = c.customer_id
where so.status = 'Completed'
group by 
	c.name,
	c.tier,
	c.region
) 
select * 
from customer_ranked
where rank_region <= 3
order by region, rank_region


-- practice before python
--Q:1 Give me a full rep performance report showing: total revenue, total orders,
-- completed revenue, cancellation rate, 
-- average order value, and how each rep ranks overall by total revenue. Order by rank."


SELECT
	r.rep_name,
	count(*) as total_orders,
	sum(so.revenue) as total_revenue,
	sum(case when status = 'Completed' then so.revenue else 0 end) as completed_orders_revenue,
	round(count(case when status = 'Cancelled' then 1 end) * 100.0 / count(*), 2) as cancel_pct,
	round(avg(revenue),2) as avg_order,
	rank() over(order by sum(so.revenue)desc) as rank_rep
FROM
	sales_orders so
left join reps r on so.rep_id = r.rep_id
group by r.rep_name
order by total_revenue desc;


--Q:2 
-- "I need a product mix report. For each category 
-- show me: total revenue, number of products in that category,
-- best selling product name, and what percentage of total company revenue that 
-- category represents. Order by revenue descending."

-- total rev, #of products in category, best selling name, and % of revenue. 

with mix_report as ( 
	select
		p.product_name,
		p.category,
		sum(so.revenue) as product_revenue,
		rank() over(partition by p.category order by sum(so.revenue) desc) as category_rank
	from sales_orders so
	left join products p on so.product_id = p.product_id
	group by product_name, p.category
)
select 
	category,
	sum(product_revenue) as category_revenue,
	count(product_name) as num_products,
	max(case when category_rank = 1 then product_name end) as best_seller,
	round(sum(product_revenue) * 100.0 / sum(sum(product_revenue)) over(),1) as pct_of_category
 from
	mix_report
group by category
order by category_revenue;
	


-- reference
select * from sales_orders; --order_id, customer_id, rep_id, product_id, revenue
select * from products; -- product_id, product_name, supplier_id
select * from reps; -- rep_id, rep_name, 
select * from customers; -- customer_id, tier, name, region
select * from suppliers; -- supplier_id





-- CTE refresher

with sales_people as ( 
	select
		rep_name,
		round(avg(revenue),2) as avg_rep_sale
	from
		sales_orders so
	left join reps r on so.rep_id = r.rep_id
	group by 
		rep_name
),
company as (
		select 
			round(avg(revenue),2) as company_avg_rev
			from sales_orders
)
select *
from sales_people
cross join company
where avg_rep_sale > company_avg_rev

---------------------------------------
--Q:2"For each region, find the month that
--had the highest revenue in 2024 only. 
--Show the region, the month, and the revenue for that month."

with monthly as ( 
select
	region, 
	DATE_TRUNC('month', order_date) as month,
	sum(revenue) as total_revenue
from
	sales_orders
where extract(Year from order_date) = 2024
group by region, DATE_TRUNC('month', order_date)

), 
monthly_ranked as (

select
	region, 
	month,
	total_revenue,
	rank() over(partition by region order by total_revenue desc) as month_rank
from monthly
)
select
	region,
	month,
	total_revenue
from monthly_ranked
where month_rank = 1
order by total_revenue desc;
	

-- Q:3 CTE
CTE Exercise 3 — 7 out of 10.
-- Find customers who have placed more than 5 orders AND whose average order 
-- value is above $40,000 MXN. Show their name,
-- tier, region, order count, and average order value. 
-- Order by average order value descending.

SELECT
	c.name,
	c.tier,
	so.region,
	count(*) as total_orders,
	round(avg(revenue),2) as avg_per_trans
FROM 
	sales_orders so
left join customers c on so.customer_id = c.customer_id
group by
	c.name,
	c.tier,
	so.region
HAVING COUNT(*) > 3 AND AVG(revenue) >= 10000
order by total_orders desc;


--Query 3 — Customer Segmentation
--Break down our customer base by tier — VIP, Regular, and New.
--For each tier show: number of unique customers, total
--revenue, average revenue per customer, and cancellation rate. Order by total revenue descending.


SELECT
	tier,
	count(DISTINCT(c.customer_id)) as unique_customers,
	sum(revenue) as total_revenue,
	round(avg(revenue),2) as avg_per_order,
	round(count(case when status = 'Cancelled' then 1 end) *100.0 / count(*),2) as pct_cancel
FROM
	sales_orders so
left join customers c on so.customer_id = c.customer_id
group by tier
order by total_revenue desc;


-- Query 4 — Supplier Performance
-- Your manager asks:
-- I want to know which suppliers are performing best. Show each supplier's name,
-- how many products they supply, total revenue generated from their products, average 
-- days to ship for their orders, and cancellation rate. Order by total revenue descending.
-- This one needs three tables — suppliers, products, and sales_orders. You haven't joined 
-- all three together yet without customers involved.
-- Think about how suppliers connect to sales_orders — it's not direct. You need products
-- as the bridge.

-- Q's: supplier name, how many products they supply, total_rev from products
-- average shipp time, canel rate, order by revenue. 



SELECT
	s.supplier_name,
	count(distinct(p.product_id)) as how_many_products,
	sum(so.revenue) as total_product_rev,
	ROUND(AVG(so.days_to_ship),1) as avg_day_to_ship,
	round(count(case when so.status ='Cancelled' then 1 end) * 100.0 / count(*),2) as pct_cancel
From
	sales_orders so
left join products p on so.product_id = p.product_id
left join suppliers s on p.supplier_id = s.supplier_id 
group by 
	s.supplier_name
order by total_product_rev desc;


-- Query 5 — The Executive Summary. Final query.
-- This is the hardest one — an 8 out of 10. No hand holding.
-- Your CEO walks in and says:
-- "Give me a single report that shows for each year (2022, 2023, 2024): total revenue,
-- total completed revenue, cancellation rate, best performing rep, best performing region,
-- and year over year revenue growth percentage. One row per year."
-- This needs everything you've learned:
-- 
-- DATE extraction for yearly grouping
-- CASE WHEN for completed revenue
-- Cancellation rate calculation
-- Window function for YoY growth with LAG
-- Subquery or CTE to get best rep and region per year
-- Chained CTEs to bring it all together
-- 
-- Before you write anything — break it into steps in plain English. How many 
-- CTEs do you need and what does each one do?

with yearly_base as ( 
select 
	SUM(case when status = 'Completed' then revenue else 0 end) as completed_order,
	sum(revenue) as total_yearly_rev,
	round(count(case when status = 'Cancelled' then 1 end) * 100.0 / COUNT(*),2) as cancel_pct,
	DATE_TRUNC('year', order_date)::DATE as year
FROM
	sales_orders
group by 
	year
), 
	best_rep as (
	select 
		r.rep_name,
		DATE_TRUNC('year', order_date)::DATE as year,
		sum(revenue) as total_rep_rev,
		rank() over(partition by DATE_TRUNC('year', order_date)::DATE order by sum(so.revenue) desc)
	FROM 
		sales_orders so
		left join reps r on so.rep_id = r.rep_id
	group by r.rep_name, DATE_TRUNC('year', order_date)::DATE

), 
best_region as (
	select 
		region,
		DATE_TRUNC('year', order_date)::DATE as year,
		sum(revenue) as total_rep_rev,
		rank() over(partition by DATE_TRUNC('year', order_date)::DATE order by sum(revenue) desc)

	from 
		sales_orders
	group by region,DATE_TRUNC('year', order_date)::DATE;

)




--- completed CTES 4 ctes 

WITH yearly_base AS (
    select 
	SUM(case when status = 'Completed' then revenue else 0 end) as completed_order,
	sum(revenue) as total_yearly_rev,
	round(count(case when status = 'Cancelled' then 1 end) * 100.0 / COUNT(*),2) as cancel_pct,
	DATE_TRUNC('year', order_date)::DATE as year
FROM
	sales_orders
group by 
	year
),
best_rep AS (
    	select 
		r.rep_name,
		DATE_TRUNC('year', order_date)::DATE as year,
		sum(revenue) as total_rep_rev,
		rank() over(partition by DATE_TRUNC('year', order_date)::DATE order by sum(so.revenue) desc)
	FROM 
		sales_orders so
		left join reps r on so.rep_id = r.rep_id
	group by r.rep_name, DATE_TRUNC('year', order_date)::DATE
),
best_region AS (
    	select 
		region,
		DATE_TRUNC('year', order_date)::DATE as year,
		sum(revenue) as total_rep_rev,
		rank() over(partition by DATE_TRUNC('year', order_date)::DATE order by sum(revenue) desc)

	from 
		sales_orders
	group by region,DATE_TRUNC('year', order_date)::DATE
),
yoy_growth AS (
	SELECT
        year,
        total_yearly_rev,
        ROUND((total_yearly_rev - LAG(total_yearly_rev) OVER (ORDER BY year)) 
              / LAG(total_yearly_rev) OVER (ORDER BY year) * 100, 1) AS yoy_growth_pct
    FROM yearly_base
)
-- Final SELECT: JOIN all four on year, filter best_rep rank=1, best_region rank=1
SELECT
    yoy.year,
    yoy.total_yearly_rev,
    yb.completed_order,
    yb.cancel_pct,
    br.rep_name AS best_rep,
    reg.region AS best_region,
    yoy.yoy_growth_pct
FROM yoy_growth yoy
LEFT JOIN yearly_base yb ON yoy.year = yb.year
LEFT JOIN best_rep br ON yoy.year = br.year AND br.rank = 1
LEFT JOIN best_region reg ON yoy.year = reg.year AND reg.rank = 1
ORDER BY yoy.year;


--





-- extra questions 
-- lag in its own cte so you use it in the future
with monthly_rev as ( 
select
	rep_name,
	sum(revenue) as monthly_revenue,
	DATE_TRUNC('month', order_date)::DATE as month
from
	sales_orders so
left join reps r on so.rep_id = r.rep_id
group by
	rep_name, DATE_TRUNC('month', order_date)
order by month desc
),
with_lag as (
	select
		rep_name,
		month,
		monthly_revenue,
		LAG(monthly_revenue) over (partition by rep_name order by month) as prev_month
	from 
		monthly_rev
)
SELECT
	rep_name,
	month,
	monthly_revenue,
	prev_month,
	ROUND((monthly_revenue - prev_month) / prev_month * 100, 1) as mom_growth_pct,
	case
		when prev_month IS NULL then 'First Month' 	
		when monthly_revenue > prev_month then 'Growth'
		when monthly_revenue < prev_month then 'Decline'
		else 'Flat'
	end as growth_flag
from with_lag
order by rep_name, month;
	
	




-- real CTEs analyst write every week in a real job 
-- year 2024 , monthly report of agents and hitting their quota 
WITH monthly_sales as ( 
SELECT
	r.rep_name,
	SUM(so.revenue) as monthly_revenue,
	r.annual_quota,
	DATE_TRUNC('month', order_date)::DATE as month
FROM
	sales_orders so
left join reps r on so.rep_id = r.rep_id
WHERE EXTRACT(YEAR FROM order_date) = 2024
AND so.status = 'Completed'
GROUP BY 
	r.annual_quota,
	DATE_TRUNC('month', order_date),
	r.rep_name
), 
with_running as ( 
	select
		rep_name,
		annual_quota,
		monthly_revenue,
		month,
		SUM(monthly_revenue) over(partition by rep_name order by month) as cumulative_revenue
	FROM
		monthly_sales
)
SELECT
	rep_name, 
	month,
	annual_quota,
	monthly_revenue,
	cumulative_revenue,
	Round(cumulative_revenue * 100.0 / annual_quota , 1) as pct_of_quota,
	CASE
		when cumulative_revenue >= annual_quota then 'Quota Hit'
		when cumulative_revenue >= annual_quota * 0.75 then 'On Track'
		when cumulative_revenue >= annual_quota * 0.50 then 'At Risk'
	    else 'Behind'
	end as quota_status
FROM
	with_running
order by 
	rep_name, month;

-- Is the quota set by the company realistic? 

SELECT 
    r.rep_name,
    r.annual_quota,
    SUM(so.revenue) AS actual_2024,
    ROUND(SUM(so.revenue) * 100.0 / r.annual_quota, 1) AS pct_of_quota
FROM sales_orders so
LEFT JOIN reps r ON so.rep_id = r.rep_id
WHERE EXTRACT(YEAR FROM order_date) = 2024
AND so.status = 'Completed'
GROUP BY r.rep_name, r.annual_quota
ORDER BY pct_of_quota DESC;





-- ntile() ideal for the 80/20 rule analysis,
-- do 25% of our customers drive 75% of revenue? 

with customer_spend as(
select
	c.name,
	c.tier,
	sum(revenue) as total_spend
from 
	sales_orders so
left join customers c on so.customer_id = c.customer_id
where status = 'Completed'
group by 
	c.name,
	c.tier
), 
with_quartile

-- Query 2 — Junior (4/10)
-- Find all completed orders placed in the second half of 2023 (July through December). 
-- Show order ID, date, rep name, product name, and revenue. Order by revenue descending.
-- Clock starts now. Go.


SELECT
	r.rep_name,
	so.order_id,
	so.revenue,
	p.product_name,
	so.order_date	
FROM
	sales_orders so
left join reps r on so.rep_id = r.rep_id 
left join products p on so.product_id = p.product_id 
WHERE so.order_date BETWEEN '2023-07-01' AND '2023-12-31'
AND so.status = 'Completed'
ORDER BY so.revenue desc;
	

-- Query 3 — Junior (4/10)
-- Find all customers who have never placed an order. Show their name, 
-- tier, and region."
-- Hint — this is a classic interview question. You need to 
-- find rows in one table that have NO match in another table.
-- Think about what JOIN type reveals missing matches. You've used it before.
-- Clock starts. Go.

SELECT
	so.order_id as no_order,
	c.name,
	c.tier,
	c.region
FROM
	customers c
left join sales_orders so on c.customer_id = so.customer_id
WHERE so.customer_id IS NULL

-- Query 4 — Junior/Mid (5/10)
-- For each product, show the total number of orders, total revenue, 
-- and the month it had its single best sales month ever. Also show what
-- that best month's revenue was.
-- This needs aggregation at two levels — overall product totals AND 
-- finding the peak month per product.
-- Think about your structure before writing. How many CTEs do you need?





-- 3 ctes 
WITH product_summary AS ( 

SELECT
	sum(revenue) as total_revenue,
	p.product_name,
	DATE_TRUNC('month', order_date)::DATE as month
	
FROM
	sales_orders so
left join products p on so.product_id = p.product_id
group by p.product_name, DATE_TRUNC('month', order_date)

),

 monthly_performance AS (

SELECT 
	total_revenue,
	product_name,
	month,
	ROW_NUMBER() OVER(PARTITION BY product_name order by total_revenue desc) 
	as row_number_month
	
FROM 
	product_summary

),

product_totals as (
	SELECT 
		p.product_name,
		COUNT(*) as total_orders,
		SUM(revenue) as all_time_revenue
	FROM 
		sales_orders so
	left join products p on so.product_id = p.product_id
	group by product_name	
)


SELECT
	mp.product_name,
	pt.total_orders,
	pt.all_time_revenue,
	mp.month as best_month,
	mp.total_revenue as best_month_revenue
from monthly_performance mp
left join product_totals pt on mp.product_name = pt.product_name
WHERE mp.row_number_month = 1
order by pt.all_time_revenue desc;


-- Query 5 — Mid (6/10)
-- For each rep, calculate their monthly revenue for 2023 and flag any month where 
-- their revenue dropped more than 20% compared to their previous month.
-- Show rep name, month, revenue, previous month revenue, the drop percentage,
-- and the flag.
-- This is a real operations query — detecting significant performance drops 
-- automatically. No manual scanning needed.
-- Think about your CTE structure before writing. How many steps?


-- this ia an early warning system to rep performance, warning if they drop 20% in sales. 
WITH monthly_performance AS (

SELECT
	r.rep_name,
	SUM(so.revenue) as monthly_revenue,
	DATE_TRUNC('month', order_date)::DATE as month
FROM 
	sales_orders so 
left join reps r on so.rep_id = r.rep_id
WHERE EXTRACT(YEAR FROM order_date) = 2023
GROUP BY
	DATE_TRUNC('month', order_date), r.rep_name
),
monthly_drop AS (
	SELECT
		rep_name,
		month,
		monthly_revenue,
		LAG(monthly_revenue) OVER(partition by rep_name order by month) as prev_month_rev

	FROM 
		monthly_performance

)
SELECT
	rep_name,
	month,
	monthly_revenue,
	prev_month_rev,
	ROUND((monthly_revenue - prev_month_rev) * 100.0 / prev_month_rev ,1) as growth_decline_pct,
	CASE
		WHEN prev_month_rev IS NULL then 'First Month'
		-- percent of something → (new - old) / old * 100 logic                  
		WHEN (monthly_revenue - prev_month_rev) / prev_month_rev * 100.0 < -20 then 'Drop_20_pct'
		WHEN monthly_revenue < prev_month_rev THEN 'Decline'
		ELSE 'Growth'
	END AS flag_rep
FROM
	monthly_drop


-- Query 6 — Mid (6/10)
-- Find the top 3 most valuable customers for each rep — based on completed revenue only.
-- Show rep name, customer name, customer tier, total completed revenue from that customer,
-- and their rank within that rep's portfolio. Order by rep name then rank.
-- This is a classic top-N per group question. You know the pattern — rank within groups, 
-- filter where rank <= 3.



WITH customer_names AS ( 

SELECT
	sum(revenue) as total_revenue,
	r.rep_name,
	c.name,
	c.tier
FROM
	sales_orders so
left join reps r on so.rep_id = r.rep_id
left join customers c on so.customer_id = c.customer_id
WHERE so.status = 'Completed'
group by 
	r.rep_name,
	c.name,
	c.tier
),
	customer_rank as (
	SELECT
		rep_name,
		name,
		tier,
		total_revenue,
		rank() over(partition by rep_name order by total_revenue desc) as rank_cust
	FROM
		customer_names
)
	SELECT
		rep_name,
			name,
			tier,
			total_revenue,
			rank_cust
		FROM
		customer_rank
		where rank_cust <= 3 
	


-- Query 7 — Mid (7/10)
-- Calculate the 3-month moving average of revenue for each region. 
-- Show the region, month, actual monthly revenue, and the 3-month moving average side by side. 
-- Filter to 2024 only. Flag months where actual revenue is below the moving average as 'Below Trend'
-- and above as 'Above Trend'

WITH monthly_rev AS (

select 
	region,
	SUM(revenue) as monthly_revenue,
	DATE_TRUNC('month', order_date)::DATE as month
FROM
	sales_orders
WHERE EXTRACT(YEAR FROM order_date) = 2024
group by
	region,
	DATE_TRUNC('month', order_date)::DATE 
			
),
mbm_rollover as (
	select 
		region,
		monthly_revenue,
		month,
		ROUND(AVG(monthly_revenue) over(
		partition by region 
		ORDER by month
		ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
		),2) as moving_avg_3months 
	FROM monthly_rev
)
SELECT 
	region,
		monthly_revenue,
		month,
		moving_avg_3months,
		CASE 
			WHEN monthly_revenue > moving_avg_3months THEN 'Above Trend'
			WHEN monthly_revenue < moving_avg_3months THEN 'Below Trend'
			ELSE 'on Trend'
		END AS trend_flag
FROM
	mbm_rollover;


-- Query 8 — Hard (7/10)
-- For each supplier, show their products, total revenue, cancellation rate, and compare their 
-- cancellation rate against the company average cancellation rate. Flag suppliers performing 
-- worse than average as 'High Risk'. Order by cancellation rate descending.
-- Three tables: suppliers, products, sales_orders. Company average cancellation rate needs
-- a separate CTE.

WITH supplier_info AS ( 
SELECT
	p.product_name,
	s.supplier_name,
	SUM(revenue) as total_revenue,
	ROUND(COUNT(CASE WHEN so.status = 'Cancelled' THEN 1 END)
					* 100.0 / COUNT(*), 2) as supplier_cancel_rate
FROM
	sales_orders so
left join products p on so.product_id = p.product_id
left join suppliers s on p.supplier_id = s.supplier_id
group by
	p.product_name,
	s.supplier_name
),
company_avg AS ( -- the is the whole table average, no group by, or just one agg funct. 
SELECT 
	ROUND(COUNT(CASE WHEN status = 'Cancelled' THEN 1 END) * 100.0 / COUNT(*), 2) as cancel_pct
FROM
	sales_orders
)
	SELECT
		si.product_name,
		si.supplier_name,
		si.total_revenue,
		si.supplier_cancel_rate,
		ca.cancel_pct as company_avg_rate,
		CASE	 -- new     old     old  * 100 
			WHEN si.supplier_cancel_rate > ca.cancel_pct THEN 'High Risk'
			ELSE 'OK'
		END AS flag_supplier
	FROM
		supplier_info si
	CROSS JOIN
		company_avg ca
	ORDER BY 
		si.supplier_cancel_rate desc;

--Query 9 — Hard (8/10)
-- Create a customer loyalty report. For each customer show:
-- their name, tier, total orders, 
-- total revenue, their first order date, their most recent order date, how many days between
-- their first and last order (their active lifespan), and classify them as 'Loyal'
-- (ordered in at least 3 different months), 'Returning' (ordered in 2 different months), or 
-- 'One-Time' (only ordered in 1 month). Order by total revenue descending. Show only the top 20.
-- This needs:
-- MIN and MAX on dates
-- Date arithmetic for lifespan
-- COUNT DISTINCT on months for loyalty classification
-- No window functions needed — pure aggregation


SELECT 	
	c.name,
	c.tier,
	SUM(revenue) as total_revenue,
	count(*) as total_orders,
	MIN(so.order_date) as first_order,
	MAX(so.order_date) as last_order,
	MAX(order_date) - MIN(order_date) as active_days,
	COUNT(DISTINCT DATE_TRUNC('month', order_date)) as months_active,
	CASE
		WHEN COUNT(DISTINCT DATE_TRUNC('month', order_date)) >= 3 THEN 'Loyal' 
		WHEN COUNT(DISTINCT DATE_TRUNC('month', order_date)) = 2 THEN 'Returning'
		ELSE 'One-Time'
	END AS loyalty_status
FROM
	sales_orders so
LEFT JOIN customers c on so.customer_id = c.customer_id
GROUP BY
	c.name, c.tier
order by 
	total_revenue DESC
LIMIT 20;

--Query 10 — Hard (8/10). Final query.
--This is your graduation query. No hints unless you're completely stuck.
--"Build a complete rep performance scorecard for 2024. For each rep show:

--Total revenue and rank among all reps
--Completed revenue and completion rate
--Cancellation rate
--Average order value
--Their best single month and that month's revenue
--Month over month revenue trend — were they growing or declining in
-- the second half of 2024 (July-December)?
--Quota attainment % (use annual_quota from reps table)
--Final grade: A (quota >= 80%), B (>= 60%), C (>= 40%), F (below 40%)

--Order by total revenue descending."
--This combines everything — JOINs, aggregations, CASE WHEN, window functions,
-- CTEs, date filtering, and business calculations.
--Budget: 30 minutes. This is a real take-home interview question.

-- ================================================================
-- REP PERFORMANCE SCORECARD 2024
-- ================================================================

WITH rep_annual_stats AS (
    -- CTE 1: Annual totals, rates, and quota attainment per rep
    SELECT
        r.rep_name,
        r.annual_quota,
        SUM(so.revenue)                                                          AS total_revenue,
        SUM(CASE WHEN so.status = 'Completed' THEN so.revenue ELSE 0 END)       AS completed_revenue,
        ROUND(COUNT(CASE WHEN so.status = 'Completed' THEN 1 END) * 100.0 
              / COUNT(*), 1)                                                      AS completion_rate,
        ROUND(COUNT(CASE WHEN so.status = 'Cancelled' THEN 1 END) * 100.0 
              / COUNT(*), 1)                                                      AS cancel_rate,
        ROUND(AVG(so.revenue), 2)                                                AS avg_order_value,
        ROUND(SUM(CASE WHEN so.status = 'Completed' THEN so.revenue ELSE 0 END) 
              * 100.0 / r.annual_quota, 1)                                       AS quota_attainment_pct
    FROM sales_orders so
    LEFT JOIN reps r ON so.rep_id = r.rep_id
    WHERE EXTRACT(YEAR FROM so.order_date) = 2024
    GROUP BY r.rep_name, r.annual_quota
),

rep_monthly AS (
    -- CTE 2: Monthly revenue per rep for 2024
    SELECT
        r.rep_name,
        DATE_TRUNC('month', so.order_date)::DATE AS month,
        SUM(so.revenue)                           AS monthly_revenue
    FROM sales_orders so
    LEFT JOIN reps r ON so.rep_id = r.rep_id
    WHERE EXTRACT(YEAR FROM so.order_date) = 2024
    GROUP BY r.rep_name, DATE_TRUNC('month', so.order_date)
),

best_month AS (
    -- CTE 3: Best single revenue month per rep
    -- Step 1: rank months within each rep
    SELECT
        rep_name,
        month            AS best_month,
        monthly_revenue  AS best_month_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY rep_name 
            ORDER BY monthly_revenue DESC
        ) AS rn
    FROM rep_monthly
),

h2_with_lag AS (
    -- CTE 4a: Add LAG to monthly data for H2 2024 only
    SELECT
        rep_name,
        month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY rep_name 
            ORDER BY month
        ) AS prev_month_revenue
    FROM rep_monthly
    WHERE month >= '2024-07-01'
),

h2_trend AS (
    -- CTE 4b: Flag each H2 month as Growth or Decline
    -- then summarize per rep
    SELECT
        rep_name,
        COUNT(CASE WHEN monthly_revenue > prev_month_revenue THEN 1 END) AS growth_months,
        COUNT(CASE WHEN monthly_revenue < prev_month_revenue THEN 1 END) AS decline_months,
        CASE
            WHEN COUNT(CASE WHEN monthly_revenue > prev_month_revenue THEN 1 END) >
                 COUNT(CASE WHEN monthly_revenue < prev_month_revenue THEN 1 END)
            THEN 'Growing'
            WHEN COUNT(CASE WHEN monthly_revenue > prev_month_revenue THEN 1 END) 
                 COUNT(CASE WHEN monthly_revenue < prev_month_revenue THEN 1 END)
            THEN 'Declining'
            ELSE 'Flat'
        END AS h2_trend
    FROM h2_with_lag
    WHERE prev_month_revenue IS NOT NULL
    GROUP BY rep_name
)

-- ================================================================
-- FINAL SELECT: Join everything together
-- ================================================================
SELECT
    ras.rep_name,

    -- Revenue metrics
    ras.total_revenue,
    RANK() OVER (ORDER BY ras.total_revenue DESC)  AS revenue_rank,
    ras.completed_revenue,
    ras.completion_rate,
    ras.cancel_rate,
    ras.avg_order_value,

    -- Best month
    bm.best_month,
    bm.best_month_revenue,

    -- H2 trend
    ht.growth_months,
    ht.decline_months,
    ht.h2_trend,

    -- Quota
    ras.annual_quota,
    ras.quota_attainment_pct,
    CASE
        WHEN ras.quota_attainment_pct >= 80 THEN 'A'
        WHEN ras.quota_attainment_pct >= 60 THEN 'B'
        WHEN ras.quota_attainment_pct >= 40 THEN 'C'
        ELSE 'F'
    END AS grade

FROM rep_annual_stats ras

-- Join best month (filter to rank 1 only)
LEFT JOIN best_month bm 
    ON ras.rep_name = bm.rep_name 
    AND bm.rn = 1

-- Join H2 trend
LEFT JOIN h2_trend ht 
    ON ras.rep_name = ht.rep_name

ORDER BY ras.total_revenue DESC;




-- top 15 SQl questions for jerbs (Indian girl)
-- work on postgreSQL, MySQL, BigQuerym Snowflake, and SQL Server


--1 . what is the differenve between DMRMS (database management sytem) and RDMBMS (relational database managment) ? 
-- DBMS - basic way to store data in files, no structure, no relationships, no querying language, just a place to put data.
-- RDBMS - relational database management system, data is stored in tables with defined relationships, security, multiple users, large datasets. 
-- and a powerful querying language (SQL) to retrieve and manipulate data. Examples include MySQL, PostgreSQL, SQL Server, Oracle, etc.



--2. what is a primary and a foreign key ?
-- primary key - a unique identifier for each record in a table, ensures that each record can be uniquely identified.
-- foreign key - a field in one table that refers to the primary key in another table, establishes a relationship between the two tables, 
-- enforces referential integrity by ensuring 
-- that the value in the foreign key field matches a valid primary key value in the related table.            



--3 constraints ? and their types ?
-- constraints are rules that are applied to the columns of a table to enforce data integrity and consistency.
-- types of constraints include: PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, CHECK, and DEFAULT.
-- PRIMARY KEY - ensures that each record has a unique identifier and cannot be null.
-- FOREIGN KEY - establishes a relationship between two tables and ensures referential integrity.
-- UNIQUE - ensures that all values in a column are unique.
-- NOT NULL - ensures that a column cannot have null values.
-- CHECK - ensures that all values in a column satisfy a specific condition.
-- DEFAULT - provides a default value for a column when no value is specified.

--4. what is DDL and DMl commands in SQL ?
-- DDL (Data Definition Language) commands are used to define and manage the structure of a database, including creating, altering, and dropping tables and 
-- other database objects. Examples include CREATE, ALTER, DROP, TRUNCATE.
-- DML (Data Manipulation Language) commands are used to manipulate the data within the database, including inserting, updating, deleting, and retrieving data.
-- Examples include SELECT, INSERT, UPDATE, DELETE. 

-- 5. difference between delete, drop, and truncate ? 
-- DELETE - removes rows from a table based on a condition, can be rolled back, and triggers any associated delete triggers.
-- DROP - removes an entire table or database, including its structure and data, cannot be rolled back, and will trigger any associated drop triggers.
-- TRUNCATE - removes all rows from a table, but keeps the structure intact, cannot be rolled back, and does not trigger delete triggers. 
-- It is faster than DELETE for large tables because it does not log individual row deletions.

-- 6 Differentiate Group BY and Order BY ? 
-- GROUP BY - is used to group rows that have the same values in specified columns into summary rows, often used with aggregate functions like COUNT, SUM, AVG, etc.
-- ORDER BY - is used to sort the result set of a query by one or more columns, in ascending (ASC) or descending (DESC) order. It does not group data, but simply sorts the output. 

-- 7. Differntiate between WHERE and HAVING clause ?
-- WHERE - is used to filter rows before any grouping takes place, it cannot be used with aggregate functions.
-- HAVING - is used to filter groups after the GROUP BY clause has been applied, it can be used with aggregate functions to filter groups based on aggregate values.

-- 8. What are aggregate functions in SQl and give examples ?
-- Aggregate functions perform calculations on a set of values and return a single value. Examples include: COUNT(), SUM(), AVG(), MAX(), MIN().
-- COUNT() - returns the number of rows that match a specified condition.
-- SUM() - returns the total sum of a numeric column.
-- AVG() - returns the average value of a numeric column.
-- MAX() - returns the maximum value in a column.
-- MIN() - returns the minimum value in a column.

-- 9. Explain Indexing in SQL and what is clustered Index?
-- Indexing is a database optimization technique that improves the speed of data retrieval operations on a table by creating a data structure (index) 
-- that allows for faster searching and sorting.
-- A clustered index determines the physical order of data in a table, meaning that the rows are stored on disk in the same 
--order as the clustered index. Each table can have only one clustered index, and it is typically created on the primary key column.

-- 10 What is Normalization and explain different types of normal forms?
-- Normalization is the process of organizing data in a database to reduce redundancy and improve data integrity. It involves dividing a database into tables and defining relationships between them.
-- Different types of normal forms include:
-- First Normal Form (1NF): Ensures that each column contains atomic values and eliminates repeating groups.
-- Second Normal Form (2NF): Builds upon 1NF and eliminates partial dependencies.
-- Third Normal Form (3NF): Builds upon 2NF and eliminates transitive dependencies.
-- Boyce-Codd Normal Form (BCNF): A stronger version of 3NF that eliminates all functional dependencies.
-- Fourth Normal Form (4NF): Eliminates multi-valued dependencies.
-- Fifth Normal Form (5NF): Eliminates join dependencies.


-- 11. differnce between union and union all ?
-- UNION - combines the result sets of two or more SELECT statements and removes duplicate rows from the result set.
-- UNION ALL - combines the result sets of two or more SELECT statements but does not remove duplicate rows, it returns all rows from the combined result set.

-- 12. find second highest salary in a table ?
-- Method 1: Using Subquery
SELECT MAX(salary) AS second_highest_salary
FROM employees
WHERE salary < (SELECT MAX(salary) FROM employees);


-- Method 2: Using ORDER BY and LIMIT
SELECT salary AS second_highest_salary
FROM employees
ORDER BY salary DESC
LIMIT 1 OFFSET 1;   


-- 13 what are views in sql, and give an example ?
-- A view in SQL is a virtual table that is based on the result set of a SELECT query. It does not store data itself but provides a way to simplify complex queries, enhance security by restricting access to specific columns or rows, and present data in a specific format.
-- Example: 
CREATE VIEW employee_view AS 
SELECT employee_id, first_name, last_name, department 
FROM employees
WHERE salary < 20000; -- or whatever

-- 14. how can we convert a text into Date format  such as '20-11-2024'?
-- In SQL, you can use the STR_TO_DATE function (in MySQL) or TO_DATE function (in PostgreSQL) to convert a text string into a date format.
-- MySQL example:
SELECT STR_TO_DATE('20-11-2024', '%d-%m-%Y') AS converted_date;

-- PostgreSQL example:
SELECT TO_DATE('20-11-2024', 'DD-MM-YYYY') AS converted_date;       


-- 15. what triggers are in SQL and give an example ?
-- A trigger in SQL is a database object that automatically executes a specified action in response to certain events on a particular table or view. 
-- Triggers can be used to enforce business rules, maintain data integrity, and perform auditing tasks.
-- Example:
CREATE TRIGGER employee_insert_trigger
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    -- Trigger logic here
END;        





