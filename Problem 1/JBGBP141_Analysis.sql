
----Difference Analysis----
SELECT * 
FROM 
  (
    SELECT 
    [ORDER_REF] AS ORDER_REF_ADYEN, 
    [DATE] AS TRANS_DATE_ADYEN,
    SUM([GROSS]) AS AMOUNT_ADYEN
    FROM 
	dbseven.dbo.Settlement_details_report 
    WHERE 
    MERCHANT_ACCOUNT = 'JetBrainsGBP' 
    AND BATCH_NUMBER IN (141) 
    GROUP BY 
    [ORDER_REF],
	[DATE]
  ) A ----get all relevent records from settlement file
	LEFT OUTER JOIN 
  (
    SELECT 
    trans.ORDER_REF AS REFERENCE_NETSUITE, 
    trans.TRANDATE as TRANSACTION_DATE_NETSUITE, 
    CAST(SUM(amount_foreign) AS int) AS REVENUE_NETSUITE 
    FROM
      (
		((dea.netsuite.TRANSACTION_LINES tranlines 
          INNER JOIN dea.netsuite.TRANSACTIONS trans ON (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
          INNER JOIN dea.netsuite.ACCOUNTS acc ON (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
          INNER JOIN dea.netsuite.SUBSIDIARIES sub ON (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
      ) 
    WHERE 
	trans.BATCH_NUMBER IN (141)
    AND acc.ACCOUNTNUMBER IN (315700, 315710, 315720, 315820, 548201) 
    AND trans.MERCHANT_ACCOUNT in ('JetBrainsGBP') 
    GROUP BY 
    trans.ORDER_REF,
	trans.TRANDATE
  ) B ---get the matching records from netsuite db existing data
  on (A.ORDER_REF_ADYEN = B.REFERENCE_NETSUITE) AND (A.TRANS_DATE_ADYEN=B.TRANSACTION_DATE_NETSUITE)
  
ORDER BY 1

GO

---Reconciliation----
SELECT *
FROM
	(
		((dea.netsuite.TRANSACTION_LINES tranlines 
		INNER JOIN dea.netsuite.TRANSACTIONS trans ON (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
		INNER JOIN dea.netsuite.ACCOUNTS acc ON (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
		INNER JOIN dea.netsuite.SUBSIDIARIES sub ON (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
	) 
WHERE 
acc.ACCOUNTNUMBER IN (311000) 
AND trans.MERCHANT_ACCOUNT IS NULL 
AND trans.BATCH_NUMBER IS NULL 
AND trans.ORDER_REF IN 
	(
		SELECT 
		DISTINCT [ORDER_REF] 
		FROM 
		dbseven.dbo.Settlement_details_report 
		WHERE 
		MERCHANT_ACCOUNT = 'JetBrainsGBP' 
		AND BATCH_NUMBER in (141)
	) 
