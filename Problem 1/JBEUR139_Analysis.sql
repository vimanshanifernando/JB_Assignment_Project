----Difference Analysis---
SELECT 
    ORDER_REF_ADYEN AS ORDER_REF_ADYEN, 
    TRANS_DATE_ADYEN AS TRANS_DATE_ADYEN, 
    AMOUNT_ADYEN AS AMOUNT_ADYEN,
	ORDER_REF_NETSUITE,
	TRANS_DATE_NETSUITE,
	AMOUNT_NETSUITE AS AMOUNT_NETSUITE 

    FROM 
    (  (
		SELECT 
		[ORDER_REF] AS ORDER_REF_ADYEN, 
		DATE AS TRANS_DATE_ADYEN, 
		SUM(GROSS) AS AMOUNT_ADYEN
		FROM 
		dbseven.dbo.Settlement_details_report 
		WHERE 
		MERCHANT_ACCOUNT = 'JetBrainsEUR' 
		AND BATCH_NUMBER IN (139) 
		GROUP BY 
		[ORDER_REF], 
		DATE
      ) A 
      FULL OUTER JOIN 
	  (
        SELECT 
        trans.ORDER_REF AS ORDER_REF_NETSUITE, 
        trans.TRANDATE AS TRANS_DATE_NETSUITE, 
        CAST(SUM(amount_foreign) AS INT) AS AMOUNT_NETSUITE 
        FROM 
			  (
			   ((dea.netsuite.TRANSACTION_LINES tranlines 
				INNER JOIN dea.netsuite.TRANSACTIONS trans on (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
				INNER JOIN dea.netsuite.ACCOUNTS acc on (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
				INNER JOIN dea.netsuite.SUBSIDIARIES sub on (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
			  ) 
		WHERE
        trans.BATCH_NUMBER = 139 
        AND acc.ACCOUNTNUMBER IN (315700, 315710, 315720, 315820, 548201) 
        AND trans.MERCHANT_ACCOUNT IN ('JetBrainsEUR') 
        GROUP BY 
        trans.ORDER_REF, 
        trans.TRANDATE
		) B ON (A.ORDER_REF_ADYEN = B.ORDER_REF_NETSUITE) AND (A.TRANS_DATE_ADYEN = B.TRANS_DATE_NETSUITE) 
		)
     WHERE AMOUNT_ADYEN <> AMOUNT_NETSUITE ---get the records with difference in amounts in two sources
	 OR AMOUNT_NETSUITE IS NULL---get the records which are there only in settlement file
     ORDER BY AMOUNT_NETSUITE DESC
 
GO

----Reconciliation----
SELECT H.* 
FROM 

  (
    SELECT 
    trans.ORDER_REF AS ORDER_REF_NETSUITE, 
    trans.TRANDATE AS TRANSACTION_DATE_NETSUITE, 
    tranlines.TRANSACTION_ID, 
    trans.BATCH_NUMBER AS BATCH_NUMBER,
	trans.MERCHANT_ACCOUNT AS MERCHANT_ACCOUNT,
	acc.ACCOUNT_ID AS ACCOUNT_ID,
	sub.SUBSIDIARY_ID AS SUBSIDIARY_ID,
    CAST(SUM(amount_foreign) AS INT) AS AMOUNT_NETSUITE 
    FROM 
			 (
			   ((dea.netsuite.TRANSACTION_LINES tranlines 
				INNER JOIN dea.netsuite.TRANSACTIONS trans on (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
				INNER JOIN dea.netsuite.ACCOUNTS acc on (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
				INNER JOIN dea.netsuite.SUBSIDIARIES sub on (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
			 ) 
	WHERE 
    trans.BATCH_NUMBER IS NULL 
    AND acc.ACCOUNTNUMBER IN (311000) 
    AND trans.MERCHANT_ACCOUNT IS NULL 
    GROUP BY 
    trans.ORDER_REF, 
	trans.TRANDATE,
	tranlines.TRANSACTION_ID,
	trans.BATCH_NUMBER,
	trans.MERCHANT_ACCOUNT,
	acc.ACCOUNT_ID,
	sub.SUBSIDIARY_ID
  ) H 
  INNER JOIN 
  (
    SELECT 
    DISTINCT REFERENCE_NETSUITE, 
    TRANSACTION_DATE_NETSUITE, 
    REVENUE_NETSUITE 
    FROM 
      
	  (
        SELECT 
        REFERENCE AS REFERENCE, 
        TRANSACTION_DATE AS TRANSACTION_DATE, 
        GROSS AS GROSS 
        FROM 
          (
            SELECT 
            [ORDER_REF] AS REFERENCE, 
            DATE AS TRANSACTION_DATE, 
            (GROSS) AS GROSS 
            FROM 
            dbseven.dbo.Settlement_details_report 
            WHERE 
            MERCHANT_ACCOUNT = 'JetBrainsEUR' 
            AND BATCH_NUMBER IN (139)
          ) A 
          LEFT OUTER JOIN 
			(
            SELECT 
            trans.ORDER_REF AS REFERENCE1, 
            trans.TRANDATE AS TRANSACTION_DATE1, 
            (amount_foreign) AS REVENUE1 
            FROM 
				 (
				   ((dea.netsuite.TRANSACTION_LINES tranlines 
					INNER JOIN dea.netsuite.TRANSACTIONS trans on (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
					INNER JOIN dea.netsuite.ACCOUNTS acc on (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
					INNER JOIN dea.netsuite.SUBSIDIARIES sub on (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
				 ) 
			WHERE 
            trans.BATCH_NUMBER = 139 
            AND acc.ACCOUNTNUMBER IN (315700, 315710, 315720, 315820, 548201) 
            AND trans.MERCHANT_ACCOUNT IN ('JetBrainsEUR')
          ) B 
		  ON (A.REFERENCE = B.REFERENCE1) AND (A.TRANSACTION_DATE = B.TRANSACTION_DATE1) 
		WHERE 
		REVENUE1 IS NULL OR ---get the records which are there only in settlement file
		(GROSS - REVENUE1)<> 0 ---get the records where amounts of settlement file and db , is not equal
      ) 
	  D 
      INNER JOIN 
	  (
        SELECT 
        DISTINCT trans.ORDER_REF AS REFERENCE_NETSUITE, 
        trans.TRANDATE AS TRANSACTION_DATE_NETSUITE, 
        trans.TRANSACTION_TYPE AS TRANSACTION_TYPE_NETSUITE, 
        CAST(SUM(amount_foreign) AS INT) AS REVENUE_NETSUITE 
        FROM 
			 (
			   ((dea.netsuite.TRANSACTION_LINES tranlines 
				INNER JOIN dea.netsuite.TRANSACTIONS trans on (tranlines.TRANSACTION_ID = trans.TRANSACTION_ID)) 
				INNER JOIN dea.netsuite.ACCOUNTS acc on (tranlines.ACCOUNT_ID = acc.ACCOUNT_ID)) 
				INNER JOIN dea.netsuite.SUBSIDIARIES sub on (tranlines.SUBSIDIARY_ID = sub.SUBSIDIARY_ID)
			 ) 
		WHERE 
        acc.ACCOUNTNUMBER IN (311000) 
        AND trans.BATCH_NUMBER IS NULL 
        AND trans.MERCHANT_ACCOUNT IS NULL 
        AND trans.TRANSACTION_TYPE IN ('Credit Note')---only (-) figures 
        GROUP BY 
        trans.ORDER_REF, 
        trans.TRANDATE, 
        trans.TRANSACTION_TYPE
      ) E ---find the missing data in differennt accounts other than 315700, 315710, 315720, 315820, 548201

    ON (D.REFERENCE = E.REFERENCE_NETSUITE) --transation dates of missing data found, do not match with dates in settlement file
    
	WHERE 
    D.GROSS = E.REVENUE_NETSUITE
  ) 
  J ON (H.ORDER_REF_NETSUITE = J.REFERENCE_NETSUITE) AND (H.TRANSACTION_DATE_NETSUITE= J.TRANSACTION_DATE_NETSUITE) 
  ORDER BY 3
  
