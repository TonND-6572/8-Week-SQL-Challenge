## A. Customer Journey
Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey. 

Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

***Ans***: This is a journey of customers that subcribe to any plans. Beside trial plan, any plan that have their own price. Each customer can change a plan to another plan at a specific time.

**Example query**: 
```
SELECT s.*, p.plan_name, p.price
FROM subscriptions s
    JOIN plans p ON s.plan_id = p.plan_id
WHERE customer_id < 8
```

## B. Data Analysis Questions
How many customers has Foodie-Fi ever had?
```
SELECT COUNT(DISTINCT(customer_id))
FROM subscriptions
```

What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value?
```
SELECT MONTH(start_date), COUNT(*)
FROM subscriptions
WHERE plan_id = 0
GROUP BY MONTH(start_date)
ORDER BY MONTH(start_date)
```

What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name?
```
SELECT p.plan_name, COUNT(*)
FROM subscriptions s
    JOIN plans p ON s.plan_id = p.plan_id
WHERE YEAR(start_date) > 2020
GROUP BY plan_name
```

What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
```
SELECT 
    SUM(plan_id = 4) as customer_count, 
    ROUND(SUM(plan_id = 4)*100 / COUNT(*), 1) churn_percentage
FROM subscriptions s
```

How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
```
WITH Q AS (
    SELECT DISTINCT customer_id
    FROM subscriptions
    WHERE plan_id BETWEEN 1 AND 3
)
SELECT SUM(Q.customer_id IS NULL AND plan_id = 4) num_customer, 
    SUM(Q.customer_id IS NULL AND plan_id = 4)*100 / COUNT(DISTINCT s.customer_id) percentage
FROM subscriptions s
    LEFT JOIN Q ON s.customer_id = Q.customer_id
```

What is the number and percentage of customer plans after their initial free trial?
```
select 
    sum(not s.plan_id = 0) number_plans, 
    sum(s.plan_id = 0)*100 / count(*) percentage_plan
from subscriptions s
```

What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
```
select plan_id, 
    count(*) total_count, 
    count(*)*100 / sum(count(*)) over() as percentage
from subscriptions
where start_date = '2020-12-31'
GROUP BY plan_id
```

How many customers have upgraded to an annual plan in 2020?
```
select count(*) number_customer_upgraded_annual
from subscriptions s
    join plans p on s.plan_id = p.plan_id
where plan_name LIKE '%annual%' and YEAR(start_date) = 2020
```

How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
```
with cte as(
    select customer_id, start_date
    from subscriptions
    where plan_id = 0
)
select CONCAT(SUM(DATEDIFF(t.start_date, cte.start_date))/COUNT(*), ' days') average_date_to_upgrade_trial_to_annual
from cte
    JOIN (SELECT customer_id, start_date from subscriptions where plan_id = 3) t 
        ON cte.customer_id = t.customer_id
```
Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
```
with cte as(
    select customer_id, start_date
    from subscriptions
    where plan_id = 0
)
select SUM(DATEDIFF(t.start_date, cte.start_date) / 30)/COUNT(*) average_date_to_upgrade_trial_to_annual
from cte
    JOIN (SELECT customer_id, start_date from subscriptions where plan_id = 3) t 
        ON cte.customer_id = t.customer_id
```

How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
```
select count(*)
from subscriptions s
where plan_id = 1 and YEAR(start_date) = 2020
```

## C. Challenge Payment Question
The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

- monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
- upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
- upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
- once a customer churns they will no longer make payments

Example outputs for this table might look like the following:

| customer_id 	| plan_id 	| plan_name     	| payment_date 	| amount 	| payment_order 	|
|-------------	|---------	|---------------	|--------------	|--------	|---------------	|
| 1           	| 1       	| basic monthly 	| 2020-08-08   	| 9.90   	| 1             	|
| 1           	| 1       	| basic monthly 	| 2020-09-08   	| 9.90   	| 2             	|
| 1           	| 1       	| basic monthly 	| 2020-10-08   	| 9.90   	| 3             	|
| 1           	| 1       	| basic monthly 	| 2020-11-08   	| 9.90   	| 4             	|
| 1           	| 1       	| basic monthly 	| 2020-12-08   	| 9.90   	| 5             	|
| 2           	| 3       	| pro annual    	| 2020-09-27   	| 199.00 	| 1             	|
| 13          	| 1       	| basic monthly 	| 2020-12-22   	| 9.90   	| 1             	|
| 15          	| 2       	| pro monthly   	| 2020-03-24   	| 19.90  	| 1             	|
| 15          	| 2       	| pro monthly   	| 2020-04-24   	| 19.90  	| 2             	|
| 16          	| 1       	| basic monthly 	| 2020-06-07   	| 9.90   	| 1             	|
| 16          	| 1       	| basic monthly 	| 2020-07-07   	| 9.90   	| 2             	|
| 16          	| 1       	| basic monthly 	| 2020-08-07   	| 9.90   	| 3             	|
| 16          	| 1       	| basic monthly 	| 2020-09-07   	| 9.90   	| 4             	|
| 16          	| 1       	| basic monthly 	| 2020-10-07   	| 9.90   	| 5             	|
| 16          	| 3       	| pro annual    	| 2020-10-21   	| 189.10 	| 6             	|
| 18          	| 2       	| pro monthly   	| 2020-07-13   	| 19.90  	| 1             	|
| 18          	| 2       	| pro monthly   	| 2020-08-13   	| 19.90  	| 2             	|
| 18          	| 2       	| pro monthly   	| 2020-09-13   	| 19.90  	| 3             	|
| 18          	| 2       	| pro monthly   	| 2020-10-13   	| 19.90  	| 4             	|
| 18          	| 2       	| pro monthly   	| 2020-11-13   	| 19.90  	| 5             	|
| 18          	| 2       	| pro monthly   	| 2020-12-13   	| 19.90  	| 6             	|
| 19          	| 2       	| pro monthly   	| 2020-06-29   	| 19.90  	| 1             	|
| 19          	| 2       	| pro monthly   	| 2020-07-29   	| 19.90  	| 2             	|
| 19          	| 3       	| pro annual    	| 2020-08-29   	| 199.00 	| 3             	|

