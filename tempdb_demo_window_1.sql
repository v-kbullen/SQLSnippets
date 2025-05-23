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
sources: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-file-space-usage-transact-sql 
*/

USE tempdb;
GO

/* summary query */
SELECT  SUM(user_object_reserved_page_count) AS user_obj_pages,         --user tables
        SUM(internal_object_reserved_page_count) AS internal_obj_pages, --user worktables (cursors, order by, group by) \ workfiles (hash join and hash aggregate operations)
        SUM(version_store_reserved_page_count) AS version_store_pages,  --row versioning-based isolation levels (RCSI, SI; primary and secondary replicas)
        SUM(unallocated_extent_page_count) AS freespace_pages           --free space
FROM    sys.dm_db_file_space_usage;

/*
If user_obj_kb is the highest consumer, then you that objects are being created by user queries 
 like local or global temp tables or table variables. 
 are any permanent tables created in tempdb.

If version_store_kb is the highest consumer, 
 the version store is growing faster than the clean up. 
*/

/* by file 
   are we proportional */
SELECT 
    [name] AS FileName,
    size * 8 / 1024 AS SizeMB,
    FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 AS SpaceUsedMB,
    (size - FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 AS FreeSpaceMB
FROM 
    sys.master_files
WHERE 
    database_id = DB_ID('tempdb');
GO

SELECT 
	s.login_name,
    s.host_name,
	s.program_name,
    u.session_id,
    u.user_objects_alloc_page_count AS user_alloc_pages,                                         --Number of pages reserved or allocated for user objects by this session
    u.user_objects_dealloc_page_count AS user_dealloc_pages,                                     --Number of pages deallocated and no longer reserved for user objects by this session
    u.user_objects_alloc_page_count - u.user_objects_dealloc_page_count AS user_alloc_pages_net,
	u.internal_objects_alloc_page_count AS internal_alloc_pages,                                 --Number of pages reserved or allocated for internal objects by this session
    u.internal_objects_dealloc_page_count AS internal_dealloc_pages,                             --Number of pages deallocated and no longer reserved for internal objects by this session
    u.internal_objects_alloc_page_count - u.internal_objects_dealloc_page_count AS internal_alloc_pages_net,
	[statement] = COALESCE(NULLIF(
		SUBSTRING(
			t.[text], 
			r.statement_start_offset / 2, 
			CASE WHEN r.statement_end_offset < r.statement_start_offset 
			THEN 0 
			ELSE( r.statement_end_offset - r.statement_start_offset ) / 2 END
		  ), ''
		), t.[text])
FROM sys.dm_db_session_space_usage u
LEFT JOIN sys.dm_exec_sessions s ON u.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.plan_handle) AS t
WHERE 1 = 1 
	AND (u.user_objects_alloc_page_count > 0 OR
	     u.internal_objects_alloc_page_count > 0);
GO

SELECT 
	s.login_name,
    s.host_name,
	s.program_name,
    u.session_id,
    SUM(u.user_objects_alloc_page_count) AS user_alloc_pages,                            --Number of pages reserved or allocated for user objects by this session
    SUM(u.user_objects_dealloc_page_count) AS user_dealloc_pages,                        --Number of pages deallocated and no longer reserved for user objects by this session
    SUM(u.user_objects_alloc_page_count - u.user_objects_dealloc_page_count) as user_alloc_pages_net,
	SUM(u.internal_objects_alloc_page_count) AS internal_alloc_pages,                    --Number of pages reserved or allocated for internal objects by this session
    SUM(u.internal_objects_dealloc_page_count) AS internal_dealloc_pages,                --Number of pages deallocated and no longer reserved for internal objects by this session
    SUM(u.internal_objects_alloc_page_count - u.internal_objects_dealloc_page_count) AS internal_alloc_pages_net
FROM sys.dm_db_task_space_usage u
JOIN sys.dm_exec_sessions s ON u.session_id = s.session_id
JOIN sys.dm_exec_requests AS r ON s.session_id = r.session_id
WHERE 1 = 1 
	AND (u.user_objects_alloc_page_count > 0 OR 
	     u.internal_objects_alloc_page_count > 0)
GROUP BY s.login_name,
         s.host_name,
	     s.program_name,
         u.session_id;

/*
Deferred deallocation occurs when the system is under heavy load or 
 when SQL Server optimizes performance by delaying the deallocation process. 
 This means the pages are marked for deallocation but are not immediately freed. 
 Instead, they are deallocated in the background when the system has more resources available

Cached tables not currently in use will have a name with a # followed by a hex value (e.g., #A8BA2F14), 
 while those in use will have a name with the table's defined name (e.g., #mytesttable_____)
*/


/*
common version store: used for row versions generated by data modification transactions in databases using row versioning-based isolation levels.
online index build version store: used specifically for row versions generated during online index operations
adr (advanced database recovery) - version store moves from the tempdb to user db
*/
SELECT  object_name ,
        counter_name ,
        instance_name ,
        cntr_value ,
        cntr_type
FROM    sys.dm_os_performance_counters
WHERE   counter_name IN ( 'Longest Transaction Running Time' ,
                          'Version Store Size (KB)' ,
						  'Version Cleanup rate (KB/s)' ,
						  'Version Generation rate (KB/s)' );

/*
--identify which active queries by session
SELECT  er.[session_id],
        st.text,
        -- Extract statement from sql text
        ISNULL(NULLIF(SUBSTRING(st.text, er.statement_start_offset / 2,
                                CASE WHEN er.statement_end_offset < er.statement_start_offset
                                        THEN 0
                                        ELSE ( er.statement_end_offset
                                               - er.statement_start_offset )
                                            / 2
                                END), ''), st.text) AS [statement text],
        qp.query_plan
FROM    sys.dm_exec_requests er
        OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS st
        OUTER APPLY sys.dm_exec_query_plan(er.plan_handle) AS qp
WHERE   1 = 1
	AND er.[session_id] <> @@SPID
    AND (st.text IS NOT NULL OR 
		 qp.query_plan IS NOT NULL);
*/
;WITH sp AS
(
    SELECT 
        s.session_id,
        [pages] = SUM((user_objects_alloc_page_count - user_objects_dealloc_page_count) +  
                      (internal_objects_alloc_page_count - internal_objects_dealloc_page_count))
    FROM sys.dm_db_session_space_usage AS s
    GROUP BY s.session_id
    HAVING SUM(s.user_objects_alloc_page_count 
      + s.internal_objects_alloc_page_count) > 0
)
SELECT s.login_name,
       s.host_name,
	   s.program_name,
	   sp.session_id,
	   sp.[pages], 
	   t.[text], 
	   [statement] = COALESCE(NULLIF(
		SUBSTRING(
			t.[text], 
			r.statement_start_offset / 2, 
			CASE WHEN r.statement_end_offset < r.statement_start_offset 
			THEN 0 
			ELSE( r.statement_end_offset - r.statement_start_offset ) / 2 END
		  ), ''
		), t.[text]),
	   qp.query_plan
FROM sp
LEFT JOIN sys.dm_exec_requests AS r ON sp.session_id = r.session_id
LEFT JOIN sys.dm_exec_sessions AS s on sp.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.plan_handle) AS t
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
ORDER BY sp.[pages] DESC;
