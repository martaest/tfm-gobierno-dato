-- Carga Bronze -> Silver de la parte WideWorldImporters (datos originales).
-- Misma idea que en banca: limpieza (UPPER/TRIM), desnormalizacion via JOINs y carga incremental por ID. 
-- Deja todo en las tablas Integration.*_Staging.

USE WideWorldImportersDW;
GO


-- DIMENSIONES (7 SPs)

-- CITY
IF OBJECT_ID('ETL.sp_CargarCity','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCity;
GO
CREATE PROCEDURE ETL.sp_CargarCity AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI City ID]) FROM Integration.City_Staging),0);
        CREATE TABLE #TempCity (
            CityID INT, CityName NVARCHAR(50), StateProvinceName NVARCHAR(50),
            CountryName NVARCHAR(60), Continent NVARCHAR(30), SalesTerritory NVARCHAR(50),
            Region NVARCHAR(30), Subregion NVARCHAR(30), Location GEOGRAPHY,
            LatestRecordedPopulation BIGINT, ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempCity
        SELECT c.CityID, c.CityName, sp.StateProvinceName, cnt.CountryName, cnt.Continent,
               sp.SalesTerritory, cnt.Region, cnt.Subregion, c.Location,
               c.LatestRecordedPopulation, c.ValidFrom, c.ValidTo
        FROM WideWorldImporters.Application.Cities c
        JOIN WideWorldImporters.Application.StateProvinces sp ON c.StateProvinceID = sp.StateProvinceID
        JOIN WideWorldImporters.Application.Countries cnt ON sp.CountryID = cnt.CountryID
        WHERE c.CityID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.City_Staging (
                [WWI City ID],[City],[State Province],[Country],
                [Continent],[Sales Territory],[Region],[Subregion],[Location],
                [Latest Recorded Population],[Valid From],[Valid To]
            )
            SELECT CityID, UPPER(TRIM(CityName)), UPPER(TRIM(StateProvinceName)),
                   UPPER(TRIM(CountryName)), UPPER(TRIM(Continent)), UPPER(TRIM(SalesTerritory)),
                   UPPER(TRIM(Region)), UPPER(TRIM(Subregion)), Location,
                   ISNULL(LatestRecordedPopulation,0), ValidFrom, ValidTo
            FROM #TempCity;
        END;
        DROP TABLE #TempCity;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'City_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCity','City_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  City_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCity','City_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CUSTOMER
IF OBJECT_ID('ETL.sp_CargarCustomer','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCustomer;
GO
CREATE PROCEDURE ETL.sp_CargarCustomer AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Customer ID]) FROM Integration.Customer_Staging),0);
        CREATE TABLE #TempCustomer (
            CustomerID INT, CustomerName NVARCHAR(100), BillToCustomerName NVARCHAR(100),
            CategoryName NVARCHAR(50), BuyingGroupName NVARCHAR(50), PrimaryContact NVARCHAR(50),
            PostalCode NVARCHAR(10), ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempCustomer
        SELECT c.CustomerID, c.CustomerName, bill.CustomerName, cat.CustomerCategoryName,
               bg.BuyingGroupName, p.FullName, c.PostalPostalCode, c.ValidFrom, c.ValidTo
        FROM WideWorldImporters.Sales.Customers c
        LEFT JOIN WideWorldImporters.Sales.Customers bill ON c.BillToCustomerID = bill.CustomerID
        LEFT JOIN WideWorldImporters.Sales.CustomerCategories cat ON c.CustomerCategoryID = cat.CustomerCategoryID
        LEFT JOIN WideWorldImporters.Sales.BuyingGroups bg ON c.BuyingGroupID = bg.BuyingGroupID
        LEFT JOIN WideWorldImporters.Application.People p ON c.PrimaryContactPersonID = p.PersonID
        WHERE c.CustomerID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Customer_Staging (
                [WWI Customer ID],[Customer],[Bill To Customer],
                [Category],[Buying Group],[Primary Contact],[Postal Code],[Valid From],[Valid To]
            )
            SELECT CustomerID, UPPER(TRIM(CustomerName)), UPPER(TRIM(BillToCustomerName)),
                   UPPER(TRIM(CategoryName)), ISNULL(UPPER(TRIM(BuyingGroupName)),'N/A'),
                   UPPER(TRIM(PrimaryContact)), LEFT(REPLACE(ISNULL(PostalCode,''),  ' ',''),10),
                   ValidFrom, ValidTo
            FROM #TempCustomer;
        END;
        DROP TABLE #TempCustomer;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Customer_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCustomer','Customer_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Customer_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCustomer','Customer_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- EMPLOYEE
IF OBJECT_ID('ETL.sp_CargarEmployee','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarEmployee;
GO
CREATE PROCEDURE ETL.sp_CargarEmployee AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Employee ID]) FROM Integration.Employee_Staging),0);
        CREATE TABLE #TempEmployee (
            PersonID INT, FullName NVARCHAR(50), PreferredName NVARCHAR(50),
            IsSalesperson BIT, Photo VARBINARY(MAX), ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempEmployee
        SELECT PersonID, FullName, PreferredName, IsSalesperson, Photo, ValidFrom, ValidTo
        FROM WideWorldImporters.Application.People
        WHERE IsEmployee = 1 AND PersonID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Employee_Staging (
                [WWI Employee ID],[Employee],[Preferred Name],
                [Is Salesperson],[Photo],[Valid From],[Valid To]
            )
            SELECT PersonID, UPPER(TRIM(FullName)), LOWER(TRIM(PreferredName)),
                   IsSalesperson, Photo, ValidFrom, ValidTo
            FROM #TempEmployee;
        END;
        DROP TABLE #TempEmployee;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Employee_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEmployee','Employee_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Employee_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEmployee','Employee_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PAYMENTMETHOD
IF OBJECT_ID('ETL.sp_CargarPaymentMethod','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarPaymentMethod;
GO
CREATE PROCEDURE ETL.sp_CargarPaymentMethod AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Payment Method ID]) FROM Integration.PaymentMethod_Staging),0);
        CREATE TABLE #TempPM (
            PaymentMethodID INT, PaymentMethodName NVARCHAR(50),
            ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempPM
        SELECT PaymentMethodID, PaymentMethodName, ValidFrom, ValidTo
        FROM WideWorldImporters.Application.PaymentMethods
        WHERE PaymentMethodID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.PaymentMethod_Staging (
                [WWI Payment Method ID],[Payment Method],[Valid From],[Valid To]
            )
            SELECT PaymentMethodID,
                   REPLACE(UPPER(TRIM(PaymentMethodName)),'CHECK','CHEQUE'),
                   ValidFrom, ValidTo
            FROM #TempPM;
        END;
        DROP TABLE #TempPM;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'PaymentMethod_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPaymentMethod','PaymentMethod_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  PaymentMethod_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPaymentMethod','PaymentMethod_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- STOCKITEM
IF OBJECT_ID('ETL.sp_CargarStockItem','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarStockItem;
GO
CREATE PROCEDURE ETL.sp_CargarStockItem AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Stock Item ID]) FROM Integration.StockItem_Staging),0);
        CREATE TABLE #TempSI (
            StockItemID INT, StockItemName NVARCHAR(100), ColorName NVARCHAR(20),
            SellingPackage NVARCHAR(50), BuyingPackage NVARCHAR(50), Brand NVARCHAR(50),
            Size NVARCHAR(20), LeadTimeDays INT, QuantityPerOuter INT, IsChillerStock BIT,
            Barcode NVARCHAR(50), TaxRate DECIMAL(18,3), UnitPrice DECIMAL(18,2),
            RecommendedRetailPrice DECIMAL(18,2), TypicalWeightPerUnit DECIMAL(18,3),
            Photo VARBINARY(MAX), ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempSI
        SELECT si.StockItemID, si.StockItemName, c.ColorName,
               pkg_outer.PackageTypeName, pkg_unit.PackageTypeName,
               si.Brand, si.Size, si.LeadTimeDays, si.QuantityPerOuter,
               si.IsChillerStock, si.Barcode, si.TaxRate, si.UnitPrice,
               si.RecommendedRetailPrice, si.TypicalWeightPerUnit,
               si.Photo, si.ValidFrom, si.ValidTo
        FROM WideWorldImporters.Warehouse.StockItems si
        LEFT JOIN WideWorldImporters.Warehouse.Colors c ON si.ColorID = c.ColorID
        LEFT JOIN WideWorldImporters.Warehouse.PackageTypes pkg_outer ON si.OuterPackageID = pkg_outer.PackageTypeID
        LEFT JOIN WideWorldImporters.Warehouse.PackageTypes pkg_unit ON si.UnitPackageID = pkg_unit.PackageTypeID
        WHERE si.StockItemID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.StockItem_Staging (
                [WWI Stock Item ID],[Stock Item],[Color],
                [Selling Package],[Buying Package],[Brand],[Size],[Lead Time Days],
                [Quantity Per Outer],[Is Chiller Stock],[Barcode],[Tax Rate],
                [Unit Price],[Recommended Retail Price],[Typical Weight Per Unit],[Photo],
                [Valid From],[Valid To]
            )
            SELECT StockItemID, UPPER(TRIM(StockItemName)),
                   ISNULL(UPPER(TRIM(ColorName)),'N/A'),
                   UPPER(TRIM(SellingPackage)), UPPER(TRIM(BuyingPackage)),
                   ISNULL(UPPER(TRIM(Brand)),'N/A'), ISNULL(UPPER(TRIM(Size)),'N/A'),
                   LeadTimeDays, QuantityPerOuter, IsChillerStock, Barcode,
                   ROUND(TaxRate,3), ROUND(UnitPrice,2), ROUND(RecommendedRetailPrice,2),
                   ROUND(TypicalWeightPerUnit,3), Photo, ValidFrom, ValidTo
            FROM #TempSI;
        END;
        DROP TABLE #TempSI;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'StockItem_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarStockItem','StockItem_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  StockItem_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarStockItem','StockItem_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- SUPPLIER
IF OBJECT_ID('ETL.sp_CargarSupplier','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarSupplier;
GO
CREATE PROCEDURE ETL.sp_CargarSupplier AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Supplier ID]) FROM Integration.Supplier_Staging),0);
        CREATE TABLE #TempSupplier (
            SupplierID INT, SupplierName NVARCHAR(100), CategoryName NVARCHAR(50),
            PrimaryContact NVARCHAR(50), SupplierReference NVARCHAR(20),
            PaymentDays INT, PostalCode NVARCHAR(10),
            ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempSupplier
        SELECT s.SupplierID, s.SupplierName, sc.SupplierCategoryName, p.FullName,
               s.SupplierReference, s.PaymentDays, s.PostalPostalCode, s.ValidFrom, s.ValidTo
        FROM WideWorldImporters.Purchasing.Suppliers s
        LEFT JOIN WideWorldImporters.Purchasing.SupplierCategories sc ON s.SupplierCategoryID = sc.SupplierCategoryID
        LEFT JOIN WideWorldImporters.Application.People p ON s.PrimaryContactPersonID = p.PersonID
        WHERE s.SupplierID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Supplier_Staging (
                [WWI Supplier ID],[Supplier],[Category],
                [Primary Contact],[Supplier Reference],[Payment Days],[Postal Code],
                [Valid From],[Valid To]
            )
            SELECT SupplierID, UPPER(TRIM(SupplierName)), UPPER(TRIM(CategoryName)),
                   UPPER(TRIM(PrimaryContact)), SupplierReference, PaymentDays,
                   LEFT(REPLACE(ISNULL(PostalCode,''),' ',''),10),
                   ValidFrom, ValidTo
            FROM #TempSupplier;
        END;
        DROP TABLE #TempSupplier;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Supplier_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSupplier','Supplier_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Supplier_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSupplier','Supplier_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- TRANSACTIONTYPE
IF OBJECT_ID('ETL.sp_CargarTransactionType','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarTransactionType;
GO
CREATE PROCEDURE ETL.sp_CargarTransactionType AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Transaction Type ID]) FROM Integration.TransactionType_Staging),0);
        CREATE TABLE #TempTT (
            TransactionTypeID INT, TransactionTypeName NVARCHAR(50),
            ValidFrom DATETIME2(7), ValidTo DATETIME2(7)
        );
        INSERT INTO #TempTT
        SELECT TransactionTypeID, TransactionTypeName, ValidFrom, ValidTo
        FROM WideWorldImporters.Application.TransactionTypes
        WHERE TransactionTypeID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.TransactionType_Staging (
                [WWI Transaction Type ID],[Transaction Type],
                [Valid From],[Valid To]
            )
            SELECT TransactionTypeID, UPPER(TRIM(TransactionTypeName)),
                   ValidFrom, ValidTo
            FROM #TempTT;
        END;
        DROP TABLE #TempTT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'TransactionType_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransactionType','TransactionType_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  TransactionType_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransactionType','TransactionType_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- DIMENSIONES ---';
GO

-- HECHOS (6 SPs)

-- STOCKHOLDING
IF OBJECT_ID('ETL.sp_CargarStockHolding','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarStockHolding;
GO
CREATE PROCEDURE ETL.sp_CargarStockHolding AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        -- StockHolding es snapshot completo, borrar y recargar (memory-optimized no soporta TRUNCATE)
        DELETE FROM Integration.StockHolding_Staging;
        CREATE TABLE #TempSH (
            StockItemID INT, QuantityOnHand INT, BinLocation NVARCHAR(20),
            LastStocktakeQuantity INT, LastCostPrice DECIMAL(18,2),
            ReorderLevel INT, TargetStockLevel INT
        );
        INSERT INTO #TempSH
        SELECT StockItemID, QuantityOnHand, BinLocation, LastStocktakeQuantity,
               LastCostPrice, ReorderLevel, TargetStockLevel
        FROM WideWorldImporters.Warehouse.StockItemHoldings;
        SET @Registros = @@ROWCOUNT;
        INSERT INTO Integration.StockHolding_Staging (
            [WWI Stock Item ID],[Quantity On Hand],[Bin Location],[Last Stocktake Quantity],
            [Last Cost Price],[Reorder Level],[Target Stock Level]
        )
        SELECT StockItemID, QuantityOnHand, UPPER(TRIM(BinLocation)),
               LastStocktakeQuantity, ROUND(LastCostPrice,2), ReorderLevel, TargetStockLevel
        FROM #TempSH;
        DROP TABLE #TempSH;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'StockHolding_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarStockHolding','StockHolding_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  StockHolding_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarStockHolding','StockHolding_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- MOVEMENT
IF OBJECT_ID('ETL.sp_CargarMovement','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarMovement;
GO
CREATE PROCEDURE ETL.sp_CargarMovement AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @UltimaFecha DATETIME = ETL.fn_ObtenerUltimaFecha('Movement_Staging');
        CREATE TABLE #TempMov (
            DateKey DATE, StockItemID INT, CustomerID INT, SupplierID INT,
            TransactionTypeID INT, StockItemTransactionID INT,
            InvoiceID INT, PurchaseOrderID INT, Quantity INT
        );
        INSERT INTO #TempMov
        SELECT CONVERT(DATE, TransactionOccurredWhen), StockItemID, CustomerID, SupplierID,
               TransactionTypeID, StockItemTransactionID, InvoiceID, PurchaseOrderID, Quantity
        FROM WideWorldImporters.Warehouse.StockItemTransactions
        WHERE TransactionOccurredWhen > @UltimaFecha;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Movement_Staging (
                [Date Key],[WWI Stock Item ID],[WWI Customer ID],[WWI Supplier ID],
                [WWI Transaction Type ID],[WWI Stock Item Transaction ID],
                [WWI Invoice ID],[WWI Purchase Order ID],[Quantity]
            )
            SELECT * FROM #TempMov;
            DECLARE @NuevaFecha DATETIME;
            SELECT @NuevaFecha = MAX(TransactionOccurredWhen)
            FROM WideWorldImporters.Warehouse.StockItemTransactions;
            EXEC ETL.sp_ActualizarControl 'Movement_Staging', @NuevaFecha, @Registros;
        END;
        DROP TABLE #TempMov;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarMovement','Movement_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Movement_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarMovement','Movement_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- ORDER
IF OBJECT_ID('ETL.sp_CargarOrder','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarOrder;
GO
CREATE PROCEDURE ETL.sp_CargarOrder AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @UltimaFecha DATETIME = ETL.fn_ObtenerUltimaFecha('Order_Staging');
        CREATE TABLE #TempOrder (
            CustomerID INT, StockItemID INT, SalespersonPersonID INT, PickedByPersonID INT,
            OrderID INT, BackorderOrderID INT, OrderDateKey DATE, PickedDateKey DATE,
            Description NVARCHAR(100), Package NVARCHAR(50), Quantity INT,
            UnitPrice DECIMAL(18,2), TaxRate DECIMAL(18,3),
            TotalExcludingTax DECIMAL(18,2), TaxAmount DECIMAL(18,2), TotalIncludingTax DECIMAL(18,2)
        );
        INSERT INTO #TempOrder
        SELECT o.CustomerID, ol.StockItemID, o.SalespersonPersonID, o.PickedByPersonID,
               o.OrderID, o.BackorderOrderID,
               CONVERT(DATE, o.OrderDate),
               CONVERT(DATE, ISNULL(o.PickingCompletedWhen,'1900-01-01')),
               UPPER(TRIM(ol.Description)), UPPER(TRIM(pt.PackageTypeName)),
               ol.Quantity, ROUND(ol.UnitPrice,2), ROUND(ol.TaxRate,2),
               ROUND(ol.Quantity * ol.UnitPrice,2),
               ROUND(ol.Quantity * ol.UnitPrice * ol.TaxRate / 100,2),
               ROUND(ol.Quantity * ol.UnitPrice * (1 + ol.TaxRate / 100),2)
        FROM WideWorldImporters.Sales.Orders o
        JOIN WideWorldImporters.Sales.OrderLines ol ON o.OrderID = ol.OrderID
        JOIN WideWorldImporters.Warehouse.PackageTypes pt ON ol.PackageTypeID = pt.PackageTypeID
        WHERE o.OrderDate > @UltimaFecha;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Order_Staging (
                [WWI Customer ID],[WWI Stock Item ID],[WWI Salesperson ID],[WWI Picker ID],
                [WWI Order ID],[WWI Backorder ID],[Order Date Key],[Picked Date Key],
                [Description],[Package],[Quantity],[Unit Price],[Tax Rate],
                [Total Excluding Tax],[Tax Amount],[Total Including Tax]
            )
            SELECT * FROM #TempOrder;
            DECLARE @NuevaFecha DATETIME;
            SELECT @NuevaFecha = MAX(OrderDate) FROM WideWorldImporters.Sales.Orders;
            EXEC ETL.sp_ActualizarControl 'Order_Staging', @NuevaFecha, @Registros;
        END;
        DROP TABLE #TempOrder;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarOrder','Order_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Order_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarOrder','Order_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PURCHASE
IF OBJECT_ID('ETL.sp_CargarPurchase','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarPurchase;
GO
CREATE PROCEDURE ETL.sp_CargarPurchase AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @UltimaFecha DATETIME = ETL.fn_ObtenerUltimaFecha('Purchase_Staging');
        CREATE TABLE #TempPurchase (
            DateKey DATE, SupplierID INT, StockItemID INT, PurchaseOrderID INT,
            OrderedOuters INT, OrderedQuantity INT, ReceivedOuters INT,
            Package NVARCHAR(50), IsOrderFinalized BIT
        );
        INSERT INTO #TempPurchase
        SELECT CONVERT(DATE, po.OrderDate), po.SupplierID, pol.StockItemID, po.PurchaseOrderID,
               pol.OrderedOuters, pol.OrderedOuters * si.QuantityPerOuter, pol.ReceivedOuters,
               UPPER(TRIM(pt.PackageTypeName)), po.IsOrderFinalized
        FROM WideWorldImporters.Purchasing.PurchaseOrders po
        JOIN WideWorldImporters.Purchasing.PurchaseOrderLines pol ON po.PurchaseOrderID = pol.PurchaseOrderID
        JOIN WideWorldImporters.Warehouse.StockItems si ON pol.StockItemID = si.StockItemID
        JOIN WideWorldImporters.Warehouse.PackageTypes pt ON pol.PackageTypeID = pt.PackageTypeID
        WHERE po.OrderDate > @UltimaFecha;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Purchase_Staging (
                [Date Key],[WWI Supplier ID],[WWI Stock Item ID],[WWI Purchase Order ID],
                [Ordered Outers],[Ordered Quantity],[Received Outers],[Package],[Is Order Finalized]
            )
            SELECT * FROM #TempPurchase;
            DECLARE @NuevaFecha DATETIME;
            SELECT @NuevaFecha = MAX(OrderDate) FROM WideWorldImporters.Purchasing.PurchaseOrders;
            EXEC ETL.sp_ActualizarControl 'Purchase_Staging', @NuevaFecha, @Registros;
        END;
        DROP TABLE #TempPurchase;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPurchase','Purchase_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Purchase_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPurchase','Purchase_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- SALE
IF OBJECT_ID('ETL.sp_CargarSale','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarSale;
GO
CREATE PROCEDURE ETL.sp_CargarSale AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @UltimaFecha DATETIME = ETL.fn_ObtenerUltimaFecha('Sale_Staging');
        CREATE TABLE #TempSale (
            CustomerID INT, BillToCustomerID INT, StockItemID INT, SalespersonPersonID INT,
            InvoiceDateKey DATE, DeliveryDateKey DATE, InvoiceID INT,
            Description NVARCHAR(100), Package NVARCHAR(50), Quantity INT,
            UnitPrice DECIMAL(18,2), TaxRate DECIMAL(18,3),
            TotalExcludingTax DECIMAL(18,2), TaxAmount DECIMAL(18,2), Profit DECIMAL(18,2),
            TotalIncludingTax DECIMAL(18,2), TotalDryItems DECIMAL(18,2), TotalChillerItems DECIMAL(18,2)
        );
        INSERT INTO #TempSale
        SELECT i.CustomerID, i.BillToCustomerID, il.StockItemID, i.SalespersonPersonID,
               CONVERT(DATE, i.InvoiceDate),
               CONVERT(DATE, ISNULL(i.ConfirmedDeliveryTime,'1900-01-01')),
               i.InvoiceID, UPPER(TRIM(il.Description)), UPPER(TRIM(pt.PackageTypeName)),
               il.Quantity, ROUND(il.UnitPrice,2), ROUND(il.TaxRate,2),
               ROUND(il.LineProfit,2), ROUND(il.TaxAmount,2), ROUND(il.LineProfit,2),
               ROUND(il.ExtendedPrice,2),
               CASE WHEN si.IsChillerStock=0 THEN ROUND(il.ExtendedPrice,2) ELSE 0 END,
               CASE WHEN si.IsChillerStock=1 THEN ROUND(il.ExtendedPrice,2) ELSE 0 END
        FROM WideWorldImporters.Sales.Invoices i
        JOIN WideWorldImporters.Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
        JOIN WideWorldImporters.Warehouse.StockItems si ON il.StockItemID = si.StockItemID
        JOIN WideWorldImporters.Warehouse.PackageTypes pt ON il.PackageTypeID = pt.PackageTypeID
        WHERE i.InvoiceDate > @UltimaFecha;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Sale_Staging (
                [WWI Customer ID],[WWI Bill To Customer ID],[WWI Stock Item ID],[WWI Salesperson ID],
                [Invoice Date Key],[Delivery Date Key],[WWI Invoice ID],[Description],[Package],
                [Quantity],[Unit Price],[Tax Rate],[Total Excluding Tax],[Tax Amount],[Profit],
                [Total Including Tax],[Total Dry Items],[Total Chiller Items]
            )
            SELECT * FROM #TempSale;
            DECLARE @NuevaFecha DATETIME;
            SELECT @NuevaFecha = MAX(InvoiceDate) FROM WideWorldImporters.Sales.Invoices;
            EXEC ETL.sp_ActualizarControl 'Sale_Staging', @NuevaFecha, @Registros;
        END;
        DROP TABLE #TempSale;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSale','Sale_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Sale_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSale','Sale_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- TRANSACTION
IF OBJECT_ID('ETL.sp_CargarTransaction','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarTransaction;
GO
CREATE PROCEDURE ETL.sp_CargarTransaction AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @UltimaFecha DATETIME = ETL.fn_ObtenerUltimaFecha('Transaction_Staging');
        CREATE TABLE #TempTrans (
            DateKey DATE, CustomerID INT, BillToCustomerID INT, SupplierID INT,
            TransactionTypeID INT, PaymentMethodID INT,
            CustomerTransactionID INT, SupplierTransactionID INT,
            InvoiceID INT, PurchaseOrderID INT,
            TotalExcludingTax DECIMAL(18,2), TaxAmount DECIMAL(18,2),
            TotalIncludingTax DECIMAL(18,2), OutstandingBalance DECIMAL(18,2), IsFinalized BIT
        );
        INSERT INTO #TempTrans
        SELECT CONVERT(DATE,TransactionDate), CustomerID, NULL, NULL,
               TransactionTypeID, PaymentMethodID, CustomerTransactionID, NULL,
               InvoiceID, NULL,
               ROUND(TransactionAmount,2), ROUND(TaxAmount,2),
               ROUND(TransactionAmount+TaxAmount,2), ROUND(OutstandingBalance,2), IsFinalized
        FROM WideWorldImporters.Sales.CustomerTransactions
        WHERE TransactionDate > @UltimaFecha;

        INSERT INTO #TempTrans
        SELECT CONVERT(DATE,TransactionDate), NULL, NULL, SupplierID,
               TransactionTypeID, PaymentMethodID, NULL, SupplierTransactionID+1000000,
               NULL, PurchaseOrderID,
               ROUND(TransactionAmount,2), ROUND(TaxAmount,2),
               ROUND(TransactionAmount+TaxAmount,2), ROUND(OutstandingBalance,2), IsFinalized
        FROM WideWorldImporters.Purchasing.SupplierTransactions
        WHERE TransactionDate > @UltimaFecha;

        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Transaction_Staging (
                [Date Key],[WWI Customer ID],[WWI Bill To Customer ID],[WWI Supplier ID],
                [WWI Transaction Type ID],[WWI Payment Method ID],
                [WWI Customer Transaction ID],[WWI Supplier Transaction ID],
                [WWI Invoice ID],[WWI Purchase Order ID],
                [Total Excluding Tax],[Tax Amount],[Total Including Tax],
                [Outstanding Balance],[Is Finalized]
            )
            SELECT * FROM #TempTrans;
            DECLARE @NuevaFechaC DATETIME, @NuevaFechaS DATETIME, @NuevaFecha DATETIME;
            SELECT @NuevaFechaC = MAX(TransactionDate) FROM WideWorldImporters.Sales.CustomerTransactions;
            SELECT @NuevaFechaS = MAX(TransactionDate) FROM WideWorldImporters.Purchasing.SupplierTransactions;
            SET @NuevaFecha = CASE WHEN @NuevaFechaC > @NuevaFechaS THEN @NuevaFechaC ELSE @NuevaFechaS END;
            EXEC ETL.sp_ActualizarControl 'Transaction_Staging', @NuevaFecha, @Registros;
        END;
        DROP TABLE #TempTrans;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransaction','Transaction_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Transaction_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransaction','Transaction_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- HECHOS  ---';
PRINT '13 SPs creados';
GO

-- 5.3 MAESTRO BRONZE -> SILVER (WWI)
IF OBJECT_ID('ETL.sp_CargarPlataCompleto','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarPlataCompleto;
GO
CREATE PROCEDURE ETL.sp_CargarPlataCompleto
    @SoloTabla NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @OK INT = 0, @Err INT = 0;

    PRINT 'ETL BRONZE -> SILVER (WWI)';
    PRINT '========================================';

    IF @SoloTabla IS NULL OR @SoloTabla='City_Staging'
    BEGIN TRY EXEC ETL.sp_CargarCity; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR City: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Customer_Staging'
    BEGIN TRY EXEC ETL.sp_CargarCustomer; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Customer: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Employee_Staging'
    BEGIN TRY EXEC ETL.sp_CargarEmployee; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Employee: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='PaymentMethod_Staging'
    BEGIN TRY EXEC ETL.sp_CargarPaymentMethod; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR PaymentMethod: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='StockItem_Staging'
    BEGIN TRY EXEC ETL.sp_CargarStockItem; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR StockItem: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Supplier_Staging'
    BEGIN TRY EXEC ETL.sp_CargarSupplier; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Supplier: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='TransactionType_Staging'
    BEGIN TRY EXEC ETL.sp_CargarTransactionType; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR TransactionType: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='StockHolding_Staging'
    BEGIN TRY EXEC ETL.sp_CargarStockHolding; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR StockHolding: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Movement_Staging'
    BEGIN TRY EXEC ETL.sp_CargarMovement; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Movement: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Order_Staging'
    BEGIN TRY EXEC ETL.sp_CargarOrder; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Order: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Purchase_Staging'
    BEGIN TRY EXEC ETL.sp_CargarPurchase; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Purchase: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Sale_Staging'
    BEGIN TRY EXEC ETL.sp_CargarSale; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Sale: '+ERROR_MESSAGE(); END CATCH;

    IF @SoloTabla IS NULL OR @SoloTabla='Transaction_Staging'
    BEGIN TRY EXEC ETL.sp_CargarTransaction; SET @OK+=1; END TRY
    BEGIN CATCH SET @Err+=1; PRINT 'ERROR Transaction: '+ERROR_MESSAGE(); END CATCH;

    PRINT '========================================';
    PRINT 'OK: '+CAST(@OK AS VARCHAR)+' | Errores: '+CAST(@Err AS VARCHAR);
    PRINT 'Duración: '+CAST(DATEDIFF(SECOND,@Inicio,GETDATE()) AS VARCHAR)+' seg';
    PRINT 'Ver log: SELECT * FROM ETL.LogEjecucion ORDER BY FechaEjecucion DESC';
END;
GO

-- Utilidades
IF OBJECT_ID('ETL.sp_VerificarEstadoETL','P') IS NOT NULL DROP PROCEDURE ETL.sp_VerificarEstadoETL;
GO
CREATE PROCEDURE ETL.sp_VerificarEstadoETL AS
BEGIN
    SET NOCOUNT ON;
    PRINT '--- CONTROL CARGA ---';
    SELECT TablaStagingDestino, UltimaFechaProcesada, Estado, FechaUltimaEjecucion
    FROM ETL.ControlCarga ORDER BY TablaStagingDestino;

    PRINT '--- ULTIMAS 10 EJECUCIONES ---';
    SELECT TOP 10 NombreProceso, TablaDestino, RegistrosCargados,
                  DuracionSegundos, Estado, FechaEjecucion
    FROM ETL.LogEjecucion ORDER BY FechaEjecucion DESC;

    PRINT '--- FILAS EN STAGING ---';
    SELECT 'City_Staging' AS Tabla, COUNT(*) AS Filas FROM Integration.City_Staging
    UNION ALL SELECT 'Customer_Staging', COUNT(*) FROM Integration.Customer_Staging
    UNION ALL SELECT 'Employee_Staging', COUNT(*) FROM Integration.Employee_Staging
    UNION ALL SELECT 'PaymentMethod_Staging', COUNT(*) FROM Integration.PaymentMethod_Staging
    UNION ALL SELECT 'StockItem_Staging', COUNT(*) FROM Integration.StockItem_Staging
    UNION ALL SELECT 'Supplier_Staging', COUNT(*) FROM Integration.Supplier_Staging
    UNION ALL SELECT 'TransactionType_Staging', COUNT(*) FROM Integration.TransactionType_Staging
    UNION ALL SELECT 'Movement_Staging', COUNT(*) FROM Integration.Movement_Staging
    UNION ALL SELECT 'Order_Staging', COUNT(*) FROM Integration.Order_Staging
    UNION ALL SELECT 'Purchase_Staging', COUNT(*) FROM Integration.Purchase_Staging
    UNION ALL SELECT 'Sale_Staging', COUNT(*) FROM Integration.Sale_Staging
    UNION ALL SELECT 'StockHolding_Staging', COUNT(*) FROM Integration.StockHolding_Staging
    UNION ALL SELECT 'Transaction_Staging', COUNT(*) FROM Integration.Transaction_Staging
    ORDER BY Tabla;
END;
GO

IF OBJECT_ID('ETL.sp_LimpiarLogsAntiguos','P') IS NOT NULL DROP PROCEDURE ETL.sp_LimpiarLogsAntiguos;
GO
CREATE PROCEDURE ETL.sp_LimpiarLogsAntiguos @DiasRetencion INT = 90 AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Corte DATETIME = DATEADD(DAY,-@DiasRetencion,GETDATE());
    DELETE FROM ETL.LogEjecucion WHERE FechaEjecucion < @Corte;
    PRINT 'Logs eliminados anteriores a: '+CONVERT(VARCHAR(10),@Corte,120);
END;
GO

PRINT '';
PRINT 'EXEC sp_CargarPlataCompleto';
GO