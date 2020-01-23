--########################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  	##
--## Comment:                                                          	##
--## Moves data in smaller bulks.  Used to make many small commits		##
--## but still maintaining atomic transaction and only moves new records##
--## Handy when a small window is available for large dataset			##
--## Drive space for log and datadrive are checked, as well as max time	##
--########################################################################

CREATE procedure [dbo].[VRB_MoveTableIncremental]
(
	 @DataBaseFrom			nvarchar(200)
	,@DataBaseTo			nvarchar(200)
	,@SchemaName			nvarchar(50)
	,@TableName				nvarchar(200)
	,@DataDrives			nvarchar(1)
	,@LogDrives				nvarchar(1)	
	,@CheckOnly				integer = 0
	,@MinDataDriveSpaceMb	integer = 2048	
	,@MinLogDriveSpaceMb	integer = 2048
	,@RecordBulkSize		integer	= 10000
	,@RunTimeMinutes		integer = 60
	,@MaxRecordMove			integer = 0 --## 0 = unlimited ##
)
as

set nocount on

begin try

	declare @checkErrorSeverity integer
	declare	@tableFromFullPath	nvarchar(300)
	declare	@tableToFullPath	nvarchar(300)
	declare @checkErrorMsg		nvarchar(4000)
	declare @tableFromColList	nvarchar(1200)
	declare @tableToColList		nvarchar(1200)
	declare @tmpStrOut			nvarchar(1200)
	declare @tmpIntOut			integer
	declare @sqlStr				nvarchar(4000)
	declare @recTotalCount		integer
	declare @LastMinute			datetime
	declare @BreakReason		varchar(500)
	declare @driveXml           xml	
	declare @tmpSpace           integer
	declare @curRecCnt			integer	
	declare @sourceTableRecCnt	integer
	declare @infoMessage		nvarchar(1000)
	
--## Check Section

	set @checkErrorSeverity = case when @CheckOnly = 1 then 1 else 16 end
	set @tableFromFullPath	= '[' + @DataBaseFrom + '].[' + @SchemaName + '].[' + @TableName + ']'
	set @tableToFullPath	= '[' + @DataBaseTo +	'].[' + @SchemaName + '].[' + @TableName + ']'

	if DB_ID(@DataBaseFrom) is null
	begin
		set @checkErrorMsg = N'From database "' + @DataBaseFrom + '" does not exist'
		raiserror(@checkErrorMsg,@checkErrorSeverity,1)
	end

	if DB_ID(@DataBaseTo) is null
	begin
		set @checkErrorMsg = N'To database "' + @DataBaseTo + '" does not exist'
		raiserror(@checkErrorMsg,@checkErrorSeverity,1)
	end

	if DB_ID(@DataBaseFrom) is not null and OBJECT_ID(@tableFromFullPath) is null
	begin
		set @checkErrorMsg = N'Source table "' + @tableFromFullPath + '" does not exist'
		raiserror(@checkErrorMsg,@checkErrorSeverity,1)
	end

	if DB_ID(@DataBaseTo) is not null and OBJECT_ID(@tableToFullPath) is null
	begin
		set @checkErrorMsg = N'Destination table "' + @tableToFullPath + '" does not exist'
		raiserror(@checkErrorMsg,@checkErrorSeverity,1)
	end

	if OBJECT_ID(@tableToFullPath) is not null and OBJECT_ID(@tableFromFullPath) is not null
	begin
		set @sqlstr = N'DECLARE @listStr NVARCHAR(MAX);' +
					  N'SELECT @listStr = COALESCE(@listStr+'','' ,'''') + Name from [' + @DataBaseFrom + '].sys.columns where object_id = Object_ID(''' + @tableFromFullPath + ''') order by Name;' +
					  N'SELECT @tmpStrOut = @listStr'
		exec sp_executesql @sqlstr, N'@tmpStrOut nvarchar(1200) output',@tmpStrOut = @tableFromColList output

		set @sqlstr = N'DECLARE @listStr NVARCHAR(MAX);' +
					  N'SELECT @listStr = COALESCE(@listStr+'','' ,'''') + Name from [' + @DataBaseTo + '].sys.columns where object_id = Object_ID(''' + @tableToFullPath + ''') order by Name;' +
					  N'SELECT @tmpStrOut = @listStr'
		exec sp_executesql @sqlstr, N'@tmpStrOut nvarchar(1200) output',@tmpStrOut = @tableToColList output
	
		if @tableFromColList <> @tableToColList
		begin
			set @checkErrorMsg = N'Columns on source and destination table mismatch' + char(13) + 
								 N'Column List on source table: ' + @tableFromColList + char(13) + 
								 N'Column List on destination table: ' + @tableToColList
			raiserror(@checkErrorMsg,@checkErrorSeverity,1)
		end
	end
	
	if OBJECT_ID(@tableToFullPath) is not null and OBJECT_ID(@tableFromFullPath) is not null and @tableFromColList = @tableToColList
	begin
		set @sqlstr = N'select @tmpIntOut = par.[rows] from [' + @DataBaseFrom + '].sys.partitions par where par.[object_id] = object_id(''' + @tableFromFullPath + ''') and par.index_id in (0,1)'
		exec sp_executesql @sqlstr, N'@tmpIntOut nvarchar(1200) output',@tmpIntOut = @sourceTableRecCnt output

		set @MaxRecordMove = case when @MaxRecordMove < 1 or @MaxRecordMove > @sourceTableRecCnt then @sourceTableRecCnt else @MaxRecordMove end
		if @MaxRecordMove = 0
		begin
			set @checkErrorMsg = N'No Records in source table: ' + @tableFromFullPath
			raiserror(@checkErrorMsg,@checkErrorSeverity,1)
		end
	end

	if @CheckOnly = 0
	begin
		set @infoMessage = N'Moving ' + CAST(@MaxRecordMove as nvarchar) + ' records from ' + @tableFromFullPath + ' to ' + @tableToFullPath + ' with increment of ' + cast(@RecordBulkSize as nvarchar)
		raiserror(@infoMessage,1,1) with nowait
		
		if object_id('dbo.RecList') is null
		begin
			CREATE TABLE dbo.RecList (DataAreaId nvarchar(5) not null, RecId bigint NOT NULL) ON [PRIMARY]
			ALTER TABLE dbo.RecList ADD CONSTRAINT PK_RecList PRIMARY KEY CLUSTERED (DataAreaId,RecId) ON [PRIMARY]
		end

		set @LastMinute = DATEADD(n,@RunTimeMinutes, GETDATE())
		
		declare @driveSpace Table
		(
			 drive  char(1)
			,mbfree	integer    
		)
		
		set @recTotalCount = 0
		
		while 1=1
		begin
			if @MaxRecordMove <= @recTotalCount
			begin
				set @BreakReason = 'Records moved reached max records: ' + cast(@recTotalCount as varchar)
				break;
			end
			if @LastMinute < getdate()
			begin
				set @BreakReason = 'Maximum run minutes elapsed: ' + cast(@RunTimeMinutes as varchar)
				break;
			end
			
			insert into @driveSpace
			EXEC master.dbo.xp_fixeddrives
			
			if len(@LogDrives) > 1    
			begin
				set @driveXml = N'<root><r>' + replace(@LogDrives,',','</r><r>') + '</r></root>'
				set @tmpSpace = (select top 1 min(mbfree) from @driveSpace where drive in (select t.value('.','char(1)') as [Drives] from @driveXml.nodes('//root/r') as a(t)))
			end
			else                    
				set @tmpSpace = (select top 1 mbfree from @driveSpace where drive = @LogDrives)
				
			if @tmpSpace < @MinLogDriveSpaceMb
			begin
				set @BreakReason = 'Minimum free space on log drive reached: ' + cast(@MinLogDriveSpaceMb as varchar)
				break;
			end

			if len(@DataDrives) > 1    
			begin
				set @driveXml = N'<root><r>' + replace(@DataDrives,',','</r><r>') + '</r></root>'
				set @tmpSpace = (select top 1 min(mbfree) from @driveSpace where drive in (select t.value('.','char(1)') as [Drives] from @driveXml.nodes('//root/r') as a(t)))
			end
			else                    
				set @tmpSpace = (select top 1 mbfree from @driveSpace where drive = @DataDrives)
				
			if @tmpSpace < @MinDataDriveSpaceMb
			begin
				set @BreakReason = 'Minimum free space on data drive reached: ' + cast(@MinDataDriveSpaceMb as varchar)
				break;
			end
			
			set @curRecCnt = case when @MaxRecordMove > 0 and @MaxRecordMove < @recTotalCount + @RecordBulkSize then @MaxRecordMove - @recTotalCount else @RecordBulkSize end
			
			truncate table dbo.RecList
			
			set @sqlStr = 'begin tran tableMove' + char(13) + char(13) + 
						  'insert into RecList select top ' + cast(@curRecCnt as varchar) + ' DataAreaId, RecId from ' + @tableFromFullPath + char(13) + 
						  'insert into ' + @tableToFullPath + '(' + @tableToColList + ')' + char(13) + 
						  'select ' + @tableFromColList + ' from ' + @tableFromFullPath + ' t1 ' + char(13) + 
						  'where exists (select 1 from RecList x1 where x1.DataAreaId = t1.DataAreaId and x1.RecId = t1.Recid)' + CHAR(13) + 
						  'and not exists (select 1 from ' + @tableToFullPath + ' x2 where x2.DataAreaId = t1.DataAreaId and x2.RecId = t1.RecId)' + char(13) + 
						  'delete t1 from ' + @tableFromFullPath + ' t1' + char(13) +
						  'where exists (select 1 from RecList x1 where x1.DataAreaId = t1.DataAreaId and x1.RecId = t1.Recid)' + CHAR(13) + char(13) + 
						  'commit tran tableMove'
						  
			--print @sqlStr
			exec sp_executesql @sqlStr
			
			set @recTotalCount = @recTotalCount + @curRecCnt
			set @infoMessage = N'Records moved: ' + cast(@recTotalCount as nvarchar)
			raiserror(@infoMessage,1,1) with nowait
		end
		print @breakReason
	end
	
	set nocount off
end try

begin catch
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

	set nocount off
	
    SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();

    -- Use RAISERROR inside the CATCH block to return error
    -- information about the original error that caused
    -- execution to jump to the CATCH block.
    RAISERROR (@ErrorMessage, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );
end catch

GO


