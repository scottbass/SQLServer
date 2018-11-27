THIS CODE IS INCOMPLETE

/*=====================================================================
Stored Process Name     : sp_MoH_CreateQuotedListV1.sql
Purpose                 : Create a quoted, delimited list from an 
                          input list, and optionally assign it to a
                          variable in the calling code.
SQL Server Version      : Microsoft SQL Server 2012 (SP3) (KB3072779) - 11.0.6020.0 (X64)   

Other Code Called       : udf_MoH_DelimitedSplit8K

Originally Written by   : Scott Bass
Date                    : 24OCT2017
Stored Process Version  : 1.0

=======================================================================

Copyright (c) 2016 Scott Bass (sas_l_739@yahoo.com.au)

This code is licensed under the Unlicense license.
For more information, please refer to http://unlicense.org/UNLICENSE.

=======================================================================

Modification History    : Original version

=====================================================================*/

/*---------------------------------------------------------------------
Usage:

sp_MoH_CreateQuotedListV1 ' foo   bar    blah     blech   ', @Debug=1
sp_MoH_CreateQuotedListV1 @List='foo bar blah blech', @Debug=1

Prints 'foo','bar','blah','blech'.

=======================================================================

DECLARE @FOO VARCHAR(100)
EXEC sp_MoH_CreateQuotedListV1 'foo bar blah blech', @Output=@FOO OUTPUT
PRINT 'FOO: '+@FOO

DECLARE @FOO VARCHAR(100)
EXEC sp_MoH_CreateQuotedListV1 @List='foo bar blah blech', @Output=@FOO OUTPUT
PRINT 'FOO: '+@FOO

Assigns 'foo','bar','blah','blech' to @FOO in the calling program,
which then prints the result.

=======================================================================

DECLARE @FOO VARCHAR(100)
EXEC sp_MoH_CreateQuotedListV1 'foo bar blah blech', @Debug=1, @Output=@FOO OUTPUT
PRINT 'FOO: '+@FOO

DECLARE @FOO VARCHAR(100)
EXEC sp_MoH_CreateQuotedListV1 @List='foo bar blah blech', @Debug=1, @Output=@FOO OUTPUT
PRINT 'FOO: '+@FOO

Prints 'foo','bar','blah','blech' because of the @Debug=1 option.
Assigns 'foo','bar','blah','blech' to @FOO in the calling program,
which then prints the result.

=======================================================================

sp_MoH_CreateQuotedListV1 'foo ^ bar blah  ^   blech   ','^', @Debug=1
sp_MoH_CreateQuotedListV1 @List='foo^bar blah^blech', @Delimiter='^', @Debug=1

Prints 'foo','bar blah','blech'.

Use this if your list contains embedded spaces within the list tokens.
You can use any delimiter that is not present in the data.

=======================================================================

sp_MoH_CreateQuotedListV1 'foo bar blah blech', @QuoteChar='"', @Debug=1
sp_MoH_CreateQuotedListV1 @List='foo bar blah blech', @QuoteChar='"', @Debug=1

Prints "foo","bar","blah","blech".

=======================================================================

DECLARE @MyOutput VARCHAR(100)
EXEC sp_MoH_CreateQuotedListV1 'foo bar blah blech', @QuoteChar='[', @Output=@MyOutput OUTPUT
PRINT @MyOutput

Assigns [foo],[bar],[blah],[blech] to @MyOutput in the calling program,
which then prints the result.

=======================================================================

sp_MoH_CreateQuotedListV1 'foo bar blah blech', @QuoteChar='(', @Debug=1

Prints (foo),(bar),(blah),(blech).

=======================================================================

sp_MoH_CreateQuotedListV1 'foo bar blah blech', @QuoteChar='{', @Debug=1

Prints {foo},{bar},{blah},{blech}.

=======================================================================

sp_MoH_CreateQuotedListV1 'foo bar blah blech', @Separator='|', @Debug=1

Prints 'foo'|'bar'|'blah'|'blech'

=======================================================================

sp_MoH_CreateQuotedListV1 'foo bar blah blech', @QuoteChar='', @Separator='|', @Debug=1

Prints foo|bar|blah|blech.

-----------------------------------------------------------------------
Notes:

>>> I have created the SYNONYM sp_MoH_CreateQuotedList for this stored procedure. <<<

Specify @Debug=1 to review the result in the Messages window.

DECLARE @MyOutput <character variable>,
then specify @Output=@MyOutput OUTPUT to assign the result to a 
variable in your calling program.  

Do not forget the trailing OUTPUT keyword after the variable assignment.

This stored procedure calls sp_MoH_DelimitedSplit8K as a utility 
procedure, which must be available to this stored procedure.

sp_MoH_DelimitedSplit8K parses the input list, returning it as a
table, which then gets recombined as the quoted, delimited list.

To make this stored procedure available to all databases on your
server instance:
   1) Create in the master db with the naming prefix "sp_"
   2) EXECUTE sp_MS_marksystemobject ‘sp_<this SP>’
 See http://sqlserverplanet.com/dba/making-a-procedure-available-in-all-databases

---------------------------------------------------------------------*/

ALTER FUNCTION [dbo].[fn_MoH_CreateQuotedList]
( @Columns                          VARCHAR(8000)
, @Delimiter                        CHAR(1) = ' '
, @QuoteChar                        CHAR(1) = ''''
, @Separator                        CHAR(1) = ','
, @Debug                            BIT = 0
, @Output                           VARCHAR(8000) = '' OUTPUT
)
AS
BEGIN
    DECLARE @quoted_list            VARCHAR(8000) = '';

    IF @QuoteChar != ''
        SET @quoted_list =       
            STUFF(
            (
                SELECT @Separator+QUOTENAME(LTRIM(RTRIM(ds.Item)),@QuoteChar)
                FROM dbo.udf_MoH_DelimitedSplit8K(@List,@Delimiter) ds
                WHERE ds.Item != ''
                FOR XML PATH ('')
            ),1,1,'')
    ELSE
        SET @quoted_list =       
            STUFF(
            (
                SELECT @Separator+LTRIM(RTRIM(ds.Item))
                FROM dbo.udf_MoH_DelimitedSplit8K(@List,@Delimiter) ds
                WHERE ds.Item != ''
                FOR XML PATH ('')
            ),1,1,'')

    SET @Output = @quoted_list;
                
    IF @Debug = 1
        PRINT @Output
END

/******* END OF FILE *******/
