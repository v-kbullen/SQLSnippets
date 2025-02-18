
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