USE pizza_runner;

-- Sameple query
SELECT
	runners.runner_id,
    runners.registration_date,
	COUNT(DISTINCT runner_orders.order_id) AS orders
FROM pizza_runner.runners
INNER JOIN pizza_runner.runner_orders
	ON runners.runner_id = runner_orders.runner_id
WHERE runner_orders.cancellation IS NOT NULL
GROUP BY
	runners.runner_id,
    runners.registration_date;

-- A. Pizza Metrics
-- 1. How many pizzas were ordered? 
SELECT 
    COUNT(DISTINCT pizza_id) 'pizza counts' 
FROM customer_orders;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) FROM customer_orders;

-- 3. How many successful orders were delivered by each runner?
SELECT 
    runners.runner_id, 
    COUNT(DISTINCT order_id) as 'num of successful orders'
FROM runner_orders
    JOIN runners 
        ON runners.runner_id = runner_orders.runner_id 
WHERE pickup_time IS NOT NULL
GROUP BY runners.runner_id
;

-- 4.How many of each type of pizza was delivered?
SELECT 
    pizza_name,
    COUNT(DISTINCT order_id) as pizza_delivered
FROM customer_orders co
    JOIN pizza_names pn
        ON co.pizza_id = pn.pizza_id 
GROUP BY co.pizza_id, pizza_name
;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
    customer_id,
    pizza_name,
    COUNT(DISTINCT order_id) as pizza_delivered
FROM customer_orders co
    JOIN pizza_names pn
        ON co.pizza_id = pn.pizza_id 
GROUP BY co.customer_id, co.pizza_id, pizza_name
;

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT COUNT(*) maximum_number_of_ordered_pizza
FROM customer_orders
GROUP BY order_id
ORDER BY COUNT(*) DESC
LIMIT 1;


-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
WITH CTE AS (
    SELECT 
        customer_id,
        exclusions,
        extras,
        CASE 
            WHEN (exclusions IS NOT NULL AND LENGTH(exclusions) > 0) 
                OR (extras IS NOT NULL AND LENGTH(extras) > 0) THEN 'true'
            ELSE 'false'
        END AS has_changed 
    FROM customer_orders co
        JOIN runner_orders ro
            ON co.order_id = ro.order_id
    WHERE pickup_time IS NOT NULL
)
SELECT 
    customer_id, 
    SUM(IF(has_changed='true', 1, 0)) AS 'has change',
    SUM(IF(has_changed='true', 0, 1)) 'unchange'
FROM CTE
GROUP BY customer_id
;

-- 8. How many pizzas were delivered that had both exclusions and extras?
WITH CTE AS (
    SELECT 
        customer_id,
        exclusions,
        extras,
        CASE 
            WHEN (exclusions IS NOT NULL AND LENGTH(exclusions) > 0) 
                AND (extras IS NOT NULL AND LENGTH(extras) > 0) THEN 'true'
            ELSE 'false'
        END AS has_changed 
    FROM customer_orders co
        JOIN runner_orders ro
            ON co.order_id = ro.order_id
    WHERE pickup_time IS NOT NULL
)
SELECT
    SUM(IF(has_changed='true', 1, 0)) AS 'have both exclusions and extras'
FROM CTE
;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT  
    HOUR(order_time) 'hour of the day',
    COUNT(order_id) 'number of order id'
FROM customer_orders
GROUP BY HOUR(order_time)
ORDER BY COUNT(order_id) DESC;

-- 10. What was the volume of orders for each day of the week?
SELECT  
    DAYOFWEEK(order_time) 'day of week',
    COUNT(order_id) 'volume of orders'
FROM customer_orders
GROUP BY DAYOFWEEK(order_time);

-- B. Runner and Customer Experience
-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT WEEK(registration_date) Week_id, COUNT(registration_date) as num_runner
FROM runners
GROUP BY WEEK(registration_date);

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT AVG(TIMESTAMPDIFF(MINUTE, order_time, pickup_time)) 'average time to pickup order in minutes'
FROM runner_orders ro
    JOIN customer_orders co ON ro.order_id = co.order_id
WHERE pickup_time IS NOT NULL;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH Q AS(
    SELECT order_id, order_time, COUNT(*) 'num_pizza'
    FROM customer_orders
    GROUP BY order_id, order_time
)
SELECT Q.order_id, order_time, pickup_time, TIMESTAMPDIFF(MINUTE, order_time, pickup_time) 'time prepare', num_pizza
FROM runner_orders ro
    JOIN Q ON Q.order_id = ro.order_id
WHERE pickup_time IS NOT NULL
ORDER BY num_pizza DESC;
-- => The larger number of pizza order the longer it take to prepare. So yes except order_id 8

-- What was the average distance travelled for each customer?
SELECT AVG(REGEXP_SUBSTR(distance,"[0.0-9.9]+")) as avg_distance
FROM runner_orders
WHERE distance IS NOT NULL;

-- What was the difference between the longest and shortest delivery times for all orders?
SELECT 
    MAX(REGEXP_SUBSTR(duration,"[0.0-9.9]+")) 'longest delivery time', 
    MIN(REGEXP_SUBSTR(duration,"[0.0-9.9]+")) 'shortest delivery time'
FROM runner_orders;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT runner_id, AVG(REGEXP_SUBSTR(duration,"[0.0-9.9]+")) avg_delivery_time, AVG(REGEXP_SUBSTR(distance,"[0.0-9.9]+")) avg_distance
FROM runner_orders
WHERE duration IS NOT NULL
GROUP BY runner_id;
-- => There were trend that longer distance cause longer to delivery order

-- What is the successful delivery percentage for each runner?
WITH Q AS(
    SELECT runner_id, COUNT(*) as total_order
    FROM runner_orders
    GROUP BY runner_id
)
SELECT Q.runner_id, (COUNT(*) / total_order)*100 as 'successful percentage'
FROM runner_orders ro 
    JOIN Q ON Q.runner_id = ro.runner_id
WHERE duration IS NOT NULL
GROUP BY runner_id, total_order;

-- C. Ingredient Optimisation
-- What are the standard ingredients for each pizza?
SELECT pr.pizza_id, pn.pizza_name, GROUP_CONCAT(pt.topping_name) toppings
FROM pizza_recipes pr
    JOIN pizza_names pn ON pr.pizza_id = pn.pizza_id 
    JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(pr.toppings, ' ', ''))
GROUP BY pr.pizza_id, pn.pizza_name

-- What was the most commonly added extra?
WITH Q AS(
    SELECT topping_id, topping_name, COUNT(*) 'num_of_extra'
    FROM customer_orders co
        JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(extras, ' ', ''))
    WHERE extras IS NOT NULL AND extras <> ''
    GROUP BY pt.topping_id, topping_name
)
SELECT topping_name 'most commly added extra', num_of_extra 
FROM Q
WHERE num_of_extra = (SELECT MAX(num_of_extra) FROM Q)


-- What was the most common exclusion?
WITH Q AS(
    SELECT topping_id, topping_name, COUNT(*) 'num_of_exclusions'
    FROM customer_orders co
        JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(exclusions, ' ', ''))
    WHERE exclusions IS NOT NULL AND exclusions <> ''
    GROUP BY pt.topping_id, topping_name
)
SELECT topping_name 'most commly exclusions', num_of_exclusions 
FROM Q
WHERE num_of_exclusions = (SELECT MAX(num_of_exclusions) FROM Q)

-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

-- Generate an alphabetically ordered comma separated ingredient list for each pizza order from the 
-- customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
WITH Q AS (
    WITH Q_sub AS(
        SELECT 
            order_id, customer_id, pizza_id, 
            topping_name excluded,
            IF(COUNT(*) > 1, CONCAT(COUNT(*), 'x', topping_name), topping_name) num_excluded
        FROM customer_orders co
            JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(exclusions, ' ', ''))
        WHERE (exclusions IS NOT NULL AND LENGTH(exclusions) > 0)
        GROUP BY order_id, customer_id, pizza_id, topping_name
        ORDER BY topping_name
    )
    SELECT order_id, customer_id, pizza_id, GROUP_CONCAT(num_excluded) excluded
    FROM Q_sub
    GROUP BY order_id, customer_id, pizza_id
),
Q1 AS (
    WITH Q1_sub AS(
        SELECT 
            order_id, customer_id, pizza_id, 
            pt.topping_name added_topping, 
            IF(COUNT(*) > 1, CONCAT(COUNT(*), 'x', topping_name), topping_name) num_added
        FROM customer_orders co
            JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(extras, ' ', ''))
        WHERE (extras IS NOT NULL AND LENGTH(extras) > 0)
        GROUP BY order_id, customer_id, pizza_id, topping_name
        ORDER BY topping_name
    )
    SELECT order_id, customer_id, pizza_id, GROUP_CONCAT(num_added) added
    FROM Q1_sub
    GROUP BY order_id, customer_id, pizza_id
),
Q1Q2 AS(
    SELECT 
        Q.order_id, Q.customer_id, Q.pizza_id, 
        Q.excluded, 
        Q1.added
    FROM Q
        LEFT JOIN Q1 ON
            Q.order_id = Q1.order_id AND
            Q.customer_id = Q1.customer_id AND
            Q.pizza_id = Q1.pizza_id
    UNION
    SELECT 
        COALESCE(Q.order_id, Q1.order_id) order_id,
        COALESCE(Q.customer_id, Q1.customer_id) customer_id,
        COALESCE(Q.pizza_id, Q1.pizza_id) pizza_id,
        Q.excluded, 
        Q1.added
    FROM Q
        RIGHT JOIN Q1 ON
            Q.order_id = Q1.order_id AND
            Q.customer_id = Q1.customer_id AND
            Q.pizza_id = Q1.pizza_id
    ORDER BY order_id, customer_id, pizza_id
)
SELECT 
    order_id, customer_id,
    CONCAT(pizza_name, 
        IFNULL(CONCAT(' - Excluded ', excluded), ''),
        IFNULL(CONCAT(' - Extra ', added), '')
    ) AS format_str 
FROM Q1Q2 temp
    LEFT JOIN pizza_names pn ON 
        temp.pizza_id = pn.pizza_id;

-- What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH Q1 AS(
    SELECT pt.topping_name topping, COUNT(*) number_of_ingredient
    FROM runner_orders ro
        JOIN customer_orders co ON ro.order_id = co.order_id
        JOIN pizza_recipes pr ON co.pizza_id = pr.pizza_id
        JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(pr.toppings, ' ', ''))
    WHERE pickup_time IS NOT NULL AND LENGTH(pickup_time) > 0
    GROUP BY pt.topping_name
    ORDER BY COUNT(*) DESC
),
Q2 AS(
    SELECT pt.topping_name topping, COUNT(*) number_exclusions
    FROM customer_orders co
        JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(co.exclusions, ' ', ''))
    WHERE exclusions IS NOT NULL AND LENGTH(exclusions) > 0
    GROUP BY topping_name
    ORDER BY COUNT(*) DESC
),
Q3 AS (
    SELECT pt.topping_name topping, COUNT(*) number_extras
    FROM customer_orders co
        JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, REPLACE(co.extras, ' ', ''))
    WHERE extras IS NOT NULL AND LENGTH(extras) > 0
    GROUP BY topping_name
    ORDER BY COUNT(*) DESC
)
SELECT Q1.*, 
    Q2.number_exclusions, 
    Q3.number_extras, 
    number_of_ingredient - IFNULL(number_exclusions, 0) + IFNULL(number_extras, 0) total
FROM Q1 
    LEFT JOIN Q2 ON Q1.topping = Q2.topping
    LEFT JOIN Q3 ON Q1.topping = Q3.topping
ORDER BY number_of_ingredient - IFNULL(number_exclusions, 0) + IFNULL(number_extras, 0) DESC;

-- D. Pricing and Ratings
-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
WITH Q AS (
    SELECT order_id, pizza_id,
    CASE 
        WHEN pizza_id = 1 THEN 12
        WHEN pizza_id = 2 THEN 10
    END AS fees
    FROM customer_orders),
Q1 AS (
    SELECT order_id, SUM(fees) fees
    FROM Q
    GROUP BY order_id)
SELECT runner_id, SUM(fees) total_income
FROM Q1
    JOIN runner_orders ro ON Q1.order_id = ro.order_id
GROUP BY runner_id;
-- What if there was an additional $1 charge for any pizza extras?
WITH Q AS(
    SELECT order_id, pizza_id, extras,
    CASE 
        WHEN pizza_id = 1 THEN 12 + IF(extras IS NOT NULL AND LENGTH(extras) > 0, 1, 0)
        WHEN pizza_id = 2 THEN 10 + IF(extras IS NOT NULL AND LENGTH(extras) > 0, 1, 0)
    END AS fees
    FROM customer_orders),
Q1 AS(
    SELECT order_id, SUM(fees) fees
    FROM Q
    GROUP BY order_id)
SELECT runner_id, SUM(fees)
FROM Q1
    JOIN runner_orders ro ON Q1.order_id = ro.order_id
GROUP BY runner_id;

-- Add cheese is $1 extra

-- The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
-- how would you design an additional table for this new dataset - 
-- generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
DROP PROCEDURE IF EXISTS proc_rating; 
DELIMITER $$
CREATE PROCEDURE proc_rating(
    IN p_order_id int,  
    IN p_rating int)
BEGIN
    DECLARE chk BOOL DEFAULT FALSE;
    DECLARE vrunner_id INT DEFAULT 0;

    SELECT IF(pickup_time IS NOT NULL AND LENGTH(pickup_time) > 0, TRUE, FALSE) 
    INTO chk
    FROM runner_orders ro
    WHERE ro.order_id = p_order_id;

    SELECT DISTINCT(runner_id)
    INTO vrunner_id
    FROM runner_orders
    WHERE order_id = p_order_id;

    IF chk = 1 THEN
        INSERT INTO order_rating(order_id, runner_id, rating)
        VALUES (p_order_id, vrunner_id, p_rating);
    ELSE 
        SELECT 'Rating not success' as '';
    END IF;
END$$

-- Using your newly generated table - can you join all of the information 
-- together to form a table which has the following information for successful deliveries?
    -- customer_id
    -- order_id
    -- runner_id
    -- rating
    -- order_time
    -- pickup_time
    -- Time between order and pickup
    -- Delivery duration
    -- Average speed
    -- Total number of pizzas
SELECT co.order_id, co.customer_id, ro.runner_id, co.order_time, ro.pickup_time, ro.duration, ro.distance, rating
FROM customer_orders co
    JOIN runner_orders ro ON co.order_id = ro.order_id
    JOIN order_rating orr ON orr.order_id = co.order_id
WHERE pickup_time IS NOT NULL

-- If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost 
-- for extras and each runner is paid $0.30 per kilometre traveled - 
-- how much money does Pizza Runner have left over after these deliveries?