create procedure QueryPlanCacheMaintenance
as

--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Date: 17.10.2015                                                  ##
--## Comment:                                                          ##
--## Checks for overgrown cache and clears is.                         ##
--## If applicable, checks if node is active node in failover scheme.  ##
--## Gather DynamicsPerf stats befor flushing if applicable            ##
--#######################################################################

declare @mbSingleUseCachePlans as decimal(9,2), @isActiveNode int, @captureDynPerf int, @cacheMaxLimit int

--## Choose applicable line
set @isActiveNode	= 1
--set @isActiveNode	= (1 - master.dbo.isDatabaseAlwaysOn(DB_ID('MyProdDB'))) | master.dbo.isDatabasePrimaryReplica(DB_ID('MyProdDB')) -- database not in AlwaysOn or is a primary replica

--## If DynamicsPerf is not capturing data, then set to 0
set @captureDynPerf	= 1

--## Limit can be adjusted and should be evaluated depending on hardware, perhaps try between 2000 and 3000 as a starting point (2-3GB)
set @cacheMaxLimit	= 2000

if @isActiveNode = 1
begin
	select @mbSingleUseCachePlans = sum(t1.size_in_bytes / 1024.00 / 1024.00)
	from sys.dm_exec_cached_plans t1
	where t1.usecounts = 1

	if @mbSingleUseCachePlans > @cacheMaxLimit
	begin
		--## Enable code if DynamicsPerf is installed -->
		--if @captureDynPerf = 1
		--begin
		--	exec SP_CAPTURESTATS @DATABASE_NAME = 'AXPROD' , @SKIP_STATS = 'N'	
		--end
		--## Comment out if DynamicsPerf is not installed <--
		
		DBCC FreeProcCache
	end
end
