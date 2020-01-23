--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Comment:                                                          ##
--## Summarize row count per company per table.   					   ##
--#######################################################################

declare @tableName as varchar(100)
declare @crossCompany as int
declare @sqlStr as nvarchar(500)

if object_Id('tempdb..#TableUsage') is null
begin
	create table #TableUsage
	(
		 TableName	varchar(100)
		,DataAreaId	varchar(5)
		,Records	int
	)
end
else
	truncate table #TableUsage
	
declare cur cursor for
select 
	 t1.name
	,case when exists (select 'x' from sys.columns t2 where t2.object_id = t1.object_Id and t2.name = 'DataAreaId') then 0 else 1 end as CrossCompany
from
	sys.tables t1
where
	T1.Type = 'U'
--and	t1.name like 'Sys%'

open cur
fetch cur into @tableName,@crossCompany

while @@FETCH_STATUS = 0
begin
	if @crossCompany = 0
	begin
		set @sqlStr = N'insert into #TableUsage select ''' + @tableName + N''', t1.DATAAREAID, count(distinct t2.RecId) from CompanyInfo t1 with (nolock) left outer join ' + @tableName + N' t2 with (nolock) on t1.DATAAREAID = t2.DATAAREAID group by t1.DATAAREAID'
	end
	else
	begin
		set @sqlStr = 'insert into #TableUsage select ''' + @tableName + ''', ''All'', count(*) from ' + @tableName + ' with (nolock)'
	end

	exec sp_executesql @sqlStr

	fetch cur into @tableName,@crossCompany
end

close cur
deallocate cur

insert into #TableUsage 
select
	 T1.Name
	,'Empty'
	,0 
from 
	sys.tables T1
where
	T1.name not in (select TableName from #TableUsage)
and T1.type	= 'U'
--and name like 'sys%'
--select * from #TableUsage order by 1, 2