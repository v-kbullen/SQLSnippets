USE tempdb
GO

DROP TABLE IF Exists ##TempTable
GO

-- Create a large table for demonstration purposes
CREATE TABLE LargeTable (ID INT IDENTITY(1,1), Data CHAR(8000));
GO

--perform a sort operation to fill up internal_obj_pages
SELECT TOP 20000000 LEFT(NEWID(),8000) AS MyNewId
FROM sys.all_objects a
CROSS JOIN sys.all_objects b
ORDER BY LEFT(NEWID(),8000)
GO

--fill a user defined table in the tempdb
SELECT TOP 20000000 LEFT(NEWID(),8000) AS MyNewId
INTO ##TempTable
FROM sys.all_objects a
CROSS JOIN sys.all_objects b
ORDER BY LEFT(NEWID(),8000)
GO

--if AdventureWorks2022 is available
ALTER DATABASE AdventureWorks2022
SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

BEGIN TRAN
UPDATE AdventureWorks2022.Sales.SalesOrderDetail
SET ModifiedDate = DATEADD(n,1,ModifiedDate)
GO

ROLLBACK
GO
