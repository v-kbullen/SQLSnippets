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
