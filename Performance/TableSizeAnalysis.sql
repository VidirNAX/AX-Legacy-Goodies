--#######################################################################
--## Author: Vidir Reyr Bjorgvinsson (Vidir Reyr Bjorgvinsson Invest)  ##
--## Comment:                                                          ##
--## Investigates table size and usage.   							   ##
--#######################################################################

SELECT 
    t.NAME AS TableName,
    Max(p.rows) AS RowCounts,
    SUM(a.total_pages) * 8 / 1024 AS TotalSpaceMB, 
    SUM(a.used_pages) * 8 / 1024 AS UsedSpaceMB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 / 1024 AS UnusedSpaceMB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
WHERE 
	1=1
--and	t.name like '%log%'
AND t.is_ms_shipped = 0
AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name
having
	Max(p.rows) > 1000
ORDER BY 
	3 desc