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

/* drop existing xe if exists */
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'CaptureTempDbCreateTable')
DROP EVENT SESSION [CaptureTempDbCreateTable] ON SERVER;
GO

/* create xe */
CREATE EVENT SESSION [CaptureTempDbCreateTable] ON SERVER 
ADD EVENT sqlserver.object_created(SET collect_database_name=(1)
    ACTION(sqlserver.server_principal_name)
    WHERE ([object_type]='USRTAB' AND [database_id]=(2)))
ADD TARGET package0.ring_buffer(SET max_memory=(8192))
WITH (MAX_MEMORY=4096 KB,
      EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
	  MAX_DISPATCH_LATENCY=30 SECONDS,
	  MAX_EVENT_SIZE=0 KB,
	  MEMORY_PARTITION_MODE=NONE,
	  TRACK_CAUSALITY=OFF,
	  STARTUP_STATE=OFF)
GO

/* start xe */
ALTER EVENT SESSION [CaptureTempDbCreateTable] ON SERVER
STATE = START;
GO
