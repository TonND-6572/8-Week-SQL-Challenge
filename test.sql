use data_bank;
# 4. How many days on average are customers reallocated to a different node?
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
    order by region_id),
rid as (
	select cte1.region_id, diff, row_number() over(partition by region_id order by diff) row_idx, median_region
	from cte1
		join rcount on cte1.region_id = rcount.region_id
	order by region_id, diff),
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
select m.region_id, median, e.th80, n.th95 
	from med m
		join eighty e on m.region_id = e.region_id
        join ninetyfive n on m.region_id = n.region_id 
