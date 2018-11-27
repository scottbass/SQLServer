/*=====================================================================
Function Name           : fn_CleanString.sql
Purpose                 : User Defined Function to:
                          1) Keep or remove characters from a string.
                          2) LTRIM, RTRIM, or STRIP (both) a string.
                          3) UPPER or LOWER case a string.         
SQL Server Version      : Microsoft SQL Server 2012 (SP3) (KB3072779) - 11.0.6020.0 (X64)

Other Code Called       : None

Originally Written by   : Scott Bass
Date                    : 24NOV2017
Stored Process Version  : 1.0

=======================================================================

Modification History    : Original version

=====================================================================*/

/*---------------------------------------------------------------------
Usage:

-- Create a test string
DECLARE @string     VARCHAR(300)=''
       ,@i          INT=0;

WHILE @i < 256 
BEGIN
    SET @string+=CHAR(@i);
    SET @i+=1;
END
SET @string=CONCAT('     ',@string,'          ')

-- Use a cursor to call each test case
DECLARE @Classes    TABLE (class VARCHAR(10));
DECLARE @Cursor     CURSOR
       ,@class      VARCHAR(10)
       ,@out        VARCHAR(8000)
;

SET NOCOUNT ON;
INSERT INTO @Classes VALUES 
(':print:'),
(':alnum:'),
(':alpha:'),
(':upper:'),
(':lower:'),
(':punct:'),
(':ascii:'),
(':cntrl:'),
(':blank:'),
(':graph:'),
(':space:'),
(':word:'),
(':xdigits:'),
('aeiou'),
('aeiouAEIOU');

BEGIN
    SET @Cursor = CURSOR FOR
    SELECT class FROM @Classes;
    OPEN @Cursor;
    FETCH NEXT FROM @Cursor INTO @class;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT @class;

        -- Either use a full path to master.dbo.fn_CleanString
        SELECT @out = master.dbo.fn_CleanString(@string,@class,'keep');
        PRINT 'KEEP:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';

        -- Or create a synonym to master.dbo.fn_CleanString in the current database
        SELECT @out = master.dbo.fn_CleanString(@string,@class,'delete');
        PRINT 'DELETE:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';

        -- Trim test        
        SELECT @out = dbo.fn_CleanString(@string,@class,'keep ltrim');
        PRINT 'LTRIM:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';
                
        SELECT @out = dbo.fn_CleanString(@string,@class,'keep rtrim');
        PRINT 'RTRIM:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';
                
        SELECT @out = dbo.fn_CleanString(@string,@class,'keep strip');
        PRINT 'STRIP:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';

        -- Case tests                
        SELECT @out = dbo.fn_CleanString(@string,@class,'keep strip upper');
        PRINT 'STRIP+UPPER:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';
                
        SELECT @out = dbo.fn_CleanString(@string,@class,'keep strip lower');
        PRINT 'STRIP+LOWER:';
        PRINT CONCAT('OUT: >>>',@out,'<<<');
        PRINT '';
                
        FETCH NEXT FROM @Cursor INTO  @class;
   END;
   CLOSE @Cursor;
   DEALLOCATE @Cursor;
END;

=======================================================================

-- Use an input table
SELECT Name, master.dbo.fn_CleanString(name,':alpha:','KEEP') AS COLUMN_NAME
FROM sys.columns
WHERE CHARINDEX('1',Name) != 0

=======================================================================

-- Use default values
SELECT Name, master.dbo.fn_CleanString(name,default,default) AS COLUMN_NAME
FROM sys.columns
WHERE CHARINDEX('1',Name) != 0

=======================================================================

-- Testing embedded spaces.
-- Note that most of the character classes do not include a space as a valid value.
-- If your data contains valid embedded spaces, use a character class that contains a space
-- (i.e. :print:) as a valid character.  
-- :print: will remove non-print (control + high order ASCII characters) but still preserve embedded spacing.

DECLARE @string VARCHAR(100)=CHAR(0)+CHAR(10)+'   John Doe Sydney, AUSTRALIA       '+CHAR(200)+CHAR(201)+CHAR(202);
PRINT CONCAT('>>>',@string,'<<<');

-- Desired results
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,default,default),'<<<')
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':print:','KEEP'),'<<<')
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':print:','KEEP STRIP'),'<<<')
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':print:','KEEP STRIP UPPER'),'<<<')

-- Undesired results
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':graph:','keep'),'<<<')
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':graph:','keep strip'),'<<<')
SELECT CONCAT('>>>',master.dbo.fn_CleanString(@string,':graph:','keep strip upper'),'<<<')

=======================================================================

-----------------------------------------------------------------------
Notes:

The primary purpose of this code is to remove special characters from
"dirty data".  In most cases, the usage pattern will be:

SELECT dbo.fn_CleanString(some_column,':print:','keep') AS COLUMN_NAME
FROM   some_table

User defined functions do not support ***unspecified*** defaults, 
but the above defaults can be specified via the DEFAULT keyword:

SELECT dbo.fn_CleanString(some_column,default,default) AS COLUMN_NAME
FROM   some_table

This code is based on POSIX character classes.  See:
https://www.regular-expressions.info/posixbrackets.html
https://en.wikibooks.org/wiki/Regular_Expressions/POSIX_Basic_Regular_Expressions
http://www.asciitable.com/

For efficiency I have limited the input string to VARCHAR(8000).
If this does not meet your needs you can change this to VARCHAR(MAX)
but performance may suffer.

If your @pClass parameter is not one of the defined POSIX classes,
it is treated as a literal string of characters to match (or not match)
against the input string or column.  This comparison is case sensitive
due to the specified SQL_Latin1_General_BIN2 collation.  

If you require a case-insensitive match, either specify both 
upper and lower case characters in your literal string, or modify the
code and remove the collation specification.  
(This is a rarely used edge case anyway).

Some of the POSIX character classes are edge cases and will rarely be
used, but I've coded them for completeness against the 
POSIX character class specifications.

There is no validation of the @pClass or @pAction parameters.
Invalid parameters will yield unexpected results (likely NULL).

As this user defined function may be useful across multiple databases,
I recommend creating it in the master database, and either use the 
full three level path (master.dbo.fn_CleanString), or else create a
synonym in the desired databases, pointing to master.dbo.fn_CleanString.

---------------------------------------------------------------------*/

ALTER FUNCTION [dbo].[fn_CleanString]
( @pString                          VARCHAR(8000)
, @pClass                           VARCHAR(10) = ':print:'
, @pAction                          VARCHAR(20) = 'KEEP' 
)
RETURNS VARCHAR(8000) AS
BEGIN
    DECLARE @p                      VARCHAR(128) = ''  -- PATINDEX pattern
           ,@a                      CHAR(1)      = '^' -- KEEP or DELETE prefix
    ;

    IF PATINDEX(':%:',@pClass) != 0
    SET @pClass  = UPPER(@pClass);
    SET @pAction = UPPER(@pAction);

    IF CHARINDEX('DELETE',@pAction) != 0 SET @a = '';

    -- :print:   
    IF @pClass = ':PRINT:' SET @p = ' -~';

    -- :alnum: --
    ELSE
    IF @pClass = ':ALNUM:' SET @p = 'a-zA-Z0-9';

    -- :alpha: --
    ELSE
    IF @pClass = ':ALPHA:' SET @p = 'a-zA-Z';

    -- :upper:   
    ELSE
    IF @pClass = ':UPPER:' SET @p = 'A-Z';

    -- :lower:
    ELSE   
    IF @pClass = ':LOWER:' SET @p = 'a-z';

    -- :punct:  
    ELSE 
    IF @pClass = ':PUNCT:' SET @p = '!-/:-@[-`{-~';  -- Note this is a series of 4 ranges, i.e. ! >>>-<<< /, : >>>-<<< @, etc.

    -- :ascii:   
    ELSE
    IF @pClass = ':ASCII:' SET @p = CONCAT(CHAR(0),'-',CHAR(127));

    -- :cntrl:   
    ELSE
    IF @pClass = ':CNTRL:' SET @p = CONCAT(CHAR(0),'-',CHAR(31),CHAR(127));

    -- :blank: 
    ELSE  
    IF @pClass = ':BLANK:' SET @p = CONCAT(CHAR(9),CHAR(32));

    -- :graph:   
    ELSE
    IF @pClass = ':GRAPH:' SET @p = '!-~';

    -- :space:  
    ELSE 
    IF @pClass = ':SPACE:' SET @p = CONCAT(CHAR(9),'-',CHAR(13),CHAR(32));

    -- :word:   
    ELSE 
    IF @pClass = ':WORD:' SET @p = 'a-zA-Z0-9_';

    -- :xdigits: 
    ELSE
    IF @pClass = ':XDIGITS:' SET @p = 'a-fA-F0-9';

    -- custom string --
    ELSE SET @p = @pClass;

    -- Add wildcards to pattern
    SET @p = CONCAT('%[',@a,@p,']%');

    -- Process the string
    WHILE PATINDEX(@p,@pString COLLATE Latin1_General_BIN2) > 0
        SET @pString = STUFF(@pString,PATINDEX(@p,@pString COLLATE Latin1_General_BIN2),1,'');

    -- Other cleansing
    IF CHARINDEX('STRIP',@pAction) != 0
        SET @pString = LTRIM(RTRIM(@pString));
    ELSE
    IF CHARINDEX('LTRIM',@pAction) != 0
        SET @pString = LTRIM(@pString);
    ELSE
    IF CHARINDEX('RTRIM',@pAction) != 0
        SET @pString = RTRIM(@pString);

    IF CHARINDEX('UPPER',@pAction) != 0
        SET @pString = UPPER(@pString);
    ELSE
    IF CHARINDEX('LOWER',@pAction) != 0
        SET @pString = LOWER(@pString);

    RETURN @pString;

END

/******* END OF FILE *******/
