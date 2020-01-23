--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Comment:                                                          ##
--## Creates views in DW database identical to Table structure in 	   ##
--## Source DB.  Add "with (nolock)" to avoid DW locking tables   	   ##
--#######################################################################

--## Set Source DB
use [SourceDB]

declare @StrPre varchar(1000)
declare @strCol varchar(8000)
declare @strPost varchar(1000)
declare @strRes varchar(8000)
declare @table varchar(50)
declare @prevTable varchar(50)
declare @column varchar(50)
declare @type varchar(20)

declare curSql cursor for
select 
	 TABLE_Name
	,COLUMN_NAME
	,DATA_TYPE
from
	INFORMATION_SCHEMA.COLUMNS
where
	TABLE_NAME in
	(
		 'CUSTINVOICEJOUR'
		,'CUSTINVOICETRANS'
		,'CUSTTABLE'
		,'DIMENSIONS'
		,'EOBORDERTABLE'
		,'FORECASTSALES'
		,'INVENTCLASSSPEC'
		,'INVENTDIM'
		,'INVENTITEMGROUP'
		,'INVENTLOCATION'
		,'INVENTSETTLEMENT'
		,'INVENTSUM'
		,'INVENTTABLE'
		,'INVENTTRANS'
		,'INVENTTRANSPOSTING'
		,'LEDGERTABLE'
		,'LEDGERTRANS'
		,'OLAPTIMEBYDAY'
		,'RETITEMTABLE'
		,'RETJOURNALTABLE'
		,'RETSTORETABLE'
		,'RETTRANSTABLE'
		,'SALESTABLEAIR'
	)
order by 1,2

OPEN curSql

FETCH NEXT FROM curSql 
INTO @table, @column, @type

 
set @StrPre		= 'drop view [' + @table + '] ' + char(13) + char(10) + ' go ' + char(13) + char(10) +
				  'create view [' + @table + '] as' + char(13) + char(10) + 'select' + char(13) + char(10)
set @prevTable	= @table
set @strCol		= CHAR(9) + ' [' + @column + ']' + char(13) + char(10) 
FETCH NEXT FROM curSql 
	INTO @table, @column, @type

--## Set destination DW database
print 'use [Destination DW]' + char(13) + char(10) + 'go'

WHILE @@FETCH_STATUS = 0
BEGIN
	if @prevTable <> @table
	begin
		set @strPost	= 'from' + char(13) + char(10) + CHAR(9) + db_name() + '.DBO.[' + @prevTable + '] with (nolock)' + char(13) + char(10) + 'go' + char(13) + char(10)
		set @strRes		= @StrPre + @strCol + @strPost
		print @strRes
		set @StrPre		= 'drop view [' + @table + '] ' + char(13) + char(10) + ' go ' + char(13) + char(10) +
						  'create view [' + @table + '] as' + char(13) + char(10) + 'select' + char(13) + char(10)
		set @prevTable	= @table
		if @type		= 'numeric'
		begin
			set @strCol		= CHAR(9) + ' cast([' + @column + '] as float) as [' + @column + ']' + char(13) + char(10) 		
		end
		else
			set @strCol		= CHAR(9) + ' [' + @column + ']' + char(13) + char(10) 
	end
	else	
		if @type		= 'numeric'
		begin
			set @strCol		= @strcol + CHAR(9) + ',cast([' + @column + '] as float) as [' + @column + ']' + char(13) + char(10) 		
		end
		else
			set @strCol		= @strcol + CHAR(9) + ',[' + @column + ']' + char(13) + char(10) 


	FETCH NEXT FROM curSql 
	INTO @table, @column, @type
END

set @strPost	= 'from' + char(13) + char(10) + CHAR(9) + db_name() + '.DBO.[' + @prevTable + '] with (nolock)' + char(13) + char(10) + 'go' + char(13) + char(10)
set @strRes		= @StrPre + @strCol + @strPost
print @strRes
		
CLOSE curSql
DEALLOCATE curSql
