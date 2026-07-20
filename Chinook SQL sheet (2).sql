-- ------------------------------------------------------------Chinook Project-------------------------------------------------------------------------------------------
-- ----OBJECTIVE QUESTIONS------------------------------------------------------------------------

-- ---**** Q1. Does any table have missing values or duplicates? If yes how would you handle it ? *****

SELECT * FROM album;
SELECT * FROM artist;
SELECT COUNT(*) FROM customer -- it gives output: 49 company, 29 state, 47 fax values are null in the customer table
WHERE fax is NULL;
SELECT * from employee; -- 1 reports_to value is null in the employee table
SELECT * FROM genre;
SELECT * FROM invoice_line;
SELECT * FROM invoice;
SELECT * FROM media_type;
SELECT * FROM playlist;
SELECT * FROM playlist_track;
SELECT COUNT(*) FROM track -- 978 composer columns are null in the track table
WHERE composer is NULL


/**** There are no duplicate values in the whole dataset.
In case of null values we can use COALESCE function.
*/

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ****Q2. Find the top-selling tracks and top artist in the USA and identify their most famous genres.***

SELECT Top_selling_track, Top_artist, Top_genre FROM 
(
SELECT t.name Top_selling_track, a.name Top_artist, g.name Top_genre, SUM(t.unit_price * il.quantity) FROM track t
LEFT JOIN invoice_line il on t.track_id = il.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
LEFT JOIN album al on al.album_id = t.album_id
LEFT JOIN artist a on a.artist_id = al.artist_id
LEFT JOIN genre g on g.genre_id = t.genre_id
WHERE billing_country = "USA"
GROUP BY t.name, a.name, g.name
ORDER BY SUM(total) DESC
LIMIT 10
) Agg_table;

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ******Q3. What is the customer demographic breakdown (age, gender, location) of Chinook's customer base? ******

SELECT city, country, COUNT(customer_id) FROM customer
GROUP BY 1,2
ORDER BY country;

SELECT country, COUNT(customer_id) FROM customer
GROUP BY 1
ORDER BY 1;

SELECT COUNT(distinct country) FROM customer;

/*
The customer base in the Chinook database is geographically diverse, spanning across 24 countries. 
The highest concentration of customers is from the United States. 
However, the current Customer table lacks key demographic attributes such as age and gender, which limits deeper insights into the customer profile.
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ****Q4. Calculate the total revenue and number of invoices for each country, state, and city.****

SELECT billing_city, billing_state, billing_country, COUNT(invoice_id) num_of_invoices, SUM(total) total_revenue FROM invoice
GROUP BY 1,2,3
ORDER BY COUNT(invoice_id) DESC, SUM(total) DESC

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ****Q5. Find the top 5 customers by total revenue in each country****

WITH CustomerRevenue AS (
    SELECT 
        c.country,
        c.first_name,
        c.last_name,
        SUM(t.unit_price * il.quantity) AS total_revenue
    FROM customer c
    LEFT JOIN invoice i ON i.customer_id = c.customer_id
    LEFT JOIN invoice_line il ON il.invoice_id = i.invoice_id 
    LEFT JOIN track t ON t.track_id = il.track_id
    GROUP BY c.country, c.first_name, c.last_name
),
RankedCustomers AS (
    SELECT 
        country,
        first_name,
        last_name,
        RANK() OVER (PARTITION BY country ORDER BY total_revenue DESC) AS rk
    FROM CustomerRevenue
)
SELECT 
    country,
    first_name,
    last_name
FROM RankedCustomers
WHERE rk <= 5
ORDER BY country, rk;

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- ***Q6. Identify the top-selling track for each customer***

SELECT first_name, last_name, t.name Track_name, SUM(quantity) Total_quantity FROM customer c
LEFT JOIN invoice i on i.customer_id = c.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
LEFT JOIN track t on t.track_id = il.track_id
GROUP BY 1,2,3
ORDER BY SUM(quantity) DESC;

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ***Q7. Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?***

SELECT customer_id, COUNT(invoice_id) num_invoices, AVG(total) avg_sales FROM invoice
GROUP BY 1
ORDER BY COUNT(invoice_id) DESC, AVG(total) DESC

/*
There is no clear correlation between the number or frequency of orders by customers and the average revenue they generate.
This suggests that average sales are likely influenced more by the unit price of the tracks purchased than by the volume of orders.
*/ 

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ****Q8. What is the customer churn rate?****

WITH num_cust_in_1st_3months as 
(
SELECT COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
),-- I have taken the assumption that total number of customers in the beginning is equal to the customers joining in the first 3 months.
num_cust_in_last_2months as
(
SELECT COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
) -- I have taken the assumption that churn rate will be calculated on the basis of the number of customers left in the last two months. 
SELECT ((SELECT ttl FROM num_cust_in_1st_3months)-(SELECT l_num FROM num_cust_in_last_2months))/(SELECT ttl FROM num_cust_in_1st_3months) * 100 as churn_rate
;

/* 
The customer churn rate is approximately 40.82%, calculated based on the number of customers in the first 3 months (49) and the number retained in the last 2 months (29).

Customers lost = 49 - 29 = 20
Churn Rate = (20 / 49) × 100 ≈ 40.82%

This indicates that the company lost over 40% of its customers during the observed period.
*/ 

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ***Q9. Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.***

WITH usa_revenue AS (
    SELECT SUM(total) AS total_revenue_usa
    FROM invoice
    WHERE billing_country = 'USA'
),

genre_revenue AS (
    SELECT 
        g.genre_id,
        g.name AS genre_name,
        SUM(t.unit_price * il.quantity) AS genre_revenue
    FROM track t
    JOIN genre g ON g.genre_id = t.genre_id
    JOIN invoice_line il ON il.track_id = t.track_id
    JOIN invoice i ON i.invoice_id = il.invoice_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
),

genre_ranking AS (
    SELECT 
        gr.genre_id,
        gr.genre_name,
        ROUND(gr.genre_revenue / ur.total_revenue_usa * 100, 2) AS percentage_contribution,
        DENSE_RANK() OVER (ORDER BY gr.genre_revenue DESC) AS rk
    FROM genre_revenue gr
    CROSS JOIN usa_revenue ur
),

final_result AS (
    SELECT 
        gr.genre_id,
        gr.genre_name,
        a.name AS artist_name,
        gr.percentage_contribution,
        gr.rk
    FROM genre_ranking gr
    JOIN track t ON t.genre_id = gr.genre_id
    JOIN album al ON al.album_id = t.album_id
    JOIN artist a ON a.artist_id = al.artist_id
)

SELECT 
    genre_id,
    genre_name,
    artist_name,
    percentage_contribution,
    rk
FROM final_result
GROUP BY genre_id, genre_name, artist_name, percentage_contribution, rk
ORDER BY rk, genre_name, artist_name;

/* Therefore the top selling genre in USA is Rock.
and 
The Posies
Scorpions
Ozzy Osbourne
Dread Zeppelin
Velvet Revolver
Van Halen
U2
The Who
The Rolling Stones
The Police
The Doors
The Cult
Terry Bozzio, Tony Levin & Steve Stevens
Stone Temple Pilots
Soundgarden
Skank
Lenny Kravitz
Santana
Rush
Red Hot Chili Peppers
Raul Seixas
R.E.M.
Queen
Pink Floyd
Pearl Jam
Paul D'Ianno
Page & Plant
O Terço
Nirvana
Men At Work
Marillion
Led Zeppelin
Kiss
Joe Satriani
Jimi Hendrix
Jamiroquai
Iron Maiden
Guns N' Roses
Foo Fighters
Faith No More
Def Leppard
Deep Purple
Creedence Clearwater Revival
David Coverdale
Frank Zappa & Captain Beefheart
Audioslave
Alice In Chains
Alanis Morissette
Aerosmith
AC/DC
Accept
are all the top artists who are associated with the Rock genre.
*/


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ***Q10. Find customers who have purchased tracks from at least 3 different+ genres***

SELECT name_of_customer FROM
(
SELECT CONCAT(first_name, ' ', last_name) name_of_customer, COUNT(DISTINCT g.name) FROM customer c 
LEFT JOIN invoice i on i.customer_id = c.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
LEFT JOIN track t on t.track_id = il.track_id
LEFT JOIN genre g on g.genre_id = t.genre_id
GROUP BY 1 HAVING COUNT(DISTINCT g.name) >= 3
ORDER BY COUNT(DISTINCT g.name) DESC
) agg_table

/* Leonie Köhler is the person who has bought tracks from 14 different genres.
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


-- ***Q11. Rank genres based on their sales performance in the USA****

WITH cte as
(
SELECT t.genre_id, g.name,  SUM(t.unit_price * il.quantity) sale_performance FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1, 2
)
SELECT name, sale_performance,
DENSE_RANK() OVER(ORDER BY sale_performance DESC) `rank` FROM cte
;

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ***Q12. Identify customers who have not made a purchase in the last 3 months***

WITH last_3_months as
(
SELECT * from invoice
WHERE invoice_date > (SELECT MAX(invoice_date) FROM invoice) - INTERVAL 3 MONTH
)
SELECT CONCAT(first_name, ' ', last_name) name_of_customer FROM customer c
LEFT JOIN last_3_months lm on lm.customer_id = c.customer_id
WHERE invoice_id is NULL
;

/* There are 22 customers in the dataset who have not made any purchase in the last 3 months.
*/

-------------------------------------------------------------------------------------------------------------------------------
-- ----SUBJECTIVE QUESTIONS------------------------------------------------------------------------

-- ***Q1. Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.***

WITH genre_sales as
(
SELECT  g.genre_id, g.name, sum(t.unit_price * il.quantity) total_revenue_for_genre FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country = 'USA'
GROUP BY 1,2
ORDER BY total_revenue_for_genre DESC
),
ranking as
(
SELECT genre_id, name, total_revenue_for_genre,
DENSE_RANK() OVER(ORDER BY total_revenue_for_genre DESC) rk FROM genre_sales
),
genre_album as
(
SELECT ranking.genre_id, ranking.name genre_name, al.title album_name FROM ranking
LEFT JOIN track t on t.genre_id = ranking.genre_id
LEFT JOIN album al on al.album_id = t.album_id
LEFT JOIN artist a on a.artist_id = al.artist_id
WHERE rk = 1
GROUP BY 1,2,3
),
best_album as
(
SELECT al.album_id, title, SUM(t.unit_price * il.quantity) FROM album al
LEFT JOIN track t on t.album_id = al.album_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
GROUP BY 1,2
ORDER BY SUM(t.unit_price * il.quantity) desc
)
SELECT genre_id, genre_name, album_name FROM genre_album 
inner join best_album on best_album.title = genre_album.album_name
LIMIT 3


/* 
Top 3 Albums to Prioritize for Advertising in the USA
Based on genre-wise revenue analysis, Rock emerges as the most popular and highest-grossing genre in the USA market. 
Accordingly, the following three albums should be prioritized for advertisements and promotions:
-----Every Kind of Light
-----20th Century Masters – The Millennium Collection: The Best of Scorpions
-----Speak of the Devil

Promoting these albums can help capitalize on the strong consumer preference for Rock music in the U.S. market.
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ****Q2. Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.***

SELECT  g.genre_id, g.name, sum(t.unit_price * il.quantity) total_revenue_for_genre FROM track t
LEFT JOIN genre g on g.genre_id = t.genre_id
LEFT JOIN invoice_line il on il.track_id = t.track_id
LEFT JOIN invoice i on i.invoice_id = il.invoice_id
WHERE billing_country != 'USA'
GROUP BY 1,2
ORDER BY total_revenue_for_genre DESC

/* Genre Performance Across USA and Other Countries

A key commonality between the USA and other countries is that the Rock genre consistently holds the top position in terms of revenue.
Following Rock, the Metal genre ranks second, while Alternative & Punk takes the third spot in both datasets.
This trend indicates a strong global preference for rock-related genres, which can inform strategic decisions around promotions and content curation.
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- ***Q3. Customer Purchasing Behavior Analysis: 
-- How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?
 
 
 -- Step 1: Calculate individual customer metrics
WITH customer_metrics AS (
    SELECT 
        i.customer_id,
        MAX(i.invoice_date) AS last_purchase,
        MIN(i.invoice_date) AS first_purchase,
        ABS(TIMESTAMPDIFF(MONTH, MAX(i.invoice_date), MIN(i.invoice_date))) AS duration_months,
        SUM(i.total) AS total_sales,
        SUM(il.quantity) AS total_items,
        COUNT(i.invoice_id) AS purchase_frequency
    FROM invoice i
    JOIN invoice_line il ON il.invoice_id = i.invoice_id
    GROUP BY i.customer_id
),

-- Step 2: Calculate average duration for categorization
average_duration AS (
    SELECT AVG(duration_months) AS avg_duration
    FROM customer_metrics
),

-- Step 3: Categorize customers
categorized_customers AS (
    SELECT 
        cm.*,
        CASE 
            WHEN cm.duration_months > ad.avg_duration THEN 'Long-term Customer'
            ELSE 'Short-term Customer'
        END AS category
    FROM customer_metrics cm
    CROSS JOIN average_duration ad
)

-- Step 4: Aggregate by category
SELECT 
    category,
    SUM(total_sales) AS total_spending,
    SUM(total_items) AS basket_size,
    COUNT(customer_id) AS customer_count
FROM categorized_customers
GROUP BY category;

/* 
Insights :-
The analysis reveals that long-term customers exhibit higher spending, basket size, and purchase frequency compared to short-term customers. 
This suggests that customer loyalty is directly linked to increased revenue contribution.

Recommendations:-
**To drive sustainable growth, the company should prioritize customer retention strategies. 
**Strengthening long-term relationships with customers can significantly boost overall sales. 
**Initiatives such as loyalty programs, personalized offers, and consistent engagement can help improve retention and maximize the lifetime value of each customer.
 */

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q4. Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers?
 --  How can this information guide product recommendations and 
 -- cross-selling initiatives?

WITH cte as
(
SELECT invoice_id, COUNT(DISTINCT g.name) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN genre g on  g.genre_id = t.genre_id
GROUP BY 1 HAVING COUNT(DISTINCT g.name) > 1
)
SELECT cte.invoice_id, num, g.name FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN genre g on  g.genre_id = t.genre_id
GROUP BY 1,2,3;

WITH cte as
(
SELECT invoice_id, COUNT(DISTINCT al.title) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN album al on al.album_id = t.album_id
GROUP BY 1 HAVING COUNT(DISTINCT al.title) > 1
)
SELECT cte.invoice_id, num, al.title FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN album al on  al.album_id = t.album_id
GROUP BY 1,2,3;

WITH cte as
(
SELECT invoice_id, COUNT(DISTINCT a.name) num FROM invoice_line il
left JOIN track t on t.track_id = il.track_id
left JOIN album al on al.album_id = t.album_id
left join artist a on a.artist_id = al.artist_id
GROUP BY 1 HAVING COUNT(DISTINCT a.name) > 1
)
SELECT cte.invoice_id, num, a.name FROM cte
left join invoice_line il on il.invoice_id = cte.invoice_id
left JOIN track t on t.track_id = il.track_id
left JOIN album al on  al.album_id = t.album_id
left join artist a on a.artist_id = al.artist_id
GROUP BY 1,2,3;


/*
Insights from Co-Purchase Analysis Using Pivot Tables:
After plotting the query outputs in Excel and constructing pivot tables with:

Genres in rows, Invoice IDs in columns, and Count of genres as values,

it becomes evident that the genres Rock, Metal, and Alternative & Punk are frequently purchased together.
Similarly, when analyzing album-level data, the albums that are commonly bought in the same invoices include:

****Mezmerize
****The Doors
****Dark Side of the Moon

For artist-level purchases, the most frequent combinations include:

****Green Day
****Foo Fighters
****U2

Conclusion:-
These patterns suggest strong associations in customer preferences,
indicating potential for bundled promotions, playlist curation, or targeted marketing strategies focused on these frequently co-purchased items.
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q5. Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?

WITH num_cust_in_1st_3months as
(
SELECT billing_country, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_country, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_country, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_country = n2.billing_country
;

WITH num_cust_in_1st_3months as
(
SELECT billing_city, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_city, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_city, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_city = n2.billing_city
;

WITH num_cust_in_1st_3months as
(
SELECT billing_state, COUNT(customer_id) ttl from invoice
WHERE invoice_date BETWEEN '2017-01-01' AND '2017-03-31'
GROUP BY 1
),
num_cust_in_last_2months as
(
SELECT billing_state, COUNT(customer_id) l_num FROM invoice
WHERE invoice_date BETWEEN '2020-11-01' AND '2020-12-31' 
GROUP BY 1
)
SELECT n1.billing_state, (ttl - COALESCE(l_num,0))/ttl * 100 churn_rate FROM num_cust_in_1st_3months n1
LEFT JOIN  num_cust_in_last_2months n2 on n1.billing_state = n2.billing_state
;


SELECT billing_country, COUNT(invoice_id) num_invoices, AVG(total) avg_sales FROM invoice
GROUP BY 1
ORDER BY COUNT(invoice_id) DESC, AVG(total) DESC

/*
Insights:-
The customer churn rate shows noticeable variation across different countries, cities, and states.
Additionally, customer purchasing behavior differs significantly by geography, indicating region-specific preferences and engagement patterns.

Recommendations:-
Data suggests that developed countries contribute a higher number of orders and greater average sales, 
highlighting the influence of economic strength on purchasing power.

----To optimize sales:
**Increase targeted advertising in high-income countries to maximize revenue potential.
**Offer more affordable track pricing or localized discounts in lower-income countries to boost accessibility and sales.
**Population size should also be considered when evaluating market potential, as it directly impacts the customer base and potential revenue volume in a given region.
*/


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Q6. Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), 
-- which customer segments are more likely to churn or pose a higher risk of reduced spending? 
-- What factors contribute to this risk?

SELECT i.customer_id, CONCAT(first_name, " ", last_name) name, billing_country, invoice_date, SUM(total) total_spending, COUNT(invoice_id) num_of_orders FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
GROUP BY 1,2,3,4
ORDER BY name

/*
Insights:-
Analysis of the sales data through charts and tables reveals a trend where countries already exhibiting high spending and frequent orders continue to grow, 
while sales and frequency remain stagnant in other regions. This indicates a regional imbalance in engagement and retention.

Additionally, a lack of demographic data limits the depth of churn and behavioral analysis. 
If available, key factors that could contribute to customer churn risk include:

**Age: Are younger customers more likely to churn?
**Gender: Does gender influence retention and spending patterns?
**Location: Are certain cities, states, or countries more prone to churn?
**Spending Behavior: How do high-spending, loyal customers compare to low-frequency or low-spending buyers?

Recommendations:-

**To mitigate churn and boost engagement in underperforming regions:
**Launch targeted promotional campaigns in countries with stagnant sales to re-engage existing customers and attract new ones.
**Use geographic segmentation to customize marketing efforts based on regional performance.

Once demographic data is available, implement customer segmentation models such as:

Young Male – High Spenders
Young Female – High Spenders
Older Male – Low Spenders
Older Female – Low Spenders

These segments would allow for more personalized engagement strategies and retention efforts, ultimately driving revenue and reducing churn across different customer profiles.

*/
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q7. Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, 
-- engagement) to predict the lifetime value of different customer segments? 
-- This could inform targeted marketing and loyalty program strategies. 
-- Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

/*
To predict the Customer Lifetime Value (CLV) across different segments, customer data such as purchase history, tenure, and engagement behavior can be leveraged effectively.
By analyzing the total spend, purchase frequency, and length of customer relationship, we can identify which customers are high-value and which ones have the potential to become so. For instance, if a customer has a short tenure but a high purchase volume, it indicates strong initial engagement—such customers are ideal candidates for targeted marketing and loyalty program initiatives to foster long-term retention.

In contrast, an analysis of customers who have stopped purchasing reveals a common pattern: many of them are from underdeveloped or developing countries. This suggests that economic factors significantly impact purchasing behavior and retention.

Recommendations:-
Segment customers based on tenure and spending patterns to identify:
High tenure – high spend (loyal high-value)
Low tenure – high spend (high potential)
High tenure – low spend (at-risk)
Low tenure – low spend (low ROI)

Target high-potential customers (low tenure, high spend) with:-

Personalized offers
Loyalty rewards
Early-access promotions
To address churn in economically weaker regions:
Launch affordable product options or localized pricing
Increase outreach through social media, email campaigns, and regional advertisements
Provide occasional discounts and incentives to encourage repeat purchases
By incorporating these strategies, the company can better maximize customer lifetime value, reduce churn, and improve customer retention across segments and geographies. 
*/       

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q8.	If data on promotional campaigns (discounts, events, email marketing) is available, 
-- how could you measure their impact on customer acquisition, retention, and overall sales?
/*
If the data on promotional campaigns was available, I would have used it to analyze its impact on 
1.	Customer Acquisition based on
•	The increase in the number of customers with time.
•	Number of people participating in the events held in different locations.
•	The increase in click-through rate due to the email marketing campaigns.

2.	Retention on the basis of
•	Number of old customers attending the event and then purchasing the track again after long time.
•	Number of customers getting a discount.

3.	Sales on the basis of
•	Increase in the sales due to promotional campaigns.
•	Trends to analyse which promotional campaign was the best.
•	New customers being generated due to discounts

*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q9.	How would you approach this problem, if the objective and subjective questions weren't given?

/*
If the objective and subjective questions weren’t given, I would have first gone through the aim of the project and based on that decide the KPIs which would have helped me reach the objective. 
Then I would have developed various business questions like: -
•	Which are locations from where maximum sale is coming?
•	Which tracks are the best-selling in each location?
•	Which are the most popular artists and albums in different regions?
•	How is sales distributed among different countries?
•	Which genre is most liked in each country?
& also look over the Trends in the purchases of tracks like: -
•	What is the total revenue generated over a period of time?
•	How is the invoice total of each customer changed with time?
•	What is the trend of a particular genre in a particular country?
Then I would have summarized all the insights and presented the data. 

*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- Q10.	How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

/*
We can use the ALTER TABLE command to add a new column to the Album table.
Code: - 
ALTER TABLE album
ADD ReleaseYear
data_type int;
*/

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


-- Q11. Chinook is interested in understanding the purchasing behavior of customers based on their 
-- geographical location. They want to know the average total amount spent by customers from each country, 
-- along with the number of customers and the average number of tracks purchased per customer. 
-- Write an SQL query to provide this information.

SELECT billing_country, 
COUNT(DISTINCT customer_id) num_of_customers, 
AVG(total) Average_total_amount, 
COUNT(track_id) num_of_tracks 
FROM invoice i
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1 
;

SELECT customer_id, COUNT(DISTINCT track_id) num_of_tracks_per_customer FROM invoice i
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1

