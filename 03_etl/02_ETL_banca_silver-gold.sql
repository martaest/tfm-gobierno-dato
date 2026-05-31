-- Carga Silver -> Gold del dominio banca.
-- Las dimensiones aplican SCD2: si un atributo controlado cambia se cierra la version vigente 
-- y se inserta una fila nueva, asi queda el historico. Los hechos resuelven las claves surrogadas 
-- contra las dimensiones y calculan el Date Key con fn_DateKey. 
-- 9 dimensiones, 8 hechos y maestro.

USE WideWorldImportersDW;
GO

PRINT 'ETL BANCA SILVER -> GOLD';

GO

-- DIMENSIONES (SCD2 donde aplica)

-- CENTRO (SCD2: Nombre, Estado, NumeroEmpleados)
IF OBJECT_ID('ETL.sp_CargarDimCentro','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimCentro;
GO
CREATE PROCEDURE ETL.sp_CargarDimCentro AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        -- Cerrar registros que cambiaron
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Centro d
        JOIN Integration.Centro_Staging s ON d.[WWI Centro ID] = s.[WWI Centro ID]
        WHERE d.[Valid To] = '9999-12-31 23:59:59.9999999'
          AND (s.[Nombre Centro]<>d.[Nombre Centro]
            OR s.[Estado Centro]<>d.[Estado Centro]
            OR ISNULL(s.[Numero Empleados],0)<>ISNULL(d.[Numero Empleados],0));
        -- Insertar nuevos y versiones nuevas
        INSERT INTO Dimension.Centro (
            [WWI Centro ID],[Codigo Centro],[Nombre Centro],[Tipo Centro],[Direccion Completa],
            [Codigo Postal],[Localidad],[Provincia],[Zona Geografica],[Numero Empleados],
            [Fecha Apertura],[Fecha Cierre],[Estado Centro],[Centro Padre Key],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Centro ID],s.[Codigo Centro],s.[Nombre Centro],s.[Tipo Centro],s.[Direccion Completa],
               s.[Codigo Postal],s.[Localidad],s.[Provincia],s.[Zona Geografica],s.[Numero Empleados],
               s.[Fecha Apertura],s.[Fecha Cierre],s.[Estado Centro],NULL,
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Centro_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Centro d
            WHERE d.[WWI Centro ID]=s.[WWI Centro ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCentro','Dimension.Centro',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Centro: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCentro','Dimension.Centro',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- ENTIDAD FINANCIERA (sin SCD2, catálogo estable)
IF OBJECT_ID('ETL.sp_CargarDimEntidadFinanciera','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimEntidadFinanciera;
GO
CREATE PROCEDURE ETL.sp_CargarDimEntidadFinanciera AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.EntidadFinanciera (
            [WWI Entidad ID],[Codigo Entidad],[Nombre Entidad],[NIF],[Tipo Entidad],
            [Pais],[Es Vigente],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Entidad ID],s.[Codigo Entidad],s.[Nombre Entidad],s.[NIF],s.[Tipo Entidad],
               s.[Pais],s.[Es Vigente],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.EntidadFinanciera_Staging s
        WHERE NOT EXISTS (SELECT 1 FROM Dimension.EntidadFinanciera d WHERE d.[WWI Entidad ID]=s.[WWI Entidad ID]);
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEntidadFinanciera','Dimension.EntidadFinanciera',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.EntidadFinanciera: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEntidadFinanciera','Dimension.EntidadFinanciera',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CLASIFICACION RIESGO (sin SCD2)
IF OBJECT_ID('ETL.sp_CargarDimClasificacionRiesgo','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimClasificacionRiesgo;
GO
CREATE PROCEDURE ETL.sp_CargarDimClasificacionRiesgo AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.ClasificacionRiesgo (
            [Codigo Clasificacion],[Nombre Clasificacion],[Descripcion],
            [Nivel Riesgo],[Porcentaje Provision],[Es Vigente],[Lineage Key]
        )
        SELECT s.[Codigo Clasificacion],s.[Nombre Clasificacion],s.[Descripcion],
               s.[Nivel Riesgo],s.[Porcentaje Provision],s.[Es Vigente],1
        FROM Integration.ClasificacionRiesgo_Staging s
        WHERE NOT EXISTS (SELECT 1 FROM Dimension.ClasificacionRiesgo d WHERE d.[Codigo Clasificacion]=s.[Codigo Clasificacion]);
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimClasificacionRiesgo','Dimension.ClasificacionRiesgo',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.ClasificacionRiesgo: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimClasificacionRiesgo','Dimension.ClasificacionRiesgo',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PRODUCTO (SCD2: TAE, TIN, EsComercializable)
IF OBJECT_ID('ETL.sp_CargarDimProducto','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimProducto;
GO
CREATE PROCEDURE ETL.sp_CargarDimProducto AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Producto d
        JOIN Integration.Producto_Staging s ON d.[WWI Producto ID] = s.[WWI Producto ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (ISNULL(s.[TAE],0)<>ISNULL(d.[TAE],0)
            OR ISNULL(s.[TIN],0)<>ISNULL(d.[TIN],0)
            OR s.[Es Comercializable]<>d.[Es Comercializable]);
        INSERT INTO Dimension.Producto (
            [WWI Producto ID],[Codigo Producto],[Nombre Producto],[Descripcion],[Tipo Producto],
            [Categoria Producto],[TAE],[TIN],[Comision],[Requiere Garantia],[Es Comercializable],
            [Fecha Lanzamiento],[Fecha Retiro],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Producto ID],s.[Codigo Producto],s.[Nombre Producto],s.[Descripcion],s.[Tipo Producto],
               s.[Categoria Producto],s.[TAE],s.[TIN],s.[Comision],s.[Requiere Garantia],s.[Es Comercializable],
               s.[Fecha Lanzamiento],s.[Fecha Retiro],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Producto_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Producto d
            WHERE d.[WWI Producto ID]=s.[WWI Producto ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimProducto','Dimension.Producto',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Producto: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimProducto','Dimension.Producto',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CLIENTE (SCD2: Segmento, Provincia, EsActivo)
IF OBJECT_ID('ETL.sp_CargarDimCliente','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimCliente;
GO
CREATE PROCEDURE ETL.sp_CargarDimCliente AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Cliente d
        JOIN Integration.Cliente_Staging s ON d.[WWI Cliente ID] = s.[WWI Cliente ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (ISNULL(s.[Segmento],'')<>ISNULL(d.[Segmento],'')
            OR ISNULL(s.[Provincia],'')<>ISNULL(d.[Provincia],'')
            OR s.[Es Cliente Activo]<>d.[Es Cliente Activo]);
        INSERT INTO Dimension.Cliente (
            [WWI Cliente ID],[Tipo Cliente],[Numero Documento],[Nombre Completo],
            [Fecha Nacimiento Constitucion],[Edad],[Sexo],[Nacionalidad],[Forma Juridica],[CNAE],
            [Email],[Telefono Movil],[Direccion Completa],[Codigo Postal],[Localidad],[Provincia],[Pais],
            [Segmento],[Subsegmento],[Potencial Negocio],[Es Cliente Activo],[Fecha Alta],[Fecha Baja],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Cliente ID],s.[Tipo Cliente],s.[Numero Documento],s.[Nombre Completo],
               s.[Fecha Nacimiento Constitucion],s.[Edad],s.[Sexo],s.[Nacionalidad],s.[Forma Juridica],s.[CNAE],
               s.[Email],s.[Telefono Movil],s.[Direccion Completa],s.[Codigo Postal],s.[Localidad],s.[Provincia],s.[Pais],
               s.[Segmento],s.[Subsegmento],s.[Potencial Negocio],s.[Es Cliente Activo],s.[Fecha Alta],s.[Fecha Baja],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Cliente_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Cliente d
            WHERE d.[WWI Cliente ID]=s.[WWI Cliente ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCliente','Dimension.Cliente',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Cliente: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCliente','Dimension.Cliente',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PERFIL RIESGO (SCD2: Score, NivelRiesgo)
IF OBJECT_ID('ETL.sp_CargarDimPerfilRiesgo','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimPerfilRiesgo;
GO
CREATE PROCEDURE ETL.sp_CargarDimPerfilRiesgo AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.PerfilRiesgo d
        JOIN Integration.PerfilRiesgo_Staging s ON d.[WWI Cliente ID] = s.[WWI Cliente ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (ISNULL(s.[Score Credito],0)<>ISNULL(d.[Score Credito],0)
            OR ISNULL(s.[Nivel Riesgo],'')<>ISNULL(d.[Nivel Riesgo],''));
        INSERT INTO Dimension.PerfilRiesgo (
            [WWI Cliente ID],[Score Credito],[Nivel Riesgo],[Probabilidad Impago],
            [Limite Endeudamiento],[Modelo Scoring],[Numero Transacciones Mes],
            [Volumen Mensual Operaciones],[Tiene Operativa Inusual],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Cliente ID],s.[Score Credito],s.[Nivel Riesgo],s.[Probabilidad Impago],
               s.[Limite Endeudamiento],s.[Modelo Scoring],s.[Numero Transacciones Mes],
               s.[Volumen Mensual Operaciones],s.[Tiene Operativa Inusual],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.PerfilRiesgo_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.PerfilRiesgo d
            WHERE d.[WWI Cliente ID]=s.[WWI Cliente ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimPerfilRiesgo','Dimension.PerfilRiesgo',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.PerfilRiesgo: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimPerfilRiesgo','Dimension.PerfilRiesgo',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- GARANTIA (sin SCD2)
IF OBJECT_ID('ETL.sp_CargarDimGarantia','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimGarantia;
GO
CREATE PROCEDURE ETL.sp_CargarDimGarantia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        INSERT INTO Dimension.Garantia (
            [WWI Garantia ID],[Tipo Garantia],[Descripcion Garantia],[Valor Tasacion],
            [Fecha Tasacion],[Entidad Tasadora],[Tiene Seguro],[Estado Garantia],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Garantia ID],s.[Tipo Garantia],s.[Descripcion Garantia],s.[Valor Tasacion],
               s.[Fecha Tasacion],s.[Entidad Tasadora],s.[Tiene Seguro],s.[Estado Garantia],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Garantia_Staging s
        WHERE NOT EXISTS (SELECT 1 FROM Dimension.Garantia d WHERE d.[WWI Garantia ID]=s.[WWI Garantia ID]);
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimGarantia','Dimension.Garantia',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Garantia: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimGarantia','Dimension.Garantia',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- EMPLEADO (SCD2: Puesto, Estado)
IF OBJECT_ID('ETL.sp_CargarDimEmpleado','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimEmpleado;
GO
CREATE PROCEDURE ETL.sp_CargarDimEmpleado AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Empleado d
        JOIN Integration.Empleado_Staging s ON d.[WWI Empleado ID] = s.[WWI Empleado ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND (s.[Puesto]<>d.[Puesto] OR s.[Estado Empleado]<>d.[Estado Empleado]);
        INSERT INTO Dimension.Empleado (
            [WWI Empleado ID],[Numero Empleado],[Nombre Completo],[Email],[Departamento],
            [Centro Asignado],[Puesto],[Categoria],[Supervisor],[Fecha Alta],[Fecha Baja],
            [Estado Empleado],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Empleado ID],s.[Numero Empleado],s.[Nombre Completo],s.[Email],s.[Departamento],
               s.[Centro Asignado],s.[Puesto],s.[Categoria],s.[Supervisor],s.[Fecha Alta],s.[Fecha Baja],
               s.[Estado Empleado],GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Empleado_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Empleado d
            WHERE d.[WWI Empleado ID]=s.[WWI Empleado ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEmpleado','Dimension.Empleado',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Empleado: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimEmpleado','Dimension.Empleado',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CUENTA (SCD2: EstadoCuenta) - lookup Cliente Key
IF OBJECT_ID('ETL.sp_CargarDimCuenta','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarDimCuenta;
GO
CREATE PROCEDURE ETL.sp_CargarDimCuenta AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        UPDATE d SET d.[Valid To] = GETDATE()
        FROM Dimension.Cuenta d
        JOIN Integration.Cuenta_Staging s ON d.[WWI Cuenta ID] = s.[WWI Cuenta ID]
        WHERE d.[Valid To]='9999-12-31 23:59:59.9999999'
          AND s.[Estado Cuenta]<>d.[Estado Cuenta];
        INSERT INTO Dimension.Cuenta (
            [WWI Cuenta ID],[Numero Cuenta],[Tipo Cuenta],[Producto],[Cliente Key],[Nombre Cliente],
            [Fecha Apertura],[Fecha Cierre],[Tiene Nomina Domiciliada],[TAE Aplicado],
            [Estado Cuenta],[Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT s.[WWI Cuenta ID],s.[Numero Cuenta],s.[Tipo Cuenta],s.[Producto],
               ISNULL((SELECT TOP 1 [Cliente Key] FROM Dimension.Cliente
                        WHERE [WWI Cliente ID]=s.[Cliente ID] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
               s.[Nombre Cliente],s.[Fecha Apertura],s.[Fecha Cierre],s.[Tiene Nomina Domiciliada],
               s.[TAE Aplicado],s.[Estado Cuenta],s.[Sucursal Gestion],
               GETDATE(),'9999-12-31 23:59:59.9999999',1
        FROM Integration.Cuenta_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM Dimension.Cuenta d
            WHERE d.[WWI Cuenta ID]=s.[WWI Cuenta ID] AND d.[Valid To]='9999-12-31 23:59:59.9999999'
        );
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCuenta','Dimension.Cuenta',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Dimension.Cuenta: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarDimCuenta','Dimension.Cuenta',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- DIMENSIONES GOLD BANCA OK (9/9) ---';
GO

-- HECHOS (lookup claves surrogadas + Date Key entero via fn_DateKey)

-- F1: MOVIMIENTO (lookup Cuenta+Cliente por Numero Cuenta)
IF OBJECT_ID('ETL.sp_CargarFactMovimiento','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactMovimiento;
GO
CREATE PROCEDURE ETL.sp_CargarFactMovimiento AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Movimiento ID]) FROM Fact.Movimiento),0);
        INSERT INTO Fact.Movimiento (
            [Fecha Movimiento Key],[Fecha Valor Key],[Cuenta Key],[Cliente Key],[Tipo Movimiento],
            [Concepto],[Importe Movimiento],[Saldo Despues Movimiento],[Canal Operacion],
            [Centro Key],[WWI Movimiento ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Movimiento]),
            ETL.fn_DateKey(s.[Fecha Valor]),
            ISNULL(dc.[Cuenta Key],0),
            ISNULL(dc.[Cliente Key],0),
            s.[Tipo Movimiento],s.[Concepto],s.[Importe Movimiento],s.[Saldo Despues Movimiento],
            s.[Canal Operacion],0,s.[WWI Movimiento ID],1
        FROM Integration.Movimiento_Staging s
        LEFT JOIN Dimension.Cuenta dc ON dc.[Numero Cuenta]=s.[Numero Cuenta]
            AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Movimiento ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactMovimiento','Fact.Movimiento',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Movimiento: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactMovimiento','Fact.Movimiento',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F2: SALDO CUENTA (lookup Cuenta+Cliente por Numero Cuenta, incremental por Fecha Key)
IF OBJECT_ID('ETL.sp_CargarFactSaldoCuenta','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactSaldoCuenta;
GO
CREATE PROCEDURE ETL.sp_CargarFactSaldoCuenta AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxKey INT = ISNULL((SELECT MAX([Fecha Key]) FROM Fact.SaldoCuenta),0);
        INSERT INTO Fact.SaldoCuenta (
            [Fecha Key],[Cuenta Key],[Cliente Key],[Producto Key],[Saldo Apertura],[Saldo Cierre],
            [Saldo Promedio],[Numero Movimientos],[Importe Total Entradas],[Importe Total Salidas],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha]),
            ISNULL(dc.[Cuenta Key],0),
            ISNULL(dc.[Cliente Key],0),
            0,
            s.[Saldo Apertura],s.[Saldo Cierre],s.[Saldo Promedio],s.[Numero Movimientos],
            s.[Importe Total Entradas],s.[Importe Total Salidas],1
        FROM Integration.SaldoDiario_Staging s
        LEFT JOIN Dimension.Cuenta dc ON dc.[Numero Cuenta]=s.[Numero Cuenta]
            AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE ETL.fn_DateKey(s.[Fecha]) > @MaxKey;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactSaldoCuenta','Fact.SaldoCuenta',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.SaldoCuenta: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactSaldoCuenta','Fact.SaldoCuenta',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F3: CREDITO (lookup Cliente+Producto; cuotas calculadas desde Cuota_Staging)
IF OBJECT_ID('ETL.sp_CargarFactCredito','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactCredito;
GO
CREATE PROCEDURE ETL.sp_CargarFactCredito AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Credito ID]) FROM Fact.Credito),0);
        INSERT INTO Fact.Credito (
            [Fecha Formalizacion Key],[Fecha Snapshot Key],[Cliente Key],[Producto Key],
            [Garantia Key],[Centro Key],[Numero Contrato],[Tipo Credito],[Importe Concedido],
            [Importe Pendiente],[Capital Pendiente],[Intereses Devengados],[TIN Aplicado],[TAE Aplicado],
            [Plazo Meses],[Cuotas Pendientes],[Cuotas Impagadas],[Dias Retraso Maximo],[Provision Dotada],
            [Estado Prestamo],[WWI Credito ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Formalizacion]),
            ETL.fn_DateKey(CAST(GETDATE() AS DATE)),
            ISNULL((SELECT TOP 1 [Cliente Key] FROM Dimension.Cliente
                     WHERE [WWI Cliente ID]=s.[Cliente ID] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
            ISNULL((SELECT TOP 1 [Producto Key] FROM Dimension.Producto
                     WHERE [Nombre Producto]=s.[Producto] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
            0,0,
            s.[Numero Contrato],s.[Tipo Credito],s.[Importe Concedido],s.[Importe Pendiente],
            s.[Importe Pendiente],0,s.[TIN Aplicado],s.[TAE Aplicado],s.[Plazo Meses],
            ISNULL((SELECT COUNT(*) FROM Integration.Cuota_Staging c WHERE c.[Numero Contrato]=s.[Numero Contrato] AND c.[Estado Cuota]='PENDIENTE'),0),
            ISNULL((SELECT COUNT(*) FROM Integration.Cuota_Staging c WHERE c.[Numero Contrato]=s.[Numero Contrato] AND c.[Estado Cuota]='IMPAGADA'),0),
            ISNULL((SELECT MAX(c.[Dias Retraso]) FROM Integration.Cuota_Staging c WHERE c.[Numero Contrato]=s.[Numero Contrato]),0),
            0,
            s.[Estado Prestamo],s.[WWI Credito ID],1
        FROM Integration.Credito_Staging s
        WHERE s.[WWI Credito ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCredito','Fact.Credito',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Credito: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCredito','Fact.Credito',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F4: CUOTA PRESTAMO (lookup Cliente via Credito_Staging por Numero Contrato)
IF OBJECT_ID('ETL.sp_CargarFactCuotaPrestamo','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactCuotaPrestamo;
GO
CREATE PROCEDURE ETL.sp_CargarFactCuotaPrestamo AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Cuota ID]) FROM Fact.CuotaPrestamo),0);
        INSERT INTO Fact.CuotaPrestamo (
            [Fecha Vencimiento Key],[Fecha Pago Key],[Cliente Key],[Numero Contrato],[Numero Cuota],
            [Importe Cuota],[Importe Capital],[Importe Intereses],[Importe Comisiones],[Capital Pendiente],
            [Importe Pagado],[Estado Cuota],[Dias Retraso],[WWI Cuota ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Vencimiento]),
            ETL.fn_DateKey(s.[Fecha Pago]),
            ISNULL((SELECT TOP 1 dc.[Cliente Key]
                     FROM Integration.Credito_Staging cr
                     JOIN Dimension.Cliente dc ON cr.[Cliente ID]=dc.[WWI Cliente ID]
                     WHERE cr.[Numero Contrato]=s.[Numero Contrato] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'),0),
            s.[Numero Contrato],s.[Numero Cuota],s.[Importe Cuota],s.[Importe Capital],s.[Importe Intereses],
            s.[Importe Comisiones],s.[Capital Pendiente],s.[Importe Pagado],s.[Estado Cuota],s.[Dias Retraso],
            s.[WWI Cuota ID],1
        FROM Integration.Cuota_Staging s
        WHERE s.[WWI Cuota ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCuotaPrestamo','Fact.CuotaPrestamo',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.CuotaPrestamo: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCuotaPrestamo','Fact.CuotaPrestamo',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F5: TRANSFERENCIA (lookup Cuenta+Cliente por Cuenta Origen)
IF OBJECT_ID('ETL.sp_CargarFactTransferencia','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactTransferencia;
GO
CREATE PROCEDURE ETL.sp_CargarFactTransferencia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Transferencia ID]) FROM Fact.Transferencia),0);
        INSERT INTO Fact.Transferencia (
            [Fecha Operacion Key],[Fecha Valor Key],[Cuenta Origen Key],[Cliente Key],[Tipo Transferencia],
            [Numero Operacion],[Nombre Beneficiario],[Pais Destino],[Importe Transferencia],
            [Comision Aplicada],[Estado Transferencia],[Canal Operacion],[Es Pago Recurrente],[Es SEPA],
            [WWI Transferencia ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Operacion]),
            ETL.fn_DateKey(s.[Fecha Valor]),
            ISNULL(dc.[Cuenta Key],0),
            ISNULL(dc.[Cliente Key],0),
            s.[Tipo Transferencia],s.[Numero Operacion],s.[Nombre Beneficiario],s.[Pais Destino],
            s.[Importe Transferencia],s.[Comision Aplicada],s.[Estado Transferencia],s.[Canal Operacion],
            s.[Es Pago Recurrente],s.[Es SEPA],s.[WWI Transferencia ID],1
        FROM Integration.Transferencia_Staging s
        LEFT JOIN Dimension.Cuenta dc ON dc.[Numero Cuenta]=s.[Cuenta Origen]
            AND dc.[Valid To]='9999-12-31 23:59:59.9999999'
        WHERE s.[WWI Transferencia ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactTransferencia','Fact.Transferencia',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Transferencia: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactTransferencia','Fact.Transferencia',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F6: PROVISION (lookup Cliente via Credito + ClasificacionRiesgo por Nombre)
IF OBJECT_ID('ETL.sp_CargarFactProvision','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactProvision;
GO
CREATE PROCEDURE ETL.sp_CargarFactProvision AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Provision ID]) FROM Fact.Provision),0);
        INSERT INTO Fact.Provision (
            [Fecha Provision Key],[Cliente Key],[Clasificacion Riesgo Key],[Numero Contrato],
            [Tipo Provision],[Importe Provisionado],[Importe Recuperado],[Saldo Provision],
            [Porcentaje Provision],[WWI Provision ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Provision]),
            ISNULL((SELECT TOP 1 dc.[Cliente Key]
                     FROM Integration.Credito_Staging cr
                     JOIN Dimension.Cliente dc ON cr.[Cliente ID]=dc.[WWI Cliente ID]
                     WHERE cr.[Numero Contrato]=s.[Numero Contrato] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'),0),
            ISNULL((SELECT TOP 1 [Clasificacion Riesgo Key] FROM Dimension.ClasificacionRiesgo
                     WHERE [Nombre Clasificacion]=s.[Clasificacion Riesgo]),0),
            s.[Numero Contrato],s.[Tipo Provision],s.[Importe Provisionado],s.[Importe Recuperado],
            s.[Saldo Provision],s.[Porcentaje Provision],s.[WWI Provision ID],1
        FROM Integration.Provision_Staging s
        WHERE s.[WWI Provision ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactProvision','Fact.Provision',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Provision: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactProvision','Fact.Provision',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F7: CIRBE (lookup Cliente + EntidadFinanciera + ClasificacionRiesgo)
IF OBJECT_ID('ETL.sp_CargarFactCIRBE','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactCIRBE;
GO
CREATE PROCEDURE ETL.sp_CargarFactCIRBE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI CIRBE ID]) FROM Fact.CIRBE),0);
        INSERT INTO Fact.CIRBE (
            [Fecha Declaracion Key],[Cliente Key],[Entidad Financiera Key],[Clasificacion Riesgo Key],
            [Periodo Declaracion],[Tipo Operacion],[Naturaleza Operacion],[Importe Operacion],[Saldo Vivo],
            [Tipo Garantia],[Es Operacion Dudosa],[Riesgo Directo],[Riesgo Indirecto],[Provision Dotada],
            [WWI CIRBE ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Declaracion]),
            ISNULL((SELECT TOP 1 [Cliente Key] FROM Dimension.Cliente
                     WHERE [WWI Cliente ID]=s.[Cliente ID] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
            ISNULL((SELECT TOP 1 [Entidad Financiera Key] FROM Dimension.EntidadFinanciera
                     WHERE [Nombre Entidad]=s.[Entidad Financiera]),0),
            ISNULL((SELECT TOP 1 [Clasificacion Riesgo Key] FROM Dimension.ClasificacionRiesgo
                     WHERE [Nombre Clasificacion]=s.[Clasificacion Riesgo]),0),
            s.[Periodo Declaracion],s.[Tipo Operacion],s.[Naturaleza Operacion],s.[Importe Operacion],
            s.[Saldo Vivo],s.[Tipo Garantia],s.[Es Operacion Dudosa],s.[Importe Operacion],0,0,
            s.[WWI CIRBE ID],1
        FROM Integration.CIRBE_Staging s
        WHERE s.[WWI CIRBE ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCIRBE','Fact.CIRBE',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.CIRBE: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactCIRBE','Fact.CIRBE',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- F8: AVAL (lookup Cliente Titular via Credito + Cliente Avalista directo)
IF OBJECT_ID('ETL.sp_CargarFactAval','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarFactAval;
GO
CREATE PROCEDURE ETL.sp_CargarFactAval AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Aval ID]) FROM Fact.Aval),0);
        INSERT INTO Fact.Aval (
            [Fecha Constitucion Key],[Fecha Vencimiento Key],[Cliente Titular Key],[Cliente Avalista Key],
            [Numero Contrato],[Numero Aval],[Tipo Aval],[Importe Avalado],[Porcentaje Cobertura],
            [Estado Aval],[WWI Aval ID],[Lineage Key]
        )
        SELECT
            ETL.fn_DateKey(s.[Fecha Constitucion]),
            ETL.fn_DateKey(s.[Fecha Vencimiento]),
            ISNULL((SELECT TOP 1 dc.[Cliente Key]
                     FROM Integration.Credito_Staging cr
                     JOIN Dimension.Cliente dc ON cr.[Cliente ID]=dc.[WWI Cliente ID]
                     WHERE cr.[Numero Contrato]=s.[Numero Contrato] AND dc.[Valid To]='9999-12-31 23:59:59.9999999'),0),
            ISNULL((SELECT TOP 1 [Cliente Key] FROM Dimension.Cliente
                     WHERE [WWI Cliente ID]=s.[Cliente Avalista ID] AND [Valid To]='9999-12-31 23:59:59.9999999'),0),
            s.[Numero Contrato],s.[Numero Aval],s.[Tipo Aval],s.[Importe Avalado],s.[Porcentaje Cobertura],
            s.[Estado Aval],s.[WWI Aval ID],1
        FROM Integration.Aval_Staging s
        WHERE s.[WWI Aval ID] > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactAval','Fact.Aval',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Fact.Aval: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarFactAval','Fact.Aval',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- HECHOS GOLD BANCA OK (8/8) ---';
GO

-- MAESTRO SILVER -> GOLD BANCA
IF OBJECT_ID('ETL.sp_CargarOroBanca','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarOroBanca;
GO
CREATE PROCEDURE ETL.sp_CargarOroBanca AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @OK INT = 0, @Err INT = 0;
    PRINT 'ETL BANCA SILVER -> GOLD';
    PRINT '========================================';
    PRINT '--- DIMENSIONES ---';
    BEGIN TRY EXEC ETL.sp_CargarDimCentro; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimCentro: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimEntidadFinanciera; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimEntidad: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimClasificacionRiesgo; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimClasif: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimProducto; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimProducto: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimCliente; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimCliente: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimPerfilRiesgo; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimPerfil: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimGarantia; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimGarantia: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimEmpleado; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimEmpleado: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarDimCuenta; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR DimCuenta: '+ERROR_MESSAGE(); END CATCH;

    PRINT '--- HECHOS ---';
    BEGIN TRY EXEC ETL.sp_CargarFactCredito; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactCredito: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactCuotaPrestamo; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactCuota: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactTransferencia; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactTransf: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactMovimiento; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactMov: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactSaldoCuenta; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactSaldo: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactProvision; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactProv: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactCIRBE; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactCIRBE: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarFactAval; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR FactAval: '+ERROR_MESSAGE(); END CATCH;

    PRINT '========================================';
    PRINT 'OK: '+CAST(@OK AS VARCHAR)+' | Errores: '+CAST(@Err AS VARCHAR);
    PRINT 'Duración: '+CAST(DATEDIFF(SECOND,@Inicio,GETDATE()) AS VARCHAR)+' seg';
END;
GO

PRINT '';

PRINT 'Para ejecutar: EXEC ETL.sp_CargarOroBanca';
GO
