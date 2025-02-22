/*
	Compiling a query plan is a costly thing to do, so SQL Server caches plans 
	for reuse.  For each cached plan it also stores execution statistics for the 
	individual executable statements that comprise the stored procedure, prepared 
	SQL or T-SQL batch.

	We can tap into these statistics to try to find costly statements that might 
	benefit from query or index tuning.

	Below is a series of queries you can use to find the topmost costly statements 
	in terms of average logical reads, CPU time, execution time, and total statement 
	executions.

	You can easily update these statements to use other execution metrics you might 
	find interesting.  In fact, the four queries below differ only in the columns
	used in the ORDER BY clause. 
*/

SET NOCOUNT ON;

-- Highest average logical reads
SELECT  CASE st.dbid WHEN 32767 THEN 'resourcedb' WHEN NULL THEN 'NA' ELSE DB_NAME(st.dbid) END AS [database],
        object_name(st.objectid) AS object_name, SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1,
                  ( ( CASE qs.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE qs.statement_end_offset
                      END - qs.statement_start_offset ) / 2 ) + 1) AS Statements_with_highest_average_logical_reads,
        qs.exec_count, qs.avg_CPU_ms, qs.avg_time_ms, qs.avg_logical_reads,
        qs.avg_logical_writes, qp.query_plan
FROM    ( SELECT TOP (10) 
                    plan_handle, statement_start_offset, statement_end_offset,
                    execution_count AS exec_count,
                    total_worker_time / ( execution_count * 1000 ) AS avg_CPU_ms,
                    ( total_elapsed_time / ( execution_count * 1000 ) ) AS avg_time_ms,
                    CASE WHEN total_logical_reads > 0
                         THEN ( total_logical_reads / execution_count )
                         ELSE 0
                    END AS avg_logical_reads,
                    CASE WHEN total_logical_writes > 0
                         THEN ( total_logical_writes / execution_count )
                         ELSE 0
                    END AS avg_logical_writes
          FROM      sys.dm_exec_query_stats
          ORDER BY  ( total_logical_reads / execution_count ) DESC
        ) AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.avg_logical_reads DESC
OPTION (RECOMPILE);
GO

-- Highest Average CPU
SELECT  CASE st.dbid WHEN 32767 THEN 'resourcedb' WHEN NULL THEN 'NA' ELSE DB_NAME(st.dbid) END AS [database],
        object_name(st.objectid) AS object_name, SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1,
                  ( ( CASE qs.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE qs.statement_end_offset
                      END - qs.statement_start_offset ) / 2 ) + 1) AS Statements_with_highest_average_CPU,
        qs.exec_count, qs.avg_CPU_ms, qs.avg_time_ms, qs.avg_logical_reads,
        qs.avg_logical_writes, qp.query_plan
FROM    ( SELECT TOP (10)
                    plan_handle, statement_start_offset, statement_end_offset,
                    execution_count AS exec_count,
                    total_worker_time / ( execution_count * 1000 ) AS avg_CPU_ms,
                    ( total_elapsed_time / ( execution_count * 1000 ) ) AS avg_time_ms,
                    CASE WHEN total_logical_reads > 0
                         THEN ( total_logical_reads / execution_count )
                         ELSE 0
                    END AS avg_logical_reads,
                    CASE WHEN total_logical_writes > 0
                         THEN ( total_logical_writes / execution_count )
                         ELSE 0
                    END AS avg_logical_writes
          FROM      sys.dm_exec_query_stats
          ORDER BY  ( total_worker_time / execution_count ) DESC
        ) AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.avg_CPU_ms DESC
OPTION (RECOMPILE);	
GO

-- Slowest avg exec times
SELECT  CASE st.dbid WHEN 32767 THEN 'resourcedb' WHEN NULL THEN 'NA' ELSE DB_NAME(st.dbid) END AS [database],
        object_name(st.objectid) AS object_name, SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1,
                  ( ( CASE qs.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE qs.statement_end_offset
                      END - qs.statement_start_offset ) / 2 ) + 1) AS Statements_with_longest_average_duration,
        qs.exec_count, qs.avg_CPU_ms, qs.avg_time_ms, qs.avg_logical_reads,
        qs.avg_logical_writes, qp.query_plan
FROM    ( SELECT TOP (10)
                    plan_handle, statement_start_offset, statement_end_offset,
                    execution_count AS exec_count,
                    total_worker_time / ( execution_count * 1000 ) AS avg_CPU_ms,
                    ( total_elapsed_time / ( execution_count * 1000 ) ) AS avg_time_ms,
                    CASE WHEN total_logical_reads > 0
                         THEN ( total_logical_reads / execution_count )
                         ELSE 0
                    END AS avg_logical_reads,
                    CASE WHEN total_logical_writes > 0
                         THEN ( total_logical_writes / execution_count )
                         ELSE 0
                    END AS avg_logical_writes
          FROM      sys.dm_exec_query_stats
          ORDER BY  ( total_elapsed_time / execution_count ) DESC
        ) AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.avg_time_ms DESC
OPTION (RECOMPILE);	
GO

-- Highest execution counts
SELECT  CASE st.dbid WHEN 32767 THEN 'resourcedb' WHEN NULL THEN 'NA' ELSE DB_NAME(st.dbid) END AS [database],
        object_name(st.objectid) AS object_name, SUBSTRING(st.text, ( qs.statement_start_offset / 2 ) + 1,
                  ( ( CASE qs.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE qs.statement_end_offset
                      END - qs.statement_start_offset ) / 2 ) + 1) AS Statements_with_highest_average_execution_counts,
        qs.exec_count, qs.avg_CPU_ms, qs.avg_time_ms, qs.avg_logical_reads,
        qs.avg_logical_writes, qp.query_plan
FROM    ( SELECT TOP (10)
                    plan_handle, statement_start_offset, statement_end_offset,
                    execution_count AS exec_count,
                    total_worker_time / ( execution_count * 1000 ) AS avg_CPU_ms,
                    ( total_elapsed_time / ( execution_count * 1000 ) ) AS avg_time_ms,
                    CASE WHEN total_logical_reads > 0
                         THEN ( total_logical_reads / execution_count )
                         ELSE 0
                    END AS avg_logical_reads,
                    CASE WHEN total_logical_writes > 0
                         THEN ( total_logical_writes / execution_count )
                         ELSE 0
                    END AS avg_logical_writes
          FROM      sys.dm_exec_query_stats
          ORDER BY  execution_count  DESC
        ) AS qs
        CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.exec_count DESC
OPTION (RECOMPILE);	
GO

/*
	For further Plan Cache exploration...

	Check out what other information is in 

	-- Biggest plans
	SELECT * FROM sys.dm_exec_cached_plans ORDER BY size_in_bytes DESC;

*/
