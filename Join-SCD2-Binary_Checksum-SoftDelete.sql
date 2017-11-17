/* Run once

IF OBJECT_ID('tempdb.dbo.#source') IS NOT NULL DROP TABLE #source;
IF OBJECT_ID('tempdb.dbo.#target') IS NOT NULL DROP TABLE #target;

-- Conditions:
-- 1) Source data is not SCD2
-- 2) Target data IS SCD2
-- 3) Use BINARY_CHECKSUM for Change Data Capture
-- 4) Soft delete target rows not in source (rows are not physically deleted in SCD2)
-- 5) Both source and target have an identity column for SK (they don't have to match) (or else join on the NK)
-- 6) Use a join to create a XREF table of the source and target SK based on the NK

CREATE TABLE #source
( SK            INT IDENTITY(1,1)
, FirstName     VARCHAR(20)
, LastName      VARCHAR(30)
, EmailAddress  VARCHAR(50)
)

CREATE TABLE #target
( SK            INT IDENTITY(1,1)
, FirstName     VARCHAR(20)
, LastName      VARCHAR(30)
, EmailAddress  VARCHAR(50)
, Status        CHAR(1)
, ValidFrom     DATETIME    DEFAULT     GETDATE()
, ValidTo       DATETIME    DEFAULT     '9999-12-31 23:59:59'
, IsCurrent     CHAR(1)     DEFAULT     'Y'
)

INSERT INTO #source
(FirstName,LastName,EmailAddress)
VALUES
 ('John','Doe','john.doe@foo.com')
,('Mary','Jones','mary.jones@bar.com')
,('Joe','Bloggs','joe@bloggs.com')

*/

/*
Note:  BINARY_CHECKSUM can experience data collisions.  Run this code:

DECLARE @t TABLE (s VARCHAR(50));
INSERT INTO @t
VALUES
 ('2Volvo Director 20')
,('3Volvo Director 30')
,('4Volvo Director 40')

SELECT s, BINARY_CHECKSUM(s) FROM @t

https://decipherinfosys.wordpress.com/2007/05/18/checksum-functions-in-sql-server-2005/
*/

-- Create code as a SP for easy reuse
DROP PROCEDURE deleteme
GO
CREATE PROCEDURE deleteme
AS
BEGIN

-- Use a full outer join to create a XREF table
IF OBJECT_ID('tempdb.dbo.#xref') IS NOT NULL DROP TABLE #xref;

;WITH ACTION (ACTION, SRC_SK, TGT_SK, CHANGED)
AS (
SELECT CASE
       -- List the WHEN clauses in order of probability
       WHEN (tgt.SK IS NULL     and src.SK IS NOT NULL) THEN 'INSERT'
       WHEN (tgt.SK IS NOT NULL and src.SK IS NOT NULL) THEN 'UPDATE'
       WHEN (tgt.SK IS NOT NULL and src.SK IS NULL)     THEN 'DELETE'
       ELSE ''  -- Will never happen but CASE likes an ELSE clause
       END AS ACTION
      ,src.SK AS SRC_SK
      ,tgt.SK AS TGT_SK
      ,CASE
       WHEN BINARY_CHECKSUM(
                 src.FirstName
                ,src.LastName
                ,src.EmailAddress
            ) <>
            BINARY_CHECKSUM(
                 tgt.FirstName
                ,tgt.LastName
                ,tgt.EmailAddress
            )
            THEN 1 ELSE 0
       END AS CHANGED
FROM   #source src
FULL   OUTER JOIN #target tgt
ON     src.FirstName = tgt.FirstName
AND    src.LastName  = tgt.LastName
)
SELECT *
INTO   #xref
FROM   ACTION a
WHERE  a.ACTION IN ('INSERT','DELETE') OR (a.ACTION = 'UPDATE' AND a.CHANGED = 1)
;

-- Use the XREF table to issue separate INSERT/UPDATE/DELETE blocks
BEGIN TRANSACTION

-- Use a constant for the ValidFrom/ValidTo dates for temporal consistency within the transaction
DECLARE @date DATETIME = GETDATE();

-- INSERT
INSERT INTO #target
(FirstName,LastName,EmailAddress,Status,ValidFrom)
SELECT src.FirstName
      ,src.LastName
      ,src.EmailAddress
      ,'I'
      ,@date
FROM   #source src
INNER  JOIN #xref x
ON     src.SK = x.SRC_SK
WHERE  x.ACTION = 'INSERT';

-- UPDATE
UPDATE tgt
SET    Status       = 'U'
      ,ValidTo      = @date
      ,IsCurrent    = 'N'
FROM   #target tgt
INNER  JOIN #xref x
ON     tgt.SK = x.TGT_SK
WHERE  x.ACTION = 'UPDATE'

INSERT INTO #target
(FirstName,LastName,EmailAddress,Status,ValidFrom)
SELECT src.FirstName
      ,src.LastName
      ,src.EmailAddress
      ,'I'
      ,@date
FROM   #source src
INNER  JOIN #xref x
ON     src.SK = x.SRC_SK
WHERE  x.ACTION = 'UPDATE';

-- DELETE
UPDATE tgt
SET    Status       = 'D'
      ,ValidTo      = @date
      ,IsCurrent    = 'N'
FROM   #target tgt
INNER  JOIN #xref x
ON     tgt.SK = x.TGT_SK
WHERE  x.ACTION = 'DELETE'

COMMIT;

SELECT * FROM #source;
SELECT * FROM #target ORDER BY FirstName,LastName,ValidFrom
SELECT * FROM #xref;

END

-- Load #1:  All new rows
TRUNCATE TABLE #target;
EXEC deleteme;


-- Load #2: No change (run the merge again)
-- There should be no change to target
-- Note there is no debug output
EXEC deleteme;


-- Load #3:
-- Record #1 unchanged
-- Record #2 changed (married, new email address)
-- Record #3 deleted
-- Record #4 added
UPDATE #source SET EmailAddress='mary.smith@blah.com' WHERE SK=2;
DELETE FROM #source WHERE SK=3;
INSERT INTO #source
(FirstName,LastName,EmailAddress)
VALUES
('Billy','Bob','william.robert@gmail.com')

EXEC deleteme;
