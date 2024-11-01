SELECT 
    cou.name AS Country,
    FLOOR(SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END)) AS SalesUsd2018H1,
    FLOOR(SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END)) AS SalesUsd2019H1,
    SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total ELSE 0 END) AS SalesLocal2018H1,
    SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total ELSE 0 END) AS SalesLocal2019H1,
	ROUND(  (
                    (FLOOR(SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END)) 
                    - FLOOR(SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END))) 
                    / CAST(SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total / exRate.rate ELSE 0.00 END) AS FLOAT)
                ) * 100,2)
            
    AS YOYUsdPercnt, -- Percentage Difference Calculation in USD, rounded to 2 decimal places
    ROUND(  (
                    (SUM(CASE WHEN YEAR(ord.exec_date) = 2019 THEN ordItm.amount_total ELSE 0 END)
                    - SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total ELSE 0 END)) 
                    / CAST(SUM(CASE WHEN YEAR(ord.exec_date) = 2018 THEN ordItm.amount_total ELSE 0 END) AS FLOAT)
                ) * 100,2)  
            
    AS YOYLocalPercnt  -- Percentage Difference Calculation in Local Currency, rounded to 2 decimal places

FROM dea.sales.Orders ord
JOIN dea.sales.OrderItems ordItm ON ord.id = ordItm.order_id
JOIN dea.sales.Customer cust ON ord.customer = cust.id
JOIN dea.sales.Country cou ON cust.country_id = cou.id
JOIN dea.sales.ExchangeRate exRate ON ord.exec_date = exRate.date AND ord.currency = exRate.currency
JOIN dea.sales.Product prod ON ordItm.product_id = prod.product_id
WHERE ord.is_paid = 1 -- Only paid orders, exclude pre-orders
AND YEAR(ord.exec_date) IN (2018, 2019) -- Years 2018, 2019
AND MONTH(ord.exec_date) BETWEEN 1 AND 6 -- H1
AND cou.region = 'ROW' -- Include only ROW market 
GROUP BY cou.name
ORDER BY DifferenceUsdPercnt; 
