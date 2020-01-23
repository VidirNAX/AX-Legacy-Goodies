create procedure TokenAndPermUserStoreCacheMaintenance
as

--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Date: 17.10.2015                                                  ##
--## Comment:                                                          ##
--## Checks for overgrown TokenAndPermUserStore cache and clears is.   ##
--#######################################################################

declare @mbPages int, @mbPagesThreshold int

--## Limit can be adjusted, recommend between 80 and 120 as a starting point
set @mbPagesThreshold = 100

set @mbPages = (select max(pages_kb/1024) from sys.dm_os_memory_clerks where type = 'USERSTORE_TOKENPERM')

if @mbPages > @mbPagesThreshold
begin
	DBCC FREESYSTEMCACHE ('TokenAndPermUserStore')
end