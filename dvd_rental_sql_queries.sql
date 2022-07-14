/*
Hi Thank you for reviewing my work, please don't hesitate to give any feedback. I really want to improve in this field. Generally, I use the question set as a guideline, but I modify some of the questions along the way to analyze questions that I think are interesting to explore.

The data can be fetched here https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/


Query 1
Topic: Movie category, rental time, and rental rate

I want to try to discover what movie is the most rented for every category and how they compare to each other.
*/

WITH rental_count_tab AS(
	SELECT 
		f.title film_title, 
		c.name category_name, 
		COUNT(r.rental_id) rental_count,
		RANK() OVER (PARTITION BY c.name ORDER BY COUNT(r.rental_id) DESC) AS category_rank
		FROM film f
	JOIN film_category fc ON f.film_id = fc.film_id
	JOIN inventory i ON f.film_id = i.film_id
	JOIN rental r ON i.inventory_id = r.inventory_id
	JOIN category c ON fc.category_id = c.category_id
	WHERE 
		c.name IN ( 'Animation', 'Children', 'Classics', 'Comedy', 'Family', 'Music')
	GROUP BY 1, 2
	ORDER BY 2, 3 DESC
	)
	
SELECT film_title, category_name, rental_count
FROM rental_count_tab
WHERE category_rank = 1
ORDER BY 3 DESC,2

/*
Query 2
Topic: Movie category, rental time, and rental rate

The second query is similar to set 1 question 2. I choose to use to measure by hour for the rental duration to see the difference between categories in higher precision. I also modify the the order a bit so I can plot the distribution graph for each category.
*/

WITH rental_hour_duration AS	(
	SELECT
		rental_id,
		(DATE_PART('day', return_date - rental_date)*24 +
		DATE_PART('hour', return_date - rental_date)) as rental_hour_duration
	FROM rental
	)

SELECT 	f.title film_title, 
		c.name category_name,
		rd.rental_hour_duration,
		NTILE(4) OVER (ORDER BY rd.rental_hour_duration) AS quartile
FROM	film f
JOIN	film_category fc ON f.film_id = fc.film_id
JOIN	inventory i ON f.film_id = i.film_id
JOIN	rental r ON i.inventory_id = r.inventory_id
JOIN	category c ON fc.category_id = c.category_id
JOIN	rental_hour_duration rd ON rd.rental_id = r.rental_id
WHERE	c.name IN ( 'Animation', 'Children', 'Classics', 'Comedy', 'Family', 'Music') 
		AND rd.rental_hour_duration IS NOT NULL
ORDER BY 2,4,3

/*
Query 3
Topic: Movie category, rental time, and rental rate

This query answer set 1 question 3 
*/

WITH rental_hour_duration AS(
	SELECT
		rental_id,
		(DATE_PART('day', return_date - rental_date)*24 +
		DATE_PART('hour', return_date - rental_date)) as rental_hour_duration
	FROM rental
	),

rental_quartile AS(
	SELECT 	f.title film_title, 
			c.name category_name,
			rd.rental_hour_duration,
			NTILE(4) OVER (ORDER BY rd.rental_hour_duration) AS quartile
	FROM	film f
	JOIN	film_category fc ON f.film_id = fc.film_id
	JOIN	inventory i ON f.film_id = i.film_id
	JOIN	rental r ON i.inventory_id = r.inventory_id
	JOIN	category c ON fc.category_id = c.category_id
	JOIN	rental_hour_duration rd ON rd.rental_id = r.rental_id
	WHERE	c.name IN ( 'Animation', 'Children', 'Classics', 'Comedy', 'Family', 'Music') 
				AND rd.rental_hour_duration IS NOT NULL
	ORDER BY 3
	)
		
SELECT category_name, quartile, count(*)
FROM rental_quartile
GROUP BY 1,2
ORDER BY 1,2

/*
Query 4
Topic: Rental By Store

This query answer set 2 question 1, but I modify it a little bit so that rental store 1 and store 2 are on a different column. This is done to make it easier to plot the graph later.
*/

WITH rental_per_store AS(
	SELECT 
		CONCAT(DATE_PART('year',r.rental_date), '-', DATE_PART('month',r.rental_date)) year_month,
		st.store_id,
		COUNT(*) rental_count
	FROM rental r
	JOIN staff st ON st.staff_id = r.staff_id
	GROUP BY 1,2
	ORDER BY 1,2
	),

rental_store1 AS(
	SELECT year_month, rental_count AS rental_store_1
	FROM rental_per_store
	WHERE store_id = 1
	),

rental_store2 AS(
	SELECT year_month, rental_count AS rental_store_2
	FROM rental_per_store
	WHERE store_id = 2  
	)
       
SELECT *
FROM rental_store1
JOIN rental_store2 
ON rental_store1.year_month = rental_store2.year_month

/*
Query 5
Topic: Top 10 Customer

This query is similar to set 2 question 2 but I modify it a little bit so it is grouped only by month. the customers are transposed into columns so that Is easier to plot the line chart
*/


WITH top10_customer AS(
	SELECT 
		c.customer_id, 
		CONCAT(c.first_name, ' ', c.last_name) full_name, 
		SUM(p.amount) total_amount,
        RANK() OVER (ORDER BY SUM(p.amount) desc) total_amount_rank
	FROM customer c
	JOIN payment p ON c.customer_id = p.customer_id
	GROUP BY 1,2
	ORDER BY 3 DESC
	LIMIT 10
	)

SELECT 
	DATE_TRUNC('month',p.payment_date) AS pay_month,
	SUM(p.amount) pay_amount,
	SUM(case when t10.total_amount_rank = 1 then p.amount end) as person1,
	SUM(case when t10.total_amount_rank = 2 then p.amount end) as person2,
	SUM(case when t10.total_amount_rank = 3 then p.amount end) as person3,
	SUM(case when t10.total_amount_rank = 4 then p.amount end) as person4,
	SUM(case when t10.total_amount_rank = 5 then p.amount end) as person5,
	SUM(case when t10.total_amount_rank = 6 then p.amount end) as person6,
	SUM(case when t10.total_amount_rank = 7 then p.amount end) as person7,
	SUM(case when t10.total_amount_rank = 8 then p.amount end) as person8,
	SUM(case when t10.total_amount_rank = 9 then p.amount end) as person9,
	SUM(case when t10.total_amount_rank = 10 then p.amount end) as person10
FROM payment p
JOIN top10_customer t10 ON p.customer_id = t10.customer_id
GROUP BY 1
ORDER BY 1

/*
Query 6 & 6a
Topic: Payment difference in each successive month

This query answer set 2 question 3. I figure it is easier to read if I separate the query for finding MAX difference (increase) in payment, so I set the CTE and we can choose to run 2 simple queries to obtain both information.
*/
WITH top10_customer AS(
	SELECT 
		c.customer_id, 
		CONCAT(c.first_name, ' ', c.last_name) full_name, 
		SUM(p.amount) total_amount
	FROM customer c
	JOIN payment p ON c.customer_id = p.customer_id
	GROUP BY 1,2
	ORDER BY 3 DESC
	LIMIT 10
	),


mon_pay_amount AS(
	SELECT 
		DATE_TRUNC('month',p.payment_date) AS pay_month,
		t10.full_name,
		SUM(p.amount) pay_amount,
		SUM(p.amount) - LAG(SUM(p.amount)) OVER (PARTITION BY full_name ORDER BY full_name, DATE_TRUNC('month',p.payment_date)) pay_amount_increase
	FROM payment p
	JOIN top10_customer t10 ON p.customer_id = t10.customer_id
	WHERE DATE_PART('year',p.payment_date) = 2007
	GROUP BY 1,2
	ORDER BY 2,1
	)
	
--SELECT * FROM mon_pay_amount
/*
6 Stop here and run SELECT * FROM mon_pay_amount if we just want to compare payment difference in each successive month
6a Run all queries with the query below included to identify the customer name who paid the most difference in terms of payments.
*/
SELECT full_name, MAX(pay_amount_increase) top_increase
FROM mon_pay_amount
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1
