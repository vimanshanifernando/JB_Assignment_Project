
----Difference Analysis----
SELECT * 
FROM 
  (
    SELECT [ORDER_REF] AS ORDER_REF_ADYEN, 
    [DATE] AS TRANS_DATE_ADYEN,
    SUM([GROSS]) as AMOUNT_ADYEN 
    FROM dbseven.dbo.Settlement_details_report 
    WHERE 
    MERCHANT_ACCOUNT = 'JetBrainsAmericasUSD' 
    AND BATCH_NUMBER IN (139) 
    GROUP BY 
    [ORDER_REF],[DATE]
  ) A ---get all records of batch number 139 in settlement file
    FULL OUTER JOIN 
  (
    SELECT 
    DISTINCT trans.ORDER_REF AS ORDER_REF_NETSUITE, 
    trans.TRANDATE AS TRANS_DATE_NETSUITE, 
    CAST(sum(amount) AS int) AS AMOUNT_NETSUITE 
    FROM
      (
		((dea.netsuite.TRANSACTION_LINES tranlines 
          INNER JOIN dea.netsuite.TRANSACTIONS trans ON (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
          INNER JOIN dea.netsuite.ACCOUNTS acc ON (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
          INNER JOIN dea.netsuite.SUBSIDIARIES sub ON (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
      ) 
    WHERE 
	trans.BATCH_NUMBER IN (139)
    AND acc.ACCOUNTNUMBER IN (315700, 315710, 315720, 315820, 548201) 
    AND trans.MERCHANT_ACCOUNT in ('JetBrainsAmericasUSD') 
    GROUP BY 
    trans.ORDER_REF, 
    trans.TRANDATE
  ) B ---get the matching records from netsuite db
  ON (A.ORDER_REF_ADYEN = B.ORDER_REF_NETSUITE) AND (A.TRANS_DATE_ADYEN = b.TRANS_DATE_NETSUITE) 
ORDER BY 1

GO 

----Reconciliation----
SELECT A.* FROM
(
SELECT DISTINCT trans.ORDER_REF AS ORDER_REF_NETSUITE, 
trans.TRANDATE AS TRANS_DATE_NETSUITE,
tranlines.TRANSACTION_ID AS TRANSACTION_ID,
trans.BATCH_NUMBER AS BATCH_NUMBER,
trans.MERCHANT_ACCOUNT AS MERCHANT_ACCOUNT,
acc.ACCOUNT_ID AS ACCOUNT_ID,
sub.SUBSIDIARY_ID AS SUBSIDIARY_ID,
CAST(sum(amount) AS int) AS AMOUNT_NETSUITE 
FROM
	(
		((dea.netsuite.TRANSACTION_LINES tranlines 
		INNER JOIN dea.netsuite.TRANSACTIONS trans ON (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
		INNER JOIN dea.netsuite.ACCOUNTS acc ON (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
		INNER JOIN dea.netsuite.SUBSIDIARIES sub ON (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
	) 
WHERE 
trans.BATCH_NUMBER IS NULL 
AND acc.ACCOUNTNUMBER IN (315700, 315710, 315720, 315820, 548201) 
AND trans.MERCHANT_ACCOUNT in ('JetBrainsAmericasUSD') 
GROUP BY 
trans.ORDER_REF, 
trans.TRANDATE,
tranlines.TRANSACTION_ID,
trans.BATCH_NUMBER,
trans.MERCHANT_ACCOUNT,
acc.ACCOUNT_ID,
sub.SUBSIDIARY_ID
) A
INNER JOIN 
(
SELECT [ORDER_REF] AS ORDER_REF_ADYEN, 
    [DATE] AS TRANS_DATE_ADYEN,
    SUM([GROSS]) as AMOUNT_ADYEN 
    FROM dbseven.dbo.Settlement_details_report 
    WHERE 
    MERCHANT_ACCOUNT = 'JetBrainsAmericasUSD' 
    AND BATCH_NUMBER IN (139) 
    GROUP BY 
    [ORDER_REF],[DATE]
  ) B ON (A.ORDER_REF_NETSUITE=B.ORDER_REF_ADYEN) AND (A.TRANS_DATE_NETSUITE=B.TRANS_DATE_ADYEN)
  ORDER BY 3


 
  




