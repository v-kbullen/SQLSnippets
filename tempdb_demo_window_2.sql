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
ALTER DATABASE WideWorldImporters 
SET READ_COMMITTED_SNAPSHOT ON 
WITH ROLLBACK IMMEDIATE;
*/

USE [tempdb]
GO
--turn live stats on
drop table if exists #orderinfo

--run:
--1. results to grid, live stats
--2. results to #table, live stats

select o.*
into #orderinfo
from wideworldimporters.sales.orders o
join wideworldimporters.sales.orderlines ol on o.orderid = ol.orderid
where o.orderdate = '2025-01-22'
order by ol.taxrate;

--3. update, open tran
begin tran

update wideworldimporters.sales.orders
set orderdate = CAST(DATEADD(day, 0, orderdate) AS DATE), LastEditedWhen = GETDATE()

rollback tran
