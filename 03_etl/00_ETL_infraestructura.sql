-- Infraestructura comun del ETL (se ejecuta una vez, antes de las cargas).
-- Crea el schema ETL y lo basico para orquestar y controlar las cargas:
--   ControlCarga   -> guarda hasta donde se ha procesado cada staging (incremental)
--   LogEjecucion   -> registro de cada ejecucion (filas, duracion, errores)
--   fn_ObtenerUltimaFecha / sp_ActualizarControl -> apoyo a la carga incremental
--   sp_RegistrarLog -> escribe en el log
--   fn_DateKey     -> convierte una fecha en la clave entera de Dimension.Date

USE WideWorldImportersDW;
GO

-- SCHEMA ETL
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ETL')
    EXEC('CREATE SCHEMA ETL');
GO

-- TABLA ETL.ControlCarga
IF OBJECT_ID('ETL.ControlCarga','U') IS NOT NULL DROP TABLE ETL.ControlCarga;
GO
CREATE TABLE ETL.ControlCarga (
    ControlCargaID      INT IDENTITY(1,1) PRIMARY KEY,
    TablaStagingDestino NVARCHAR(200) NOT NULL,
    UltimaFechaProcesada DATETIME2 NULL,
    UltimoIDProcesado   INT NULL,
    Estado              NVARCHAR(50) NOT NULL DEFAULT 'Pendiente',
    FechaUltimaEjecucion DATETIME2 NULL
);
GO

-- TABLA ETL.LogEjecucion
IF OBJECT_ID('ETL.LogEjecucion','U') IS NOT NULL DROP TABLE ETL.LogEjecucion;
GO
CREATE TABLE ETL.LogEjecucion (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    NombreProceso   NVARCHAR(200) NOT NULL,
    TablaDestino    NVARCHAR(200) NOT NULL,
    RegistrosCargados INT NOT NULL DEFAULT 0,
    DuracionSegundos  INT NOT NULL DEFAULT 0,
    Estado          NVARCHAR(50) NOT NULL,
    MensajeError    NVARCHAR(MAX) NULL,
    FechaEjecucion  DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

-- FUNCIÓN ETL.fn_ObtenerUltimaFecha
IF OBJECT_ID('ETL.fn_ObtenerUltimaFecha','FN') IS NOT NULL 
    DROP FUNCTION ETL.fn_ObtenerUltimaFecha;
GO
CREATE FUNCTION ETL.fn_ObtenerUltimaFecha(@Tabla NVARCHAR(200))
RETURNS DATETIME2
WITH EXECUTE AS OWNER
AS
BEGIN
    DECLARE @Fecha DATETIME2;
    SELECT @Fecha = UltimaFechaProcesada
    FROM ETL.ControlCarga
    WHERE TablaStagingDestino = @Tabla;
    RETURN ISNULL(@Fecha, '1900-01-01');
END;
GO

-- SP ETL.sp_ActualizarControl
IF OBJECT_ID('ETL.sp_ActualizarControl','P') IS NOT NULL 
    DROP PROCEDURE ETL.sp_ActualizarControl;
GO
CREATE PROCEDURE ETL.sp_ActualizarControl
    @Tabla      NVARCHAR(200),
    @Fecha      DATETIME2 = NULL,
    @Registros  INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM ETL.ControlCarga WHERE TablaStagingDestino = @Tabla)
        UPDATE ETL.ControlCarga
        SET UltimaFechaProcesada  = ISNULL(@Fecha, SYSDATETIME()),
            Estado                = 'OK',
            FechaUltimaEjecucion  = SYSDATETIME()
        WHERE TablaStagingDestino = @Tabla;
    ELSE
        INSERT INTO ETL.ControlCarga 
            (TablaStagingDestino, UltimaFechaProcesada, Estado, FechaUltimaEjecucion)
        VALUES 
            (@Tabla, ISNULL(@Fecha, SYSDATETIME()), 'OK', SYSDATETIME());
END;
GO

-- SP ETL.sp_RegistrarLog
IF OBJECT_ID('ETL.sp_RegistrarLog','P') IS NOT NULL 
    DROP PROCEDURE ETL.sp_RegistrarLog;
GO
CREATE PROCEDURE ETL.sp_RegistrarLog
    @Proceso    NVARCHAR(200),
    @Tabla      NVARCHAR(200),
    @Registros  INT,
    @Duracion   INT,
    @Estado     NVARCHAR(50),
    @Error      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO ETL.LogEjecucion 
        (NombreProceso, TablaDestino, RegistrosCargados, DuracionSegundos, Estado, MensajeError)
    VALUES 
        (@Proceso, @Tabla, @Registros, @Duracion, @Estado, @Error);
END;
GO

-- FUNCIÓN ETL.fn_DateKey
IF OBJECT_ID('ETL.fn_DateKey','FN') IS NOT NULL 
    DROP FUNCTION ETL.fn_DateKey;
GO
CREATE FUNCTION ETL.fn_DateKey(@fecha DATE)
RETURNS INT
WITH EXECUTE AS OWNER
AS
BEGIN
    IF @fecha IS NULL RETURN 0;
    RETURN YEAR(@fecha)*10000 + MONTH(@fecha)*100 + DAY(@fecha);
END;
GO

-- VERIFICACIÓN
SELECT SCHEMA_NAME(schema_id) AS esquema, name AS objeto, type_desc
FROM sys.objects
WHERE SCHEMA_NAME(schema_id) = 'ETL'
ORDER BY type_desc, name;
GO