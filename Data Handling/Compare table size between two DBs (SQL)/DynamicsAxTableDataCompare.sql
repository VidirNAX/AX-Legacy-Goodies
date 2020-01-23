--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Comment:                                                          ##
--## Compares Datapage usage of same table in different DB.			   ##
--## Hint: For row accuracy, join partition table to compare rows	   ##
--#######################################################################

Declare @TableName as varchar(100)
declare @DataPages as integer
declare @DataPages2 as integer

create table #tableSizeTmp
(
	 TableName varchar(100)
	,TableSizeMb real
	,TableSizeMb2 real
	,TableSizeKB real
	,TableSizeKB2 real
	,Diff int
)

declare tableSize cursor for
select name 
from sys.tables 
where
	[type]	= 'U'
--and name	like 'DMF%'
order by 1

open tableSize	
fetch from tableSize into @TableName

while @@FETCH_STATUS = 0
begin
	set @DataPages	= (select top 1 t1.dpages from sysindexes T1 where t1.indid in (0,1) and t1.id = OBJECT_ID(@TableName,'U'))
	--## Change DB to compare
	set @DataPages2	= (select top 1 t1.dpages from DynamicsAx.dbo.sysindexes T1 where t1.indid in (0,1) and t1.id = OBJECT_ID(@TableName,'U'))
	insert into #tableSizeTmp Values (@TableName, @DataPages * 8 / 1024, @DataPages2 * 8 / 1024, @DataPages * 8, @DataPages2 * 8, @DataPages-@DataPages2)
	fetch from tableSize into @TableName
end

close tableSize
deallocate tableSize

select * from #tableSizeTmp

drop table #tableSizeTmp
