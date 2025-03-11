/*    SALES ANALYSIS  */


select * from gold.gold_dim_customers;
select * from gold.gold_dim_products;
select * from gold.gold_fact_sales;

# Analyze how a measure evolves over time
#1.sum of sales based on over year and month
select 
     year(order_date) as year,
     month(order_date) as month,
     sum(sales_amount) as order_sales,
     count(distinct customer_key) as no_of_customer,
     sum(quantity) as total_quantity
     from gold.gold_fact_sales
     where  year(order_date) is not null
     group by  year(order_date), month(order_date)
     order by  year(order_date), month(order_date) ;

#cummulative analysis
#1.calculate the total sales by month and the running total of sales over time
select
order_year,
total_sales,
sum(total_sales) over(partition by order_year order by order_year) as sales_running_total 
from
(select 
extract(year_month from order_date)as order_year,
sum(sales_amount) as total_sales
from 
gold.gold_fact_sales
where order_date is not null
group by order_year
) as t;

#2.running total of average price and total sales over year
select
order_year,
total_sales,
avg_price,
sum(total_sales) over(partition by order_year order by order_year) as sales_running_total,
avg(avg_price) over(order by  avg_price) as avg_price_running_total
from
(select 
extract(year from order_date)as order_year,
sum(sales_amount) as total_sales,
avg(price) as avg_price
from 
gold.gold_fact_sales
where order_date is not null
group by order_year
) as t
order by order_year;


#Performance Analysis
#1.analyse the yearly performance of products  by comparing their sales to both the average sales performance of the product and previous years salea.
with yearly_product_sales as 
(select
year(f.order_date) as order_year,
p.product_name as productName,
sum(f.sales_amount) as current_sales
from
gold.gold_fact_sales as f
left join
gold.gold_dim_products as p
on
f.product_key = p.product_key
where year(f.order_date) is not null
group by year(f.order_date),p.product_name
order by year(f.order_date) )

select 
order_year,
productName,
current_sales,
lag(current_sales) over(partition by productName order by order_year) as py_change,
current_sales-lag(current_sales) over(partition by productName order by order_year) as py_diff,
case
when current_sales-lag(current_sales) over(partition by productName order by order_year) > 0 then 'increase'
when current_sales-lag(current_sales) over(partition by productName order by order_year) < 0 then 'decrease'
else 'no change'
end as about_py_diff,
avg(current_sales) over(partition by productName) as avg_sales,
current_sales-avg(current_sales) over(partition by productName) as avg_diff,
case 
when current_sales-avg(current_sales) over(partition by productName) > 0 then 'above avg'
when current_sales-avg(current_sales) over(partition by productName) < 0 then 'below avg'
else 'avg'
end as avg_change
from 
yearly_product_sales
order by productName,order_year;

#proportional analysis
#1.which category contributes the most to overall sales 
with category_sales as (
select
p.category as category,
sum(f.sales_amount) as total_sales
from
gold.gold_fact_sales as f
left join
gold.gold_dim_products as p
on f.product_key=p.product_key
group by p.category)

select
category,
total_sales,
#sum(total_sales) over() as overall_sales,
concat(round((cast(total_sales as float) / sum(total_sales) over()) *100),'%')  as overall_percentage
from
category_sales
order by total_sales desc;

#segmentation
#1.segment products into cost ranges and count how many products fall into each segment
with range_of_cost as (select
product_key,
product_id,
product_name,
cost,
case
when cost <100 then 'below 100'
when cost between 100 and 500 then '100-500'
when cost between 500 and 1000 then '500-1000'
else 'above 1000'
end cost_range
from
gold.gold_dim_products)

select 
cost_range,
count(product_id) as product_count
from
range_of_cost
group by cost_range;

/*2.group customers into 3 segments based on their spending behaviour
    -VIP: with atleast 12 months of history and spending more than 5,000
    -regular: with atleast 12 months of history and spending less than 5,000
    -new:customers with lifespan less than 12 months
And find the total number of customers in each group
*/
with customer_spending as (select
c.customer_key,
sum(f.sales_amount) as total_spending,
timestampdiff(month,min(order_date), max(order_date)) as lifespan
from
gold.gold_fact_sales as f
left join
gold.gold_dim_customers as c
on
f.customer_key=c.customer_key
group by c.customer_key)

select
segment,
count(customer_key) as total_customers
from
(select
customer_key,
total_spending,
lifespan,
case
when lifespan >= 12 and total_spending > 5000 then 'VIP'
when lifespan >= 12 and total_spending <= 5000 then 'regular'
else 'new customer'
end as segment
from customer_spending) t
group by segment 
order by count(customer_key) desc

















 









