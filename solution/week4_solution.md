## A. Customer Nodes Exploration
1. How many unique nodes are there on the Data Bank system?
```
select COUNT(distinct(node_id))
from data_bank.customer_nodes
# 5 unique nodes
```
2. What is the number of nodes per region?
```
select cn.region_id, region_name, COUNT(distinct(node_id)) number_of_node
from data_bank.customer_nodes cn
	join data_bank.regions r on cn.region_id = r.region_id
GROUP BY cn.region_id, region_name;
# each country have the same 5 nodes
```

3. How many customers are allocated to each region?
```
select r.region_id, r.region_name, count(distinct(customer_id))
from data_bank.customer_nodes cn
	join data_bank.regions r on cn.region_id = r.region_id
group by r.region_id, r.region_name
```
4. How many days on average are customers reallocated to a different node?
```
with cte as (
	select customer_id, node_id, start_date,
		case 
			when lag(node_id) over(partition by customer_id) = node_id then null
			else lag(start_date) over(partition by customer_id) 
			end as prev_start_date
	from data_bank.customer_nodes cn), -- if spot a different node by each customer add the start_day before else it's null 
cte1 as (
	select *, if(prev_start_date is null, 0, datediff(start_date, prev_start_date)) as average
	from cte
	where prev_start_date is not null) -- if prev day exists, calculate the day diff of the present and the previous start_date
select concat(round(avg(average), 1), ' days') average_days_reallocated_node
from cte1

# 15.6 days
```
5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
```
with cte as (
	select customer_id, node_id, start_date, region_id,
		case 
			when lag(node_id) over(partition by customer_id) = node_id then null
			else lag(start_date) over(partition by customer_id) 
			end as prev_start_date
	from data_bank.customer_nodes cn), 
cte1 as (
	select *, if(prev_start_date is null, 0, datediff(start_date, prev_start_date)) as diff
	from cte
	where prev_start_date is not null),
rcount as (
	select region_id, count(*) as median_region
    from cte1
    group by region_id
    order by region_id), -- rcount to count total number of the day has changed located to different node,
rid as (
	select cte1.region_id, diff, row_number() over(partition by region_id order by diff) row_idx, median_region
	from cte1
		join rcount on cte1.region_id = rcount.region_id
	order by region_id, diff), -- rid to mark row index and order the day diff to get percentile by the total (ex: if we need the 25th we use total*0.25)
med as (
	select region_id, avg(diff) 'median'
	from rid
	where row_idx = floor(median_region*0.5) or row_idx = ceil(median_region*0.5)
	group by region_id
),
eighty as (
	select region_id, avg(diff) 'percentile_80th'
	from rid
	where row_idx = floor(median_region*0.8) or row_idx = ceil(median_region*0.8)
	group by region_id ),
ninetyfive as (
	select region_id, avg(diff) 'percentile_95th'
	from rid
	where row_idx = floor(median_region*0.95) or row_idx = ceil(median_region*0.95)
	group by region_id
)
select m.region_id, median, e.percentile_80th, percentile_95th 
	from med m
		join eighty e on m.region_id = e.region_id
        join ninetyfive n on m.region_id = n.region_id 
```

## B. Customer Transactions
1. What is the unique count and total amount for each transaction type?
2. What is the average total historical deposit counts and amounts for all customers?
3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
4. What is the closing balance for each customer at the end of the month?
5. What is the percentage of customers who increase their closing balance by more than 5%?

## C. Data Allocation Challenge
To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

+ Option 1: data is allocated based off the amount of money at the end of the previous month
+ Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
+ Option 3: data is updated real-time
For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

+ running customer balance column that includes the impact each transaction
+ customer balance at the end of each month
+ minimum, average and maximum values of the running balance for each customer
Using all of the data available - how much data would have been required for each option on a monthly basis?

## D. Extra Challenge
Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?

Special notes:

+ Data Bank wants an initial calculation which does not allow for compounding interest, however they may also be interested in a daily compounding interest calculation so you can try to perform this calculation if you have the stamina!
## Extension Request
The Data Bank team wants you to use the outputs generated from the above sections to create a quick Powerpoint presentation which will be used as marketing materials for both external investors who might want to buy Data Bank shares and new prospective customers who might want to bank with Data Bank.

1. Using the outputs generated from the customer node questions, generate a few headline insights which Data Bank might use to market it’s world-leading security features to potential investors and customers.

2. With the transaction analysis - prepare a 1 page presentation slide which contains all the relevant information about the various options for the data provisioning so the Data Bank management team can make an informed decision.