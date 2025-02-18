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
