/* Run once

IF OBJECT_ID('tempdb.dbo.#source') IS NOT NULL DROP TABLE #source;
IF OBJECT_ID('tempdb.dbo.#target') IS NOT NULL DROP TABLE #target;
IF OBJECT_ID('tempdb.dbo.#debug')  IS NOT NULL DROP TABLE #debug;

-- Conditions:
-- 1) Source data is not SCD2
-- 2) Target data is not SCD2
-- 3) Use BINARY_CHECKSUM for Change Data Capture
-- 4) Physically delete target rows not in source

CREATE TABLE #source
( SK            INT IDENTITY(1,1)
, FirstName     VARCHAR(20)
, LastName      VARCHAR(30)
, EmailAddress  VARCHAR(50)
)

CREATE TABLE #target
( SK            INT
, FirstName     VARCHAR(20)
, LastName      VARCHAR(30)
, EmailAddress  VARCHAR(50)
, Status        CHAR(1)
, BCS           INT
)

CREATE TABLE #debug
( ACTION        CHAR(6)
, SK            INT
, FirstName     VARCHAR(20)
, LastName      VARCHAR(30)
, EmailAddress  VARCHAR(50)
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

TRUNCATE TABLE #debug
INSERT INTO #debug
SELECT
     ACTION
    ,SK
    ,FirstName
    ,LastName
    ,EmailAddress
FROM (

MERGE #target tgt
USING #source src
ON (tgt.SK = src.SK)

-- New Rows
WHEN NOT MATCHED
THEN INSERT
(
     SK
    ,FirstName
    ,LastName
    ,EmailAddress
    ,Status
    ,BCS
)
VALUES (
     src.SK
    ,src.FirstName
    ,src.LastName
    ,src.EmailAddress
    ,'I'
    ,BINARY_CHECKSUM(
         src.SK
        ,src.FirstName
        ,src.LastName
        ,src.EmailAddress
    )
)

-- Changed Rows
-- Use BINARY_CHECKSUM comparison to detect actual changes
WHEN MATCHED
 AND (tgt.BCS <> BINARY_CHECKSUM(
                     src.SK
                    ,src.FirstName
                    ,src.LastName
                    ,src.EmailAddress
                 )
     )
THEN UPDATE
SET  tgt.FirstName      = src.FirstName
    ,tgt.LastName       = src.LastName
    ,tgt.EmailAddress   = src.EmailAddress
    ,tgt.Status         = 'U'
    ,tgt.BCS            = BINARY_CHECKSUM(
                             src.SK
                            ,src.FirstName
                            ,src.LastName
                            ,src.EmailAddress
                        )

-- Physically delete target rows not in source
WHEN NOT MATCHED BY SOURCE
THEN DELETE

-- Stream output to outer query
OUTPUT
     $ACTION
    ,src.SK
    ,src.FirstName
    ,src.LastName
    ,src.EmailAddress
)
AS changes
(
     ACTION
    ,SK
    ,FirstName
    ,LastName
    ,EmailAddress
)
;

SELECT * FROM #source
SELECT * FROM #target
SELECT * FROM #debug

END

-- Load #1:  All new rows
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
UPDATE #source SET LastName='Smith',EmailAddress='mary.smith@blah.com' WHERE SK=2;
DELETE FROM #source WHERE SK=3;
INSERT INTO #source
(FirstName,LastName,EmailAddress)
VALUES
('Billy','Bob','william.robert@gmail.com')

EXEC deleteme;
