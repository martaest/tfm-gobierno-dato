-- Carga Silver -> Gold de WideWorldImporters.
-- Mismo patron que banca (SCD2 en dimensiones, lookup de surrogadas en hechos).
-- Aqui el Date Key va como fecha (DATE) en lugar de entero.
-- 7 dimensiones + 6 hechos + maestro.

USE WideWorldImportersDW;
GO

PRINT 'ETL WWI SILVER -> GOLD';
PRINT '========================================';
GO

-- DIMENSIONES

-- CITY (SCD2: Latest Recorded Population)
IF OBJECT_ID('ETL.sp_CargarDimCity','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimCity;
GO
CREATE PROCEDURE ETL.sp_CargarDimCity AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.City (
            [WWI City ID],[City],[State Province],[Country],[Continent],[Sales Territory],
            [Region],[Subregion],[Location],[Latest Recorded Population],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI City ID],s.[City],s.[State Province],s.[Country],s.[Continent],s.[Sales Territory],
               s.[Region],s.[Subregion],s.[Location],s.[Latest Recorded Population],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.City_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.City d
            WHERE d.[WWI City ID]=s.[WWI City ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCity','Dimension.City',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.City: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCity','Dimension.City',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CUSTOMER (SCD2: Category, Buying Group)
IF OBJECT_ID('ETL.sp_CargarDimCustomer','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimCustomer;
GO
CREATE PROCEDURE ETL.sp_CargarDimCustomer AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Customer d
        JOIN Integration.Customer_Staging s ON d.[WWI Customer ID] = s.[WWI Customer ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (s.[Category]<>d.[Category] OR ISNULL(s.[Buying Group],'')<>ISNULL(d.[Buying Group],''));
        INSERT INTO Dimension.Customer (
            [WWI Customer ID],[Customer],[Bill To Customer],[Category],[Buying Group],
            [Primary Contact],[Postal Code],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Customer ID],s.[Customer],s.[Bill To Customer],s.[Category],s.[Buying Group],
               s.[Primary Contact],s.[Postal Code],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Customer_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Customer d
            WHERE d.[WWI Customer ID]=s.[WWI Customer ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCustomer','Dimension.Customer',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Customer: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCustomer','Dimension.Customer',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- EMPLOYEE (SCD2: Is Salesperson)
IF OBJECT_ID('ETL.sp_CargarDimEmployee','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimEmployee;
GO
CREATE PROCEDURE ETL.sp_CargarDimEmployee AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.Employee (
            [WWI Employee ID],[Employee],[Preferred Name],[Is Salesperson],[Photo],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Employee ID],s.[Employee],s.[Preferred Name],s.[Is Salesperson],s.[Photo],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Employee_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Employee d
            WHERE d.[WWI Employee ID]=s.[WWI Employee ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEmployee','Dimension.Employee',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Employee: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEmployee','Dimension.Employee',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PAYMENT METHOD (sin SCD2)
IF OBJECT_ID('ETL.sp_CargarDimPaymentMethod','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimPaymentMethod;
GO
CREATE PROCEDURE ETL.sp_CargarDimPaymentMethod AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.[Payment Method] (
            [WWI Payment Method ID],[Payment Method],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Payment Method ID],s.[Payment Method],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.PaymentMethod_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.[Payment Method] d
            WHERE d.[WWI Payment Method ID]=s.[WWI Payment Method ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimPaymentMethod','Dimension.Payment Method',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Payment Method: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimPaymentMethod','Dimension.Payment Method',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- STOCK ITEM (SCD2: Unit Price, Recommended Retail Price)
IF OBJECT_ID('ETL.sp_CargarDimStockItem','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimStockItem;
GO
CREATE PROCEDURE ETL.sp_CargarDimStockItem AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.[Stock Item] d
        JOIN Integration.StockItem_Staging s ON d.[WWI Stock Item ID] = s.[WWI Stock Item ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (ISNULL(s.[Unit Price],0)<>ISNULL(d.[Unit Price],0)
            OR ISNULL(s.[Recommended Retail Price],0)<>ISNULL(d.[Recommended Retail Price],0));
        INSERT INTO Dimension.[Stock Item] (
            [WWI Stock Item ID],[Stock Item],[Color],[Selling Package],[Buying Package],[Brand],[Size],
            [Lead Time Days],[Quantity Per Outer],[Is Chiller Stock],[Barcode],[Tax Rate],[Unit Price],
            [Recommended Retail Price],[Typical Weight Per Unit],[Photo],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Stock Item ID],s.[Stock Item],s.[Color],s.[Selling Package],s.[Buying Package],s.[Brand],s.[Size],
               s.[Lead Time Days],s.[Quantity Per Outer],s.[Is Chiller Stock],s.[Barcode],s.[Tax Rate],s.[Unit Price],
               s.[Recommended Retail Price],s.[Typical Weight Per Unit],s.[Photo],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.StockItem_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.[Stock Item] d
            WHERE d.[WWI Stock Item ID]=s.[WWI Stock Item ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimStockItem','Dimension.Stock Item',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Stock Item: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimStockItem','Dimension.Stock Item',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- SUPPLIER (SCD2: Category)
IF OBJECT_ID('ETL.sp_CargarDimSupplier','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimSupplier;
GO
CREATE PROCEDURE ETL.sp_CargarDimSupplier AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Supplier d
        JOIN Integration.Supplier_Staging s ON d.[WWI Supplier ID] = s.[WWI Supplier ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND s.[Category]<>d.[Category];
        INSERT INTO Dimension.Supplier (
            [WWI Supplier ID],[Supplier],[Category],[Primary Contact],[Supplier Reference],
            [Payment Days],[Postal Code],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Supplier ID],s.[Supplier],s.[Category],s.[Primary Contact],s.[Supplier Reference],
               s.[Payment Days],s.[Postal Code],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Supplier_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Supplier d
            WHERE d.[WWI Supplier ID]=s.[WWI Supplier ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimSupplier','Dimension.Supplier',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Supplier: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimSupplier','Dimension.Supplier',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- TRANSACTION TYPE (sin SCD2)
IF OBJECT_ID('ETL.sp_CargarDimTransactionType','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimTransactionType;
GO
CREATE PROCEDURE ETL.sp_CargarDimTransactionType AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.[Transaction Type] (
            [WWI Transaction Type ID],[Transaction Type],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Transaction Type ID],s.[Transaction Type],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.TransactionType_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.[Transaction Type] d
            WHERE d.[WWI Transaction Type ID]=s.[WWI Transaction Type ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimTransactionType','Dimension.Transaction Type',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Transaction Type: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimTransactionType','Dimension.Transaction Type',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- DIMENSIONES GOLD  ---';
GO

-- HECHOS (lookup claves surrogadas; Date Key = fecha DATE directa)

-- F1: STOCK HOLDING (snapshot, lookup Stock Item; DELETE+recarga)
IF OBJECT_ID('ETL.sp_CargarFactStockHolding','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactStockHolding;
GO
CREATE PROCEDURE ETL.sp_CargarFactStockHolding AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DELETE FROM Fact.[Stock Holding];
        INSERT INTO Fact.[Stock Holding] (
            [Stock Item Key],[Quantity On Hand],[Bin Location],[Last Stocktake Quantity],
            [Last Cost Price],[Reorder Level],[Target Stock Level],[Lineage Key]
        )
        SELECT
            ISNULL((SELECT TOP 1 [Stock Item Key] FROM Dimension.[Stock Item]
                     WHERE [WWI Stock Item ID]=s.[WWI Stock Item ID] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
            s.[Quantity On Hand],s.[Bin Location],s.[Last Stocktake Quantity],
            s.[Last Cost Price],s.[Reorder Level],s.[Target Stock Level],1
        FROM Integration.StockHolding_Staging s;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactStockHolding','Fact.Stock Holding',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Stock Holding: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactStockHolding','Fact.Stock Holding',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F2: MOVEMENT (lookup StockItem+Customer+Supplier+TransactionType)
IF OBJECT_ID('ETL.sp_CargarFactMovement','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactMovement;
GO
CREATE PROCEDURE ETL.sp_CargarFactMovement AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Stock Item Transaction ID]) FROM Fact.Movement),0);
        INSERT INTO Fact.Movement (
            [Date Key],[Stock Item Key],[Customer Key],[Supplier Key],[Transaction Type Key],
            [WWI Stock Item Transaction ID],[WWI Invoice ID],[WWI Purchase Order ID],[Quantity],[Lineage Key]
        )
        SELECT
            s.[Date Key],
            ISNULL(dsi.[Stock Item Key],0),
            ISNULL(dc.[Customer Key],0),
            ISNULL(dsup.[Supplier Key],0),
            ISNULL(dtt.[Transaction Type Key],0),
            s.[WWI Stock Item Transaction ID],s.[WWI Invoice ID],s.[WWI Purchase Order ID],s.[Quantity],1
        FROM Integration.Movement_Staging s
        LEFT JOIN Dimension.[Stock Item] dsi ON dsi.[WWI Stock Item ID]=s.[WWI Stock Item ID] AND dsi.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Customer dc ON dc.[WWI Customer ID]=s.[WWI Customer ID] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Supplier dsup ON dsup.[WWI Supplier ID]=s.[WWI Supplier ID] AND dsup.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.[Transaction Type] dtt ON dtt.[WWI Transaction Type ID]=s.[WWI Transaction Type ID] AND dtt.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Stock Item Transaction ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactMovement','Fact.Movement',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Movement: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactMovement','Fact.Movement',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F3: ORDER (lookup City+Customer+StockItem+Salesperson+Picker)
IF OBJECT_ID('ETL.sp_CargarFactOrder','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactOrder;
GO
CREATE PROCEDURE ETL.sp_CargarFactOrder AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Order ID]) FROM Fact.[Order]),0);
        INSERT INTO Fact.[Order] (
            [City Key],[Customer Key],[Stock Item Key],[Order Date Key],[Picked Date Key],
            [Salesperson Key],[Picker Key],[WWI Order ID],[WWI Backorder ID],[Description],[Package],
            [Quantity],[Unit Price],[Tax Rate],[Total Excluding Tax],[Tax Amount],[Total Including Tax],[Lineage Key]
        )
        SELECT
            0,
            ISNULL(dc.[Customer Key],0),
            ISNULL(dsi.[Stock Item Key],0),
            s.[Order Date Key],s.[Picked Date Key],
            ISNULL(dsp.[Employee Key],0),
            ISNULL(dpk.[Employee Key],0),
            s.[WWI Order ID],s.[WWI Backorder ID],s.[Description],s.[Package],
            s.[Quantity],s.[Unit Price],s.[Tax Rate],s.[Total Excluding Tax],s.[Tax Amount],s.[Total Including Tax],1
        FROM Integration.Order_Staging s
        LEFT JOIN Dimension.Customer dc ON dc.[WWI Customer ID]=s.[WWI Customer ID] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.[Stock Item] dsi ON dsi.[WWI Stock Item ID]=s.[WWI Stock Item ID] AND dsi.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Employee dsp ON dsp.[WWI Employee ID]=s.[WWI Salesperson ID] AND dsp.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Employee dpk ON dpk.[WWI Employee ID]=s.[WWI Picker ID] AND dpk.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Order ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactOrder','Fact.Order',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Order: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactOrder','Fact.Order',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F4: PURCHASE (lookup Supplier+StockItem)
IF OBJECT_ID('ETL.sp_CargarFactPurchase','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactPurchase;
GO
CREATE PROCEDURE ETL.sp_CargarFactPurchase AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Purchase Order ID]) FROM Fact.Purchase),0);
        INSERT INTO Fact.Purchase (
            [Date Key],[Supplier Key],[Stock Item Key],[WWI Purchase Order ID],
            [Ordered Outers],[Ordered Quantity],[Received Outers],[Package],[Is Order Finalized],[Lineage Key]
        )
        SELECT
            s.[Date Key],
            ISNULL(dsup.[Supplier Key],0),
            ISNULL(dsi.[Stock Item Key],0),
            s.[WWI Purchase Order ID],s.[Ordered Outers],s.[Ordered Quantity],s.[Received Outers],
            s.[Package],s.[Is Order Finalized],1
        FROM Integration.Purchase_Staging s
        LEFT JOIN Dimension.Supplier dsup ON dsup.[WWI Supplier ID]=s.[WWI Supplier ID] AND dsup.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.[Stock Item] dsi ON dsi.[WWI Stock Item ID]=s.[WWI Stock Item ID] AND dsi.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Purchase Order ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactPurchase','Fact.Purchase',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Purchase: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactPurchase','Fact.Purchase',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F5: SALE (lookup Customer+BillToCustomer+StockItem+Salesperson)
IF OBJECT_ID('ETL.sp_CargarFactSale','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactSale;
GO
CREATE PROCEDURE ETL.sp_CargarFactSale AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Invoice ID]) FROM Fact.Sale),0);
        INSERT INTO Fact.Sale (
            [City Key],[Customer Key],[Bill To Customer Key],[Stock Item Key],[Invoice Date Key],[Delivery Date Key],
            [Salesperson Key],[WWI Invoice ID],[Description],[Package],[Quantity],[Unit Price],[Tax Rate],
            [Total Excluding Tax],[Tax Amount],[Profit],[Total Including Tax],[Total Dry Items],[Total Chiller Items],[Lineage Key]
        )
        SELECT
            0,
            ISNULL(dc.[Customer Key],0),
            ISNULL(dbc.[Customer Key],0),
            ISNULL(dsi.[Stock Item Key],0),
            s.[Invoice Date Key],s.[Delivery Date Key],
            ISNULL(dsp.[Employee Key],0),
            s.[WWI Invoice ID],s.[Description],s.[Package],s.[Quantity],s.[Unit Price],s.[Tax Rate],
            s.[Total Excluding Tax],s.[Tax Amount],s.[Profit],s.[Total Including Tax],s.[Total Dry Items],s.[Total Chiller Items],1
        FROM Integration.Sale_Staging s
        LEFT JOIN Dimension.Customer dc ON dc.[WWI Customer ID]=s.[WWI Customer ID] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Customer dbc ON dbc.[WWI Customer ID]=s.[WWI Bill To Customer ID] AND dbc.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.[Stock Item] dsi ON dsi.[WWI Stock Item ID]=s.[WWI Stock Item ID] AND dsi.[Valid To]='9999-12-31 23:59:59.9999999'
        LEFT JOIN Dimension.Employee dsp ON dsp.[WWI Employee ID]=s.[WWI Salesperson ID] AND dsp.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Invoice ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactSale','Fact.Sale',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Sale: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactSale','Fact.Sale',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F6: TRANSACTION (lookup Customer+Supplier+TransactionType+PaymentMethod)
IF OBJECT_ID('ETL.sp_CargarFactTransaction','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactTransaction;
GO
CREATE PROCEDURE ETL.sp_CargarFactTransaction AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxKey INT = ISNULL((SELECT MAX([Transaction Key]) FROM Fact.[Transaction]),0);
        -- Insertar todo (no hay ID unico de negocio fiable combinando customer+supplier), control por Transaction Key surrogate
        -- Para evitar duplicados, solo cargar si la tabla esta vacia o usar incremental por fecha
        DECLARE @filas INT = (SELECT COUNT(*) FROM Fact.[Transaction]);
        IF @filas = 0
        BEGIN
            INSERT INTO Fact.[Transaction] (
                [Date Key],[Customer Key],[Bill To Customer Key],[Supplier Key],[Transaction Type Key],[Payment Method Key],
                [WWI Customer Transaction ID],[WWI Supplier Transaction ID],[WWI Invoice ID],[WWI Purchase Order ID],
                [Supplier Invoice Number],[Total Excluding Tax],[Tax Amount],[Total Including Tax],[Outstanding Balance],[Is Finalized],[Lineage Key]
            )
            SELECT
                s.[Date Key],
                ISNULL(dc.[Customer Key],0),0,
                ISNULL(dsup.[Supplier Key],0),
                ISNULL(dtt.[Transaction Type Key],0),
                ISNULL(dpm.[Payment Method Key],0),
                s.[WWI Customer Transaction ID],s.[WWI Supplier Transaction ID],s.[WWI Invoice ID],s.[WWI Purchase Order ID],
                NULL,s.[Total Excluding Tax],s.[Tax Amount],s.[Total Including Tax],s.[Outstanding Balance],s.[Is Finalized],1
            FROM Integration.Transaction_Staging s
            LEFT JOIN Dimension.Customer dc ON dc.[WWI Customer ID]=s.[WWI Customer ID] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
            LEFT JOIN Dimension.Supplier dsup ON dsup.[WWI Supplier ID]=s.[WWI Supplier ID] AND dsup.[Valid To]='9999-12-31 23:59:59.9999999'
            LEFT JOIN Dimension.[Transaction Type] dtt ON dtt.[WWI Transaction Type ID]=s.[WWI Transaction Type ID] AND dtt.[Valid To]='9999-12-31 23:59:59.9999999'
            LEFT JOIN Dimension.[Payment Method] dpm ON dpm.[WWI Payment Method ID]=s.[WWI Payment Method ID] AND dpm.[Valid To]='9999-12-31 23:59:59.9999999';
            SET @Registros = @@ROWCOUNT;
        END;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactTransaction','Fact.Transaction',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Transaction: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactTransaction','Fact.Transaction',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- HECHOS GOLD  ---';
GO

-- MAESTRO SILVER -> GOLD WWI
IF OBJECT_ID('ETL.sp_CargarOroWWI','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarOroWWI;
GO
CREATE PROCEDURE ETL.sp_CargarOroWWI AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @OK INT = 0, @Err INT = 0;
    PRINT 'ETL WWI SILVER -> GOLD';
    PRINT '========================================';
    PRINT '--- DIMENSIONES ---';
    BEGIN TRY EXEC ETL.sp_CargarDimCity; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimCity: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimCustomer; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimCustomer: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimEmployee; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimEmployee: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimPaymentMethod; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimPayment: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimStockItem; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimStockItem: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimSupplier; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimSupplier: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimTransactionType; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimTransType: '+ERROR_MESSAGE(); END CATCH;

    PRINT '--- HECHOS ---';
    BEGIN TRY EXEC ETL.sp_CargarFactStockHolding; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactStockHolding: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactMovement; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactMovement: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactOrder; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactOrder: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactPurchase; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactPurchase: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactSale; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactSale: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactTransaction; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactTransaction: '+ERROR_MESSAGE(); END CATCH;

    PRINT '========================================';
    PRINT 'OK: '+CAST(@OK AS VARCHAR)+' | Errores: '+CAST(@Err AS VARCHAR);
    PRINT 'Duración: '+CAST(DATEDIFF(SECOND,@Inicio,GETDATE()) AS VARCHAR)+' seg';
END;
GO

PRINT '';
PRINT 'Para ejecutar: EXEC ETL.sp_CargarOroWWI';
GO
