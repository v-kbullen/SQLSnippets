/*
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS 
FOR A PARTICULAR PURPOSE. 

We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute 
the object code form of the Sample Code, provided that You agree: ?
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; ?
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and ?
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, 
that arise or result from the use or distribution of the Sample Code. ?
Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions 
contained within the Premier Customer Services Description. ?
*/

/*
sources: https://www.microsoft.com/en-us/sql-server/blog/2022/07/21/improve-scalability-with-system-page-latch-concurrency-enhancements-in-sql-server-2022/
         https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database?view=sql-server-ver16
*/

/* metadata page types
1 - PFS (page free space) 
    Page which is used any time SQL needs to allocate space to an object
    If SQL Server needs to add some data, SQL Server uses the PFS page to see how full 
    the associated object is to see where the data can fit
    After each 8088 pages, there is another PFS page in the same data file
2 - GAM (Global Allocation Map)
    GAM pages record which extents have been allocated for any use. 
    An extent is a collection of eight contiguous 8 KB pages, totaling 64 KB
    Each GAM page uses a bit to represent the allocation status of each extent. 
    If the bit is set to 1, the extent is free and available for allocation. 
    If the bit is set to 0, the extent is already allocated
    When SQL Server needs to allocate space for a new object 
    it consults the GAM pages to find free extents.
    if there are no free extents, it allocates a new extent
    manages 64k extents (or 4GB data)
3 - SGAM(Shared Global Allocation Map)
    This page is used if SQL needs to allocate space on a mixed extent
    Used for objects < 8 pages (by default all new objects start with a mixed extent)
*/

/* Allocation contention 
Occurs when multiple tasks simultaneously try to allocate pages, 
  leading to delays and performance issues. 
  This can be a common problem in SQL Server, especially under heavy workloads.

High-Concurrency Workloads: Operations like creating and dropping temporary tables, 
  table variables, and work tables for sorting or hashing can lead to high contention.

Mixed Extents: When SQL Server allocates pages from mixed extents, 
 it can cause contention on SGAM pages.
 *changed starting in SQL Server 2016, uses uniform extents in tempdb, not configurable*

Symptoms include:
  High Wait Times: You may notice high wait times for PAGELATCH_UP or PAGELATCH_EX wait types.
  Slow Performance: Queries and operations involving tempdb may become slow or unresponsive
*/

/* Metadata contention
Occurs when multiple sessions simultaneously try to access and modify the system tables in tempdb. 
This contention can lead to performance bottlenecks and decreased query performance

Caused by:
High-Concurrency Workloads: When many sessions create and drop temporary tables, table variables, or other temporary objects, 
  they all need to access the system tables in tempdb to manage these objects.

System Table Access: The contention typically happens on system tables 
 like sysobjects, sysindexes, and syscolumns, which store metadata about the temporary objects

Symptoms include:
  High Wait Times: You may notice high wait times for PAGELATCH_UP or PAGELATCH_EX wait types.
  Slow Performance: Queries and operations involving tempdb may become slow or unresponsive

You can track metadata contention using the same methods you would use to track object allocation contention, 
 the difference is instead of the wait resource being 2:1:1, 2:1:2, 2:1:3 on the PFS, GAM, and SGAM, 
 you are more likely to see the contention occurring on index and data pages and 
 the page number in the wait resource will be a higher value such as 2:1:111, 2:1:118, or 2:1:122
*/

-- <= sql server 2016
SELECT session_id, 
       wait_duration_ms,
	   resource_description
FROM sys.dm_os_waiting_tasks
WHERE wait_type like 'PAGE%LATCH_%'
	--first number refers to the database, 
	--the second number is the file id
	--the last number is the page type (page #1 is the PFS, #2 is the GAM, and #3 is SGAM)
	--ex. 2:7:2
	AND resource_description like '2:%'

-- >= sql server 2019
SELECT er.session_id,
       er.wait_type,
	   er.wait_resource,
	   OBJECT_NAME(page_info.[object_id],page_info.database_id) as [object_name],
	   er.blocking_session_id,
	   er.command,
	   SUBSTRING(st.text, (er.statement_start_offset/2)+1,
	   ((CASE er.statement_end_offset
	         WHEN -1 THEN DATALENGTH(st.text)
	       ELSE er.statement_end_offset
	     END - er.statement_start_offset)/2) + 1) AS statement_text,
	   page_info.database_id,
	   page_info.[file_id],
	   page_info.[page_id],
	   page_info.[object_id]
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
CROSS APPLY sys.fn_PageResCracker (er.page_resource) AS r
CROSS APPLY sys.dm_db_page_info(r.[db_id],r.[file_id],r.page_id,'LIMITED') as page_info
WHERE page_info.database_id = 2
      AND UPPER(er.wait_type) LIKE N'PAGELATCH[_]%'
/*
sys.fn_PageResCracker dynamic management function returns 
  the db_id, file_id, and page_id for the given page_resource value
  
sys.dm_db_page_info dynamic management function returns page information 
  like page_id, file_id, index_id, object_id, and more that are present in a page header.
*/

/*
Any results found on database id 2 indicate that there are requests waiting for tempdb resources 
  and the accumulation of these requests can help database administrators 
  narrow down the root cause of the contention
*/


/* SQL Server 2016 Improvements
 - Trace flags 1117 and 1118 functionality deprecated with SQL 2016+
   1117 - all files in the tempdb database grow at the same time and by the same amount when auto-growth is triggered
   1118 - forces SQL Server to allocate uniform extents instead of mixed extents
*/

/* SQL Server 2019 Improvements
- Concurrent Page Free Space (PFS) page updates reduce page latch contention in all databases, 
  an issue most commonly seen in tempdb. This improvement changes the concurrency management of 
  PFS page updates so that they can be updated under a shared latch, rather than an exclusive latch.
*/

/* SQL Server 2022 Improvements
 - In SQL Server 2022 we allow concurrent updates to the GAM and SGAM under a shared latch rather than using the update latch. 
   This improvement erases nearly all tempdb contention by allowing parallel threads to be able to modify the GAM and SGAM pages.
*/

/* Optimize tempdb performance in SQL Server

 - The size and physical placement of tempdb files can affect performance. 
   For example, if the initial size of tempdb is too small, 
   time and resources might be taken up to autogrow tempdb to the size required 
   to support the workload every time the Database Engine instance is restarted.

 - If possible, use instant file initialization to improve performance of the growth operations for data files.

 - Starting with SQL Server 2022 (16.x), transaction log file growth events up to 64 MB 
   can also benefit from instant file initialization.

 - Preallocate space for all tempdb files by setting the file size to a value large enough 
   to accommodate the typical workload in the environment. 
   Preallocation prevents tempdb from autogrowing too often, which can negatively affect performance.

 - The files in the tempdb database should be set to autogrow to provide space during unplanned growth events.

 - Dividing tempdb into multiple data files of equal size can improve efficiency of operations that use tempdb.

 - To avoid data allocation imbalance, data files should have the same initial size 
   and growth parameters because the Database Engine uses a proportional-fill algorithm 
   that favors allocations in files with more free space.

 - Set the file growth increment to a reasonable size, 
  for example 64 MB, and make the growth increment the same for all data files to prevent growth imbalance.
*/

/* Memory-optimized TempDB metadata
 
 - Temporary object metadata contention has historically been a bottleneck to scalability for many SQL Server workloads. 
 
   To address that, SQL Server 2019 introduced a feature that's part of the in-memory database feature family: Memory-optimized TempDB metadata.
   The system tables involved in managing temporary object metadata can become latch-free, non-durable, memory-optimized tables

 - Limitations:
   - Enabling or disabling the Memory-optimized TempDB metadata feature requires a restart.
   - In certain cases, you might observe high memory usage by the MEMORYCLERK_XTP memory clerk causing out-of-memory errors in your workload
   - When you use In-Memory OLTP, a single transaction is not allowed to access memory-optimized tables in more than one database. 
     Because of this, any transaction that involves a memory-optimized table in a user database can't also access tempdb system views in the same transaction.
   - Queries against system catalog views always use the READ COMMITTED isolation level. 
     When the Memory-optimized TempDB metadata is enabled, queries against system catalog views in tempdb use the SNAPSHOT isolation level. 
     In either case, locking hints are not honored.
   - Columnstore indexes can't be created on temporary tables when Memory-optimized TempDB metadata is enabled.

 - Identifying metadata contention:
	SELECT OBJECT_NAME(dpi.object_id, dpi.database_id) AS system_table_name,
		   COUNT(DISTINCT(r.session_id)) AS session_count
	FROM sys.dm_exec_requests AS r
	CROSS APPLY sys.fn_PageResCracker(r.page_resource) AS prc
	CROSS APPLY sys.dm_db_page_info(prc.db_id, prc.file_id, prc.page_id, 'LIMITED') AS dpi
	WHERE dpi.database_id = 2
		  AND dpi.object_id IN (3, 9, 34, 40, 41, 54, 55, 60, 74, 75)
		  AND UPPER(r.wait_type) LIKE N'PAGELATCH[_]%'
	GROUP BY dpi.object_id, dpi.database_id;
*/
