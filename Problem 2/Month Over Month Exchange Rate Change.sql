---CTE to get the last rate for each currency by month
WITH MonthlyRates AS (
  SELECT 
    currency, 
    DATEADD(
      DAY, 
      - DAY(date) + 1, 
      date
    ) AS month_start_date, 
    rate, 
    ROW_NUMBER() OVER (
      PARTITION BY currency, 
      YEAR(date), 
      MONTH(date) 
      ORDER BY 
        date DESC
    ) AS row_num ------ Assign a row number within each currency and month to find the last date's rate
  FROM 
    sales.ExchangeRate 
  WHERE 
    YEAR(date)= 2018 
    AND currency <> 'USD'
), 
LastDayRates AS (
  SELECT 
    currency, 
    month_start_date, 
    rate AS end_of_month_rate 
  FROM 
    MonthlyRates 
  WHERE 
    row_num = 1 -- Consider last rate for each month
    ) 
SELECT 
  currency, 
  month_start_date, 
  end_of_month_rate, 
  LAG(end_of_month_rate) OVER (
    PARTITION BY currency 
    ORDER BY 
      month_start_date
  ) AS prev_month_rate, -- Fetch the previous month's last rate for the same currency using LAG
  CASE WHEN LAG(end_of_month_rate) OVER (
    PARTITION BY currency 
    ORDER BY 
      month_start_date
  ) IS NULL THEN NULL ELSE ROUND(
    CAST(
      (
        (
          end_of_month_rate - LAG(end_of_month_rate) OVER (
            PARTITION BY currency 
            ORDER BY 
              month_start_date
          )
        ) / LAG(end_of_month_rate) OVER (
          PARTITION BY currency 
          ORDER BY 
            month_start_date
        )
      ) AS float
    )* 100, 
    2
  ) END AS month_over_month_change_percentage 
FROM 
  LastDayRates 
ORDER BY 
  currency, 
  month_start_date;
