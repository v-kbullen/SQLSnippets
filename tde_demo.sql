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

-- create a test database on a test sql server to enable tde
USE master
GO
DROP DATABASE IF EXISTS tdedb;
GO
CREATE DATABASE tdedb;
GO

-- load a table to create some data in this Test database
USE tdedb
GO

CREATE TABLE dbo.Customer
(CustID tinyint IDENTITY,
 CustomerName varchar(30),
 CustomerEmail varchar(30),
 SalesPersonName varchar(5))
GO

INSERT INTO dbo.CUSTOMER VALUES
('Stephen Jiang', 'Stephen.Jiang@adworks.com', 'Jack'),
('Michael Blythe', 'Michael@contoso.com', 'Jack'),
('Linda Mitchell', 'Linda@VolcanoCoffee.org', 'Jack'),
('Jilian Carson', 'JilianC@Northwind.net', 'Jack'),
('Garret Vargas', 'Garret@WorldWideImporters.com', 'Diane'),
('Shu Ito', 'Shu@BlueYonder.com', 'Diane'),
('Sahana Reiter', 'Sahana@CohoVines.com', 'Diane'),
('Syed Abbas','Syed@AlpineSki.com', 'Diane')
GO

-- create master key, certificate
USE master;
GO
IF NOT EXISTS (SELECT * 
               FROM sys.symmetric_keys 
			   WHERE symmetric_key_id = 101)
BEGIN
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SQL$ecurity3SQL$ecurity3';
	PRINT 'Database Master Key Created'
END
ELSE
BEGIN
	PRINT 'Database Master Key Already Exists'
END
GO

IF NOT EXISTS (SELECT * 
               FROM sys.certificates 
			   WHERE name = 'TDETestCert8675309')
BEGIN
	CREATE CERTIFICATE TDETestCert8675309 WITH SUBJECT = 'Certificate for TDE - tdedb'
	PRINT 'Certificate TDETestCert8675309 Created'
END
ELSE
BEGIN
	PRINT 'Certificate TDETestCert8675309 Already Exists'
END
GO

-- create database encryption Key
USE tdedb;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDETestCert8675309;
GO

/*
USE master
GO

SELECT *
FROM sys.certificates

SELECT * 
FROM sys.dm_database_encryption_keys
*/

-- turn on encryption (run both statements together to see the encryption progress)
ALTER DATABASE tdedb SET ENCRYPTION ON;
SELECT * 
FROM sys.dm_database_encryption_keys --(for a brief moment you may see status=2, which means encryption in progess;status=3 is encrypted)
WAITFOR DELAY '00:00:05'
SELECT * 
FROM sys.dm_database_encryption_keys --(for a brief moment you may see status=2, which means encryption in progess;status=3 is encrypted)
GO

--************* most important step: backup certificate and key ************
-- make sure sql server service account has write permission to C:\Temp (and C:\Temp exists)
USE master;
GO
BACKUP CERTIFICATE TDETestCert8675309
TO FILE = 'C:\Temp\TDETestCert8675309.cer'
WITH PRIVATE KEY (FILE = 'C:\Temp\TDETestCert8675309.pvk', 
ENCRYPTION BY PASSWORD = 'SQL$ecurity3SQL$ecurity3')
GO

-- to disable tde  (run both statements together to see the decryption progress)
ALTER DATABASE tdedb SET ENCRYPTION OFF;
SELECT * 
FROM sys.dm_database_encryption_keys --(status=5 means decryption in progess, status = 1 is unencrypted)
WAITFOR DELAY '00:00:05'
SELECT * 
FROM sys.dm_database_encryption_keys --(status=5 means decryption in progess, status = 1 is unencrypted)
GO

USE master
GO
DROP DATABASE IF EXISTS tdedb;
GO

--CAREFUL, WE'RE DROPPING THE CERT
USE master
GO
IF NOT EXISTS (SELECT * 
               FROM sys.certificates 
			   WHERE name = 'TDETestCert8675309')
BEGIN
	DROP CERTIFICATE TDETestCert8675309;
END
GO