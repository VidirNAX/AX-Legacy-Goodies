--############################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  		##
--## Comment:                                                          		##
--## Checks RecID consistency on all table and outputs SQL command to fix.	##
--## Note: Remember to stop the AOS before running this script		   		##
--############################################################################

declare @TableName varchar(100)
declare @TableId integer
declare @MaxRecId bigint
declare @SqlStr nvarchar(200)

--## Temporary table to store results ##
create table #tmpRecIdUpdate
(
	 TableName		varchar(100)
	,TableId		integer
	,CurrentRecId	bigint
	,NewRecId		bigint
)

--## Get current system info about RecId and table data ##
insert into #tmpRecIdUpdate (TableName, TableId, CurrentRecId)
select
	 d.SQLNAME
	,d.TABLEID 
	,s.NEXTVAL
from
	SQLDICTIONARY d
inner join
	SYSTEMSEQUENCES s
		on	s.NAME	= 'SEQNO'
		and	s.TABID	= d.TABLEID
where
	d.FIELDID = 0
and exists (select 'x' from SQLDICTIONARY x where x.TABLEID = d.TABLEID and x.NAME = 'RECID') --## exclude tables without RECID ##

declare allTables cursor for
select TableName from #tmpRecIdUpdate order by 1

open allTables	
fetch from allTables into @TableName

while @@FETCH_STATUS = 0
begin
	--## Get current highest RecId of a table ##
	set @SqlStr = N'select @MaxRecIdOUT = max(recid) from ' + @TableName
	execute sp_executesql @SqlStr, N'@MaxRecIdOUT bigint OUTPUT', @MaxRecIdOUT = @MaxRecId OUTPUT
	if @MaxRecId is not null
	begin
		update #tmpRecIdUpdate set NewRecId = @MaxRecId + 1 where TableName = @TableName
	end

	fetch from allTables into @TableName
end

--select * from #tmpRecIdUpdate
--## Output the results for tables with RecID out of sync and the update syntax to correct it.
select *, SQLUpdateSyntax = 'update SYSTEMSEQUENCES set NEXTVAL = ' + cast(NewRecId as varchar) + ' where TABID = ' + cast(TableId as varchar) + ' and NAME = ''SEQNO'''
from #tmpRecIdUpdate where NewRecId > CurrentRecId

--## clean up ##
close allTables
deallocate allTables

drop table #tmpRecIdUpdate