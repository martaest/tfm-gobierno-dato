-- Carga Bronze -> Silver del dominio banca.
-- Cada SP limpia y desnormaliza una entidad (UPPER/TRIM, JOINs para traerse
-- las descripciones, edad calculada, etc.) y la deja en su Integration.*_Staging.
-- La carga es incremental: solo se trae lo nuevo desde el ultimo ID o fecha
-- ya procesado. Son 17 SPs (9 dimensiones y 8 hechos) mas el maestro.

USE WideWorldImportersDW;
GO

PRINT 'ETL BANCA BRONZE -> SILVER';
PRINT '========================================';
GO

-- DIMENSIONES BANCA

-- CENTRO (Sucursales + ZonasGeograficas)
IF OBJECT_ID('ETL.sp_CargarCentro','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCentro;
GO
CREATE PROCEDURE ETL.sp_CargarCentro AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Centro ID]) FROM Integration.Centro_Staging),0);
        CREATE TABLE #TmpCentro (
            SucursalID INT, CodigoSucursal NVARCHAR(20), NombreSucursal NVARCHAR(200),
            DireccionCompleta NVARCHAR(500), CodigoPostal NVARCHAR(10), Localidad NVARCHAR(100),
            Provincia NVARCHAR(100), ZonaGeografica NVARCHAR(200), Telefono NVARCHAR(20),
            Email NVARCHAR(200), DirectorSucursal NVARCHAR(200), NumeroEmpleados INT,
            FechaApertura DATE, FechaCierre DATE, EstadoSucursal NVARCHAR(50)
        );
        INSERT INTO #TmpCentro
        SELECT s.SucursalID, s.CodigoSucursal, s.NombreSucursal, s.DireccionCompleta,
               s.CodigoPostal, s.Localidad, s.Provincia, z.NombreZona, s.Telefono,
               s.Email, s.DirectorSucursal, s.NumeroEmpleados, s.FechaApertura,
               s.FechaCierre, s.EstadoSucursal
        FROM WideWorldImporters.Organizacion.Sucursales s
        LEFT JOIN WideWorldImporters.Organizacion.ZonasGeograficas z ON s.ZonaGeograficaID = z.ZonaGeograficaID
        WHERE s.SucursalID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        IF @Registros > 0
        BEGIN
            INSERT INTO Integration.Centro_Staging (
                [WWI Centro ID],[Codigo Centro],[Nombre Centro],[Tipo Centro],[Direccion Completa],
                [Codigo Postal],[Localidad],[Provincia],[Zona Geografica],[Telefono],[Email],
                [Director Centro],[Numero Empleados],[Fecha Apertura],[Fecha Cierre],[Estado Centro],
                [Centro Padre],[Valid From],[Valid To],[Lineage Key]
            )
            SELECT SucursalID, UPPER(TRIM(CodigoSucursal)), UPPER(TRIM(NombreSucursal)), 'SUCURSAL',
                   UPPER(TRIM(DireccionCompleta)), UPPER(TRIM(CodigoPostal)), UPPER(TRIM(Localidad)),
                   UPPER(TRIM(Provincia)), UPPER(TRIM(ZonaGeografica)), UPPER(TRIM(Telefono)),
                   LOWER(TRIM(Email)), UPPER(TRIM(DirectorSucursal)), NumeroEmpleados,
                   FechaApertura, FechaCierre, UPPER(TRIM(EstadoSucursal)), NULL,
                   GETDATE(), '9999-12-31', 1
            FROM #TmpCentro;
        END;
        DROP TABLE #TmpCentro;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Centro_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCentro','Centro_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Centro_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCentro','Centro_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- ENTIDAD FINANCIERA
IF OBJECT_ID('ETL.sp_CargarEntidadFinanciera','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarEntidadFinanciera;
GO
CREATE PROCEDURE ETL.sp_CargarEntidadFinanciera AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Entidad ID]) FROM Integration.EntidadFinanciera_Staging),0);
        INSERT INTO Integration.EntidadFinanciera_Staging (
            [WWI Entidad ID],[Codigo Entidad],[Nombre Entidad],[NIF],[Tipo Entidad],
            [Pais],[Es Vigente],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT EntidadFinancieraID, UPPER(TRIM(CodigoEntidad)), UPPER(TRIM(NombreEntidad)),
               UPPER(TRIM(NIF)), UPPER(TRIM(TipoEntidad)), UPPER(TRIM(Pais)), EsVigente,
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Riesgo.EntidadesFinancieras
        WHERE EntidadFinancieraID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'EntidadFinanciera_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEntidadFinanciera','EntidadFinanciera_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  EntidadFinanciera_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEntidadFinanciera','EntidadFinanciera_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CLASIFICACION RIESGO
IF OBJECT_ID('ETL.sp_CargarClasificacionRiesgo','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarClasificacionRiesgo;
GO
CREATE PROCEDURE ETL.sp_CargarClasificacionRiesgo AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Clasificacion ID]) FROM Integration.ClasificacionRiesgo_Staging),0);
        INSERT INTO Integration.ClasificacionRiesgo_Staging (
            [WWI Clasificacion ID],[Codigo Clasificacion],[Nombre Clasificacion],[Descripcion],
            [Nivel Riesgo],[Porcentaje Provision],[Es Vigente],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT ClasificacionRiesgoID, UPPER(TRIM(CodigoClasificacion)), UPPER(TRIM(NombreClasificacion)),
               UPPER(TRIM(Descripcion)), NivelRiesgo, PorcentajeProvision, EsVigente,
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Riesgo.ClasificacionesRiesgo
        WHERE ClasificacionRiesgoID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'ClasificacionRiesgo_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarClasificacionRiesgo','ClasificacionRiesgo_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  ClasificacionRiesgo_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarClasificacionRiesgo','ClasificacionRiesgo_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PRODUCTO (CatalogoProductos + TiposProducto + CategoriasProducto)
IF OBJECT_ID('ETL.sp_CargarProducto','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarProducto;
GO
CREATE PROCEDURE ETL.sp_CargarProducto AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Producto ID]) FROM Integration.Producto_Staging),0);
        INSERT INTO Integration.Producto_Staging (
            [WWI Producto ID],[Codigo Producto],[Nombre Producto],[Descripcion],[Tipo Producto],
            [Categoria Producto],[TAE],[TIN],[Comision],[Importe Minimo],[Importe Maximo],
            [Plazo Minimo Dias],[Plazo Maximo Dias],[Requiere Garantia],[Edad Minima],[Edad Maxima],
            [Es Comercializable],[Fecha Lanzamiento],[Fecha Retiro],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT p.ProductoID, UPPER(TRIM(p.CodigoProducto)), UPPER(TRIM(p.NombreProducto)),
               UPPER(TRIM(p.Descripcion)), UPPER(TRIM(tp.NombreTipoProducto)), UPPER(TRIM(cp.NombreCategoria)),
               p.TAE, p.TIN, p.Comision, p.ImporteMinimo, p.ImporteMaximo,
               p.PlazoMinimoDias, p.PlazoMaximoDias, p.RequiereGarantia, p.EdadMinima, p.EdadMaxima,
               p.EsComercializable, p.FechaLanzamiento, p.FechaRetiro, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Producto.CatalogoProductos p
        JOIN WideWorldImporters.Producto.TiposProducto tp ON p.TipoProductoID = tp.TipoProductoID
        JOIN WideWorldImporters.Producto.CategoriasProducto cp ON p.CategoriaProductoID = cp.CategoriaProductoID
        WHERE p.ProductoID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Producto_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarProducto','Producto_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Producto_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarProducto','Producto_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CLIENTE (Personas físicas + Jurídicas, offset 1M, JOINs Segmento/Direccion/SegmentacionComercial)
IF OBJECT_ID('ETL.sp_CargarCliente','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCliente;
GO
CREATE PROCEDURE ETL.sp_CargarCliente AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxIDF INT = ISNULL((SELECT MAX([WWI Cliente ID]) FROM Integration.Cliente_Staging WHERE [Tipo Cliente]='Persona Física'),0);
        DECLARE @MaxIDJ INT = ISNULL((SELECT MAX([WWI Cliente ID])-1000000 FROM Integration.Cliente_Staging WHERE [Tipo Cliente]='Persona Jurídica'),0);

        -- Personas físicas
        INSERT INTO Integration.Cliente_Staging (
            [WWI Cliente ID],[Tipo Cliente],[Numero Documento],[Nombre Completo],
            [Fecha Nacimiento Constitucion],[Edad],[Sexo],[Nacionalidad],[Forma Juridica],[CNAE],
            [Email],[Telefono Movil],[Telefono Fijo],[Direccion Completa],[Codigo Postal],
            [Localidad],[Provincia],[Pais],[Segmento],[Subsegmento],[Clasificacion Comercial],
            [Potencial Negocio],[Es Cliente Activo],[Fecha Alta],[Fecha Baja],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT p.PersonaID, 'Persona Física', UPPER(TRIM(p.NumeroDocumento)),
               UPPER(TRIM(p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,''))),
               p.FechaNacimiento, DATEDIFF(YEAR, p.FechaNacimiento, GETDATE()),
               UPPER(TRIM(p.Sexo)), UPPER(TRIM(p.Nacionalidad)), NULL, NULL,
               LOWER(TRIM(p.Email)), TRIM(p.TelefonoMovil), TRIM(p.TelefonoFijo),
               NULL, NULL, NULL, NULL, 'ESPAÑA',
               UPPER(TRIM(s.NombreSegmento)), UPPER(TRIM(sc.SubSegmento)),
               UPPER(TRIM(sc.ClasificacionComercial)), UPPER(TRIM(sc.PotencialNegocio)),
               p.EsClienteActivo, p.FechaAlta, p.FechaBaja, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cliente.Personas p
        LEFT JOIN WideWorldImporters.Cliente.SegmentacionComercial sc ON p.PersonaID = sc.PersonaID
        LEFT JOIN WideWorldImporters.Cliente.Segmentos s ON p.SegmentoID = s.SegmentoID
        WHERE p.PersonaID > @MaxIDF;
        SET @Registros = @@ROWCOUNT;

        -- Personas jurídicas (offset 1.000.000)
        INSERT INTO Integration.Cliente_Staging (
            [WWI Cliente ID],[Tipo Cliente],[Numero Documento],[Nombre Completo],
            [Fecha Nacimiento Constitucion],[Edad],[Sexo],[Nacionalidad],[Forma Juridica],[CNAE],
            [Email],[Telefono Movil],[Telefono Fijo],[Direccion Completa],[Codigo Postal],
            [Localidad],[Provincia],[Pais],[Segmento],[Subsegmento],[Clasificacion Comercial],
            [Potencial Negocio],[Es Cliente Activo],[Fecha Alta],[Fecha Baja],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT 1000000+pj.PersonaJuridicaID, 'Persona Jurídica', UPPER(TRIM(pj.CIF)),
               UPPER(TRIM(pj.RazonSocial)), pj.FechaConstitucion, NULL, NULL, 'ESPAÑA',
               UPPER(TRIM(pj.FormaJuridica)), UPPER(TRIM(pj.CNAE)),
               LOWER(TRIM(pj.Email)), TRIM(pj.TelefonoContacto), NULL,
               NULL, NULL, NULL, NULL, 'ESPAÑA',
               UPPER(TRIM(s.NombreSegmento)), UPPER(TRIM(sc.SubSegmento)),
               UPPER(TRIM(sc.ClasificacionComercial)), UPPER(TRIM(sc.PotencialNegocio)),
               pj.EsClienteActivo, pj.FechaAlta, pj.FechaBaja, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cliente.PersonasJuridicas pj
        LEFT JOIN WideWorldImporters.Cliente.SegmentacionComercial sc ON pj.PersonaJuridicaID = sc.PersonaJuridicaID
        LEFT JOIN WideWorldImporters.Cliente.Segmentos s ON pj.SegmentoID = s.SegmentoID
        WHERE pj.PersonaJuridicaID > @MaxIDJ;
        SET @Registros = @Registros + @@ROWCOUNT;

        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Cliente_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCliente','Cliente_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Cliente_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCliente','Cliente_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PERFIL RIESGO (ScoreCrediticio + PerfilTransaccional, solo personas físicas)
IF OBJECT_ID('ETL.sp_CargarPerfilRiesgo','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarPerfilRiesgo;
GO
CREATE PROCEDURE ETL.sp_CargarPerfilRiesgo AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Cliente ID]) FROM Integration.PerfilRiesgo_Staging),0);
        INSERT INTO Integration.PerfilRiesgo_Staging (
            [WWI Cliente ID],[Score Credito],[Nivel Riesgo],[Probabilidad Impago],
            [Limite Endeudamiento],[Fecha Calculo Score],[Fuente Score],[Modelo Scoring],
            [Numero Transacciones Mes],[Importe Promedio Transaccion],[Volumen Mensual Operaciones],
            [Numero Transferencias Internacionales],[Tiene Operativa Inusual],[Fecha Actualizacion],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT sc.PersonaID, sc.ScoreCredito, UPPER(TRIM(sc.NivelRiesgo)), sc.ProbabilidadImpago,
               sc.LimiteEndeudamiento, sc.FechaCalculoScore, UPPER(TRIM(sc.FuenteScore)),
               UPPER(TRIM(sc.ModeloScoring)), pt.NumeroTransaccionesMes, pt.ImportePromedioTransaccion,
               pt.VolumenMensualOperaciones, pt.NumeroTransferenciasInternacionales,
               ISNULL(pt.TieneOperativaInusual,0), ISNULL(pt.FechaUltimaActualizacion, sc.FechaCalculoScore), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cliente.ScoreCrediticio sc
        LEFT JOIN WideWorldImporters.Cliente.PerfilTransaccional pt ON sc.PersonaID = pt.PersonaID
        WHERE sc.PersonaID IS NOT NULL AND sc.PersonaID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'PerfilRiesgo_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPerfilRiesgo','PerfilRiesgo_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  PerfilRiesgo_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarPerfilRiesgo','PerfilRiesgo_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- GARANTIA (Garantias + TiposGarantia)
IF OBJECT_ID('ETL.sp_CargarGarantia','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarGarantia;
GO
CREATE PROCEDURE ETL.sp_CargarGarantia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Garantia ID]) FROM Integration.Garantia_Staging),0);
        INSERT INTO Integration.Garantia_Staging (
            [WWI Garantia ID],[Numero Contrato],[Tipo Garantia],[Descripcion Garantia],
            [Valor Tasacion],[Fecha Tasacion],[Entidad Tasadora],[Direccion Garantia],
            [Tiene Seguro],[Fecha Constitucion],[Fecha Liberacion],[Estado Garantia],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT g.GarantiaID, UPPER(TRIM(g.NumeroContrato)), UPPER(TRIM(tg.NombreTipoGarantia)),
               UPPER(TRIM(g.DescripcionGarantia)), g.ValorTasacion, g.FechaTasacion,
               UPPER(TRIM(g.EntidadTasadora)), UPPER(TRIM(g.DireccionGarantia)), g.TieneSeguro,
               g.FechaConstitucion, g.FechaLiberacion, UPPER(TRIM(g.EstadoGarantia)),
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Credito.Garantias g
        JOIN WideWorldImporters.Credito.TiposGarantia tg ON g.TipoGarantiaID = tg.TipoGarantiaID
        WHERE g.GarantiaID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Garantia_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarGarantia','Garantia_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Garantia_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarGarantia','Garantia_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- EMPLEADO (Empleados + Personas + Departamentos + Sucursales + Supervisor)
IF OBJECT_ID('ETL.sp_CargarEmpleado','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarEmpleado;
GO
CREATE PROCEDURE ETL.sp_CargarEmpleado AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Empleado ID]) FROM Integration.Empleado_Staging),0);
        INSERT INTO Integration.Empleado_Staging (
            [WWI Empleado ID],[Numero Empleado],[Nombre Completo],[Email],[Telefono],
            [Departamento],[Centro Asignado],[Puesto],[Categoria],[Supervisor],
            [Fecha Alta],[Fecha Baja],[Estado Empleado],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT e.EmpleadoID, UPPER(TRIM(e.NumeroEmpleado)),
               UPPER(TRIM(p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,''))),
               LOWER(TRIM(p.Email)), TRIM(p.TelefonoMovil), UPPER(TRIM(d.NombreDepartamento)),
               UPPER(TRIM(s.NombreSucursal)), UPPER(TRIM(e.Puesto)), UPPER(TRIM(e.Categoria)),
               UPPER(TRIM(ps.Nombre+' '+ps.Apellido1)), e.FechaAlta, e.FechaBaja,
               UPPER(TRIM(e.EstadoEmpleado)), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Organizacion.Empleados e
        JOIN WideWorldImporters.Cliente.Personas p ON e.PersonaID = p.PersonaID
        LEFT JOIN WideWorldImporters.Organizacion.Departamentos d ON e.DepartamentoID = d.DepartamentoID
        LEFT JOIN WideWorldImporters.Organizacion.Sucursales s ON e.SucursalID = s.SucursalID
        LEFT JOIN WideWorldImporters.Organizacion.Empleados esup ON e.SupervisorID = esup.EmpleadoID
        LEFT JOIN WideWorldImporters.Cliente.Personas ps ON esup.PersonaID = ps.PersonaID
        WHERE e.EmpleadoID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Empleado_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEmpleado','Empleado_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Empleado_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarEmpleado','Empleado_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CUENTA (Corrientes + Ahorro offset 100k + Nomina offset 200k, JOIN Titular/Persona)
IF OBJECT_ID('ETL.sp_CargarCuenta','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCuenta;
GO
CREATE PROCEDURE ETL.sp_CargarCuenta AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxCC INT = ISNULL((SELECT MAX([WWI Cuenta ID]) FROM Integration.Cuenta_Staging WHERE [WWI Cuenta ID] < 100000),0);
        DECLARE @MaxCA INT = ISNULL((SELECT MAX([WWI Cuenta ID])-100000 FROM Integration.Cuenta_Staging WHERE [WWI Cuenta ID] BETWEEN 100001 AND 199999),0);
        DECLARE @MaxCN INT = ISNULL((SELECT MAX([WWI Cuenta ID])-200000 FROM Integration.Cuenta_Staging WHERE [WWI Cuenta ID] >= 200001),0);

        -- Corrientes
        INSERT INTO Integration.Cuenta_Staging (
            [WWI Cuenta ID],[Numero Cuenta],[Tipo Cuenta],[Producto],[Cliente ID],[Nombre Cliente],
            [Fecha Apertura],[Fecha Cierre],[Saldo Actual],[Saldo Disponible],[Saldo Retenido],
            [Limite Descubierto],[TAE Aplicado],[Tiene Nomina Domiciliada],[Estado Cuenta],
            [Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT cc.CuentaCorrienteID, UPPER(TRIM(cc.NumeroCuenta)), UPPER(TRIM(tc.NombreTipoCuenta)),
               UPPER(TRIM(cp.NombreProducto)), ISNULL(tit.PersonaID,0),
               UPPER(TRIM(ISNULL(p.Nombre+' '+p.Apellido1,''))),
               cc.FechaApertura, cc.FechaCierre, ISNULL(cc.SaldoActual,0), ISNULL(cc.SaldoDisponible,0), ISNULL(cc.SaldoRetenido,0),
               cc.LimiteDescubierto, NULL, 0, UPPER(TRIM(cc.EstadoCuenta)),
               UPPER(TRIM(s.NombreSucursal)), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cuenta.CuentasCorrientes cc
        JOIN WideWorldImporters.Cuenta.TiposCuenta tc ON cc.TipoCuentaID = tc.TipoCuentaID
        JOIN WideWorldImporters.Producto.CatalogoProductos cp ON cc.ProductoID = cp.ProductoID
        LEFT JOIN WideWorldImporters.Cuenta.TitularesCuenta tit ON cc.NumeroCuenta = tit.NumeroCuenta AND tit.TipoTitularidad = 'Titular'
        LEFT JOIN WideWorldImporters.Cliente.Personas p ON tit.PersonaID = p.PersonaID
        LEFT JOIN WideWorldImporters.Organizacion.Sucursales s ON cc.SucursalGestion = s.SucursalID
        WHERE cc.CuentaCorrienteID > @MaxCC;
        SET @Registros = @@ROWCOUNT;

        -- Ahorro (offset 100.000)
        INSERT INTO Integration.Cuenta_Staging (
            [WWI Cuenta ID],[Numero Cuenta],[Tipo Cuenta],[Producto],[Cliente ID],[Nombre Cliente],
            [Fecha Apertura],[Fecha Cierre],[Saldo Actual],[Saldo Disponible],[Saldo Retenido],
            [Limite Descubierto],[TAE Aplicado],[Tiene Nomina Domiciliada],[Estado Cuenta],
            [Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT 100000+ca.CuentaAhorroID, UPPER(TRIM(ca.NumeroCuenta)), UPPER(TRIM(tc.NombreTipoCuenta)),
               UPPER(TRIM(cp.NombreProducto)), 0, NULL,
               ca.FechaApertura, ca.FechaCierre, ISNULL(ca.SaldoActual,0), ISNULL(ca.SaldoActual,0), 0,
               NULL, ca.TAEAplicado, 0, UPPER(TRIM(ca.EstadoCuenta)),
               NULL, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cuenta.CuentasAhorro ca
        JOIN WideWorldImporters.Cuenta.TiposCuenta tc ON ca.TipoCuentaID = tc.TipoCuentaID
        JOIN WideWorldImporters.Producto.CatalogoProductos cp ON ca.ProductoID = cp.ProductoID
        WHERE ca.CuentaAhorroID > @MaxCA;
        SET @Registros = @Registros + @@ROWCOUNT;

        -- Nomina (offset 200.000)
        INSERT INTO Integration.Cuenta_Staging (
            [WWI Cuenta ID],[Numero Cuenta],[Tipo Cuenta],[Producto],[Cliente ID],[Nombre Cliente],
            [Fecha Apertura],[Fecha Cierre],[Saldo Actual],[Saldo Disponible],[Saldo Retenido],
            [Limite Descubierto],[TAE Aplicado],[Tiene Nomina Domiciliada],[Estado Cuenta],
            [Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT 200000+cn.CuentaNominaID, UPPER(TRIM(cn.NumeroCuenta)), UPPER(TRIM(tc.NombreTipoCuenta)),
               UPPER(TRIM(cp.NombreProducto)), 0, NULL,
               cn.FechaApertura, cn.FechaCierre, ISNULL(cn.SaldoActual,0), ISNULL(cn.SaldoDisponible,0), 0,
               NULL, NULL, ISNULL(cn.TieneNominaDomiciliada,0), UPPER(TRIM(cn.EstadoCuenta)),
               NULL, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cuenta.CuentasNomina cn
        JOIN WideWorldImporters.Cuenta.TiposCuenta tc ON cn.TipoCuentaID = tc.TipoCuentaID
        JOIN WideWorldImporters.Producto.CatalogoProductos cp ON cn.ProductoID = cp.ProductoID
        WHERE cn.CuentaNominaID > @MaxCN;
        SET @Registros = @Registros + @@ROWCOUNT;

        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Cuenta_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCuenta','Cuenta_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Cuenta_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCuenta','Cuenta_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- DIMENSIONES BANCA ---';
GO

-- HECHOS BANCA

-- MOVIMIENTO (incremental por ID)
IF OBJECT_ID('ETL.sp_CargarMovimiento','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarMovimiento;
GO
CREATE PROCEDURE ETL.sp_CargarMovimiento AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Movimiento ID]) FROM Integration.Movimiento_Staging),0);
        INSERT INTO Integration.Movimiento_Staging (
            [WWI Movimiento ID],[Numero Cuenta],[Fecha Movimiento],[Fecha Valor],[Tipo Movimiento],
            [Concepto],[Importe Movimiento],[Saldo Despues Movimiento],[Numero Cuenta Contrapartida],
            [Canal Operacion],[Sucursal Operacion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT MovimientoCuentaID, UPPER(TRIM(NumeroCuenta)), FechaMovimiento, FechaValor,
               UPPER(TRIM(TipoMovimiento)), UPPER(TRIM(Concepto)), ImporteMovimiento,
               SaldoDespuesMovimiento, UPPER(TRIM(NumeroCuentaContrapartida)),
               UPPER(TRIM(CanalOperacion)), CAST(SucursalOperacion AS NVARCHAR(20)),
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cuenta.MovimientosCuenta
        WHERE MovimientoCuentaID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Movimiento_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarMovimiento','Movimiento_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Movimiento_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarMovimiento','Movimiento_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- SALDO DIARIO (agregado GROUP BY cuenta+fecha, incremental por fecha)
IF OBJECT_ID('ETL.sp_CargarSaldoDiario','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarSaldoDiario;
GO
CREATE PROCEDURE ETL.sp_CargarSaldoDiario AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxFecha DATE = ISNULL((SELECT MAX([Fecha]) FROM Integration.SaldoDiario_Staging),'1900-01-01');
        INSERT INTO Integration.SaldoDiario_Staging (
            [Numero Cuenta],[Fecha],[Saldo Apertura],[Saldo Cierre],[Saldo Minimo],[Saldo Maximo],
            [Saldo Promedio],[Numero Movimientos],[Importe Total Entradas],[Importe Total Salidas],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT UPPER(TRIM(NumeroCuenta)), FechaMovimiento,
               MIN(SaldoDespuesMovimiento), MAX(SaldoDespuesMovimiento),
               MIN(SaldoDespuesMovimiento), MAX(SaldoDespuesMovimiento), AVG(SaldoDespuesMovimiento),
               COUNT(*),
               SUM(CASE WHEN ImporteMovimiento > 0 THEN ImporteMovimiento ELSE 0 END),
               SUM(CASE WHEN ImporteMovimiento < 0 THEN ABS(ImporteMovimiento) ELSE 0 END),
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Cuenta.MovimientosCuenta
        WHERE FechaMovimiento > @MaxFecha
        GROUP BY NumeroCuenta, FechaMovimiento;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'SaldoDiario_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSaldoDiario','SaldoDiario_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  SaldoDiario_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarSaldoDiario','SaldoDiario_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CREDITO (Prestamos + Hipotecas offset 10k, JOIN Producto/Persona/Sucursal)
IF OBJECT_ID('ETL.sp_CargarCredito','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCredito;
GO
CREATE PROCEDURE ETL.sp_CargarCredito AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxP INT = ISNULL((SELECT MAX([WWI Credito ID]) FROM Integration.Credito_Staging WHERE [WWI Credito ID] < 10000),0);
        DECLARE @MaxH INT = ISNULL((SELECT MAX([WWI Credito ID])-10000 FROM Integration.Credito_Staging WHERE [WWI Credito ID] >= 10001),0);

        -- Préstamos personales
        INSERT INTO Integration.Credito_Staging (
            [WWI Credito ID],[Numero Contrato],[Tipo Credito],[Cliente ID],[Nombre Cliente],[Producto],
            [Importe Concedido],[Importe Pendiente],[TIN Aplicado],[TAE Aplicado],[Tipo Interes],
            [Plazo Meses],[Importe Cuota],[Fecha Formalizacion],[Fecha Primer Vencimiento],
            [Fecha Ultimo Vencimiento],[Fecha Liquidacion],[Estado Prestamo],[Valor Tasacion Garantia],
            [LTV Porcentaje],[Tiene Seguro Vida],[Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT pr.PrestamoID, UPPER(TRIM(pr.NumeroContrato)), 'PRESTAMO PERSONAL', pr.PersonaID,
               UPPER(TRIM(p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,''))),
               UPPER(TRIM(cp.NombreProducto)), pr.ImporteConcedido, pr.ImportePendiente,
               pr.TINAplicado, pr.TAEAplicado, UPPER(TRIM(pr.TipoInteres)), pr.PlazoMeses, pr.ImporteCuota,
               pr.FechaFormalizacion, pr.FechaPrimerVencimiento, pr.FechaUltimoVencimiento,
               pr.FechaLiquidacion, UPPER(TRIM(pr.EstadoPrestamo)), NULL, NULL, 0,
               UPPER(TRIM(s.NombreSucursal)), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Credito.Prestamos pr
        JOIN WideWorldImporters.Producto.CatalogoProductos cp ON pr.ProductoID = cp.ProductoID
        LEFT JOIN WideWorldImporters.Cliente.Personas p ON pr.PersonaID = p.PersonaID
        LEFT JOIN WideWorldImporters.Organizacion.Sucursales s ON pr.SucursalGestion = s.SucursalID
        WHERE pr.PrestamoID > @MaxP;
        SET @Registros = @@ROWCOUNT;

        -- Hipotecas (offset 10.000)
        INSERT INTO Integration.Credito_Staging (
            [WWI Credito ID],[Numero Contrato],[Tipo Credito],[Cliente ID],[Nombre Cliente],[Producto],
            [Importe Concedido],[Importe Pendiente],[TIN Aplicado],[TAE Aplicado],[Tipo Interes],
            [Plazo Meses],[Importe Cuota],[Fecha Formalizacion],[Fecha Primer Vencimiento],
            [Fecha Ultimo Vencimiento],[Fecha Liquidacion],[Estado Prestamo],[Valor Tasacion Garantia],
            [LTV Porcentaje],[Tiene Seguro Vida],[Sucursal Gestion],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT 10000+h.PrestamoHipotecarioID, UPPER(TRIM(h.NumeroContrato)), 'HIPOTECA', h.PersonaID,
               UPPER(TRIM(p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,''))),
               UPPER(TRIM(cp.NombreProducto)), h.ImporteConcedido, h.ImportePendiente,
               h.TINAplicado, h.TAEAplicado, UPPER(TRIM(h.TipoInteres)), h.PlazoMeses, h.ImporteCuota,
               h.FechaFormalizacion, h.FechaPrimerVencimiento, h.FechaUltimoVencimiento,
               NULL, UPPER(TRIM(h.EstadoPrestamo)), h.ValorTasacionInmueble, h.LTVPorcentaje,
               ISNULL(h.TieneSeguroVida,0), NULL, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Credito.PrestamosHipotecarios h
        JOIN WideWorldImporters.Producto.CatalogoProductos cp ON h.ProductoID = cp.ProductoID
        LEFT JOIN WideWorldImporters.Cliente.Personas p ON h.PersonaID = p.PersonaID
        WHERE h.PrestamoHipotecarioID > @MaxH;
        SET @Registros = @Registros + @@ROWCOUNT;

        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Credito_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCredito','Credito_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Credito_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCredito','Credito_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CUOTA (incremental por ID)
IF OBJECT_ID('ETL.sp_CargarCuota','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCuota;
GO
CREATE PROCEDURE ETL.sp_CargarCuota AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Cuota ID]) FROM Integration.Cuota_Staging),0);
        INSERT INTO Integration.Cuota_Staging (
            [WWI Cuota ID],[Numero Contrato],[Numero Cuota],[Fecha Vencimiento],[Importe Cuota],
            [Importe Capital],[Importe Intereses],[Importe Comisiones],[Capital Pendiente],
            [Fecha Pago],[Importe Pagado],[Estado Cuota],[Dias Retraso],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT CuotaPrestamoID, UPPER(TRIM(NumeroContrato)), NumeroCuota, FechaVencimiento, ImporteCuota,
               ImporteCapital, ImporteIntereses, ImporteComisiones, CapitalPendiente,
               FechaPago, ImportePagado, UPPER(TRIM(EstadoCuota)), DiasRetraso, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Credito.CuotasPrestamo
        WHERE CuotaPrestamoID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Cuota_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCuota','Cuota_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Cuota_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCuota','Cuota_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- TRANSFERENCIA (Internas + Externas offset 1M + SEPA offset 2M)
IF OBJECT_ID('ETL.sp_CargarTransferencia','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarTransferencia;
GO
CREATE PROCEDURE ETL.sp_CargarTransferencia AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxInt INT = ISNULL((SELECT MAX([WWI Transferencia ID]) FROM Integration.Transferencia_Staging WHERE [WWI Transferencia ID] < 1000000),0);
        DECLARE @MaxExt INT = ISNULL((SELECT MAX([WWI Transferencia ID])-1000000 FROM Integration.Transferencia_Staging WHERE [WWI Transferencia ID] BETWEEN 1000001 AND 1999999),0);
        DECLARE @MaxSEPA INT = ISNULL((SELECT MAX([WWI Transferencia ID])-2000000 FROM Integration.Transferencia_Staging WHERE [WWI Transferencia ID] >= 2000001),0);

        -- Internas
        INSERT INTO Integration.Transferencia_Staging (
            [WWI Transferencia ID],[Numero Operacion],[Tipo Transferencia],[Cuenta Origen],[Cuenta Destino],
            [Nombre Beneficiario],[Entidad Destino],[Pais Destino],[Importe Transferencia],[Concepto],
            [Fecha Operacion],[Fecha Valor],[Comision Aplicada],[Estado Transferencia],[Canal Operacion],
            [Es Pago Recurrente],[Es SEPA],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT TransferenciaInternaID, UPPER(TRIM(NumeroOperacion)), 'INTERNA',
               UPPER(TRIM(CuentaOrigen)), UPPER(TRIM(CuentaDestino)), NULL, NULL, NULL,
               ImporteTransferencia, UPPER(TRIM(Concepto)), FechaOperacion, FechaValor,
               0, UPPER(TRIM(EstadoTransferencia)), UPPER(TRIM(CanalOperacion)), 0, 0,
               GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Transferencia.TransferenciasInternas
        WHERE TransferenciaInternaID > @MaxInt;
        SET @Registros = @@ROWCOUNT;

        -- Externas (offset 1.000.000)
        INSERT INTO Integration.Transferencia_Staging (
            [WWI Transferencia ID],[Numero Operacion],[Tipo Transferencia],[Cuenta Origen],[Cuenta Destino],
            [Nombre Beneficiario],[Entidad Destino],[Pais Destino],[Importe Transferencia],[Concepto],
            [Fecha Operacion],[Fecha Valor],[Comision Aplicada],[Estado Transferencia],[Canal Operacion],
            [Es Pago Recurrente],[Es SEPA],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT 1000000+TransferenciaExternaID, UPPER(TRIM(NumeroOperacion)), 'EXTERNA',
               UPPER(TRIM(CuentaOrigen)), UPPER(TRIM(IBANDestino)), UPPER(TRIM(BeneficiarioNombre)),
               UPPER(TRIM(EntidadDestino)), NULL, ImporteTransferencia, UPPER(TRIM(Concepto)),
               FechaOperacion, FechaValor, ComisionAplicada, UPPER(TRIM(EstadoTransferencia)),
               UPPER(TRIM(CanalOperacion)), 0, 0, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Transferencia.TransferenciasExternas
        WHERE TransferenciaExternaID > @MaxExt;
        SET @Registros = @Registros + @@ROWCOUNT;

        -- SEPA (offset 2.000.000)
        INSERT INTO Integration.Transferencia_Staging (
            [WWI Transferencia ID],[Numero Operacion],[Tipo Transferencia],[Cuenta Origen],[Cuenta Destino],
            [Nombre Beneficiario],[Entidad Destino],[Pais Destino],[Importe Transferencia],[Concepto],
            [Fecha Operacion],[Fecha Valor],[Comision Aplicada],[Estado Transferencia],[Canal Operacion],
            [Es Pago Recurrente],[Es SEPA],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT 2000000+TransferenciaSEPAID, UPPER(TRIM(NumeroOperacion)), 'SEPA',
               UPPER(TRIM(CuentaOrigen)), UPPER(TRIM(IBANDestino)), UPPER(TRIM(BeneficiarioNombre)),
               NULL, UPPER(TRIM(PaisDestino)), ImporteTransferencia, UPPER(TRIM(Concepto)),
               FechaOperacion, FechaValor, ComisionAplicada, UPPER(TRIM(EstadoTransferencia)),
               NULL, 0, 1, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Transferencia.TransferenciasSEPA
        WHERE TransferenciaSEPAID > @MaxSEPA;
        SET @Registros = @Registros + @@ROWCOUNT;

        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Transferencia_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransferencia','Transferencia_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Transferencia_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarTransferencia','Transferencia_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- PROVISION (ProvisionesContables + ClasificacionesRiesgo)
IF OBJECT_ID('ETL.sp_CargarProvision','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarProvision;
GO
CREATE PROCEDURE ETL.sp_CargarProvision AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Provision ID]) FROM Integration.Provision_Staging),0);
        INSERT INTO Integration.Provision_Staging (
            [WWI Provision ID],[Numero Contrato],[Fecha Provision],[Tipo Provision],[Importe Provisionado],
            [Importe Recuperado],[Saldo Provision],[Clasificacion Riesgo],[Porcentaje Provision],
            [Valid From],[Valid To],[Lineage Key]
        )
        SELECT p.ProvisionID, UPPER(TRIM(p.NumeroContrato)), p.FechaProvision, UPPER(TRIM(p.TipoProvision)),
               p.ImporteProvisionado, p.ImporteRecuperado, p.SaldoProvision,
               UPPER(TRIM(cr.NombreClasificacion)), cr.PorcentajeProvision, GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Riesgo.ProvisionesContables p
        JOIN WideWorldImporters.Riesgo.ClasificacionesRiesgo cr ON p.ClasificacionRiesgoID = cr.ClasificacionRiesgoID
        WHERE p.ProvisionID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Provision_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarProvision','Provision_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Provision_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarProvision','Provision_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- CIRBE (OperacionesCIRBE + DeclaracionesCIRBE + EntidadesFinancieras + Personas)
IF OBJECT_ID('ETL.sp_CargarCIRBE','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarCIRBE;
GO
CREATE PROCEDURE ETL.sp_CargarCIRBE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI CIRBE ID]) FROM Integration.CIRBE_Staging),0);
        INSERT INTO Integration.CIRBE_Staging (
            [WWI CIRBE ID],[Cliente ID],[Nombre Cliente],[Periodo Declaracion],[Fecha Declaracion],
            [Entidad Financiera],[Tipo Operacion],[Naturaleza Operacion],[Importe Operacion],[Saldo Vivo],
            [Tipo Garantia],[Es Operacion Dudosa],[Clasificacion Riesgo],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT oc.OperacionCIRBEID, dc.PersonaID,
               UPPER(TRIM(p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,''))),
               UPPER(TRIM(dc.PeriodoDeclaracion)), dc.FechaDeclaracion, UPPER(TRIM(ef.NombreEntidad)),
               UPPER(TRIM(oc.TipoOperacion)), UPPER(TRIM(oc.NaturalezaOperacion)), oc.ImporteOperacion,
               oc.SaldoVivo, UPPER(TRIM(oc.TipoGarantia)), oc.EsOperacionDudosa,
               UPPER(TRIM(dc.ClasificacionRiesgo)), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Riesgo.OperacionesCIRBE oc
        JOIN WideWorldImporters.Riesgo.DeclaracionesCIRBE dc ON oc.DeclaracionCIRBEID = dc.DeclaracionCIRBEID
        JOIN WideWorldImporters.Riesgo.EntidadesFinancieras ef ON oc.EntidadFinancieraID = ef.EntidadFinancieraID
        LEFT JOIN WideWorldImporters.Cliente.Personas p ON dc.PersonaID = p.PersonaID
        WHERE oc.OperacionCIRBEID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'CIRBE_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCIRBE','CIRBE_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  CIRBE_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarCIRBE','CIRBE_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

-- AVAL (Avales + Personas avalista)
IF OBJECT_ID('ETL.sp_CargarAval','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarAval;
GO
CREATE PROCEDURE ETL.sp_CargarAval AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Registros INT = 0;
    DECLARE @Dur INT = 0;
    DECLARE @ErrMsg NVARCHAR(MAX) = NULL;
    BEGIN TRY
        DECLARE @MaxID INT = ISNULL((SELECT MAX([WWI Aval ID]) FROM Integration.Aval_Staging),0);
        INSERT INTO Integration.Aval_Staging (
            [WWI Aval ID],[Numero Contrato],[Numero Aval],[Cliente Avalista ID],[Nombre Avalista],
            [Tipo Aval],[Importe Avalado],[Porcentaje Cobertura],[Fecha Constitucion],
            [Fecha Vencimiento],[Estado Aval],[Valid From],[Valid To],[Lineage Key]
        )
        SELECT av.AvalID, UPPER(TRIM(av.NumeroContrato)), UPPER(TRIM(av.NumeroAval)), av.AvaladorPersonaID,
               UPPER(TRIM(ISNULL(av.AvaladorNombre, p.Nombre+' '+p.Apellido1+ISNULL(' '+p.Apellido2,'')))),
               UPPER(TRIM(av.TipoAval)), av.ImporteAvalado, av.PorcentajeCobertura, av.FechaConstitucion,
               av.FechaVencimiento, UPPER(TRIM(av.EstadoAval)), GETDATE(), '9999-12-31', 1
        FROM WideWorldImporters.Credito.Avales av
        LEFT JOIN WideWorldImporters.Cliente.Personas p ON av.AvaladorPersonaID = p.PersonaID
        WHERE av.AvalID > @MaxID;
        SET @Registros = @@ROWCOUNT;
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_ActualizarControl 'Aval_Staging', NULL, @Registros;
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarAval','Aval_Staging',@Registros,@Dur,'Exitoso',NULL;
        PRINT '  Aval_Staging: '+CAST(@Registros AS VARCHAR)+' filas';
    END TRY
    BEGIN CATCH
        SET @ErrMsg = ERROR_MESSAGE();
        SET @Dur = DATEDIFF(SECOND,@Inicio,GETDATE());
        EXEC ETL.sp_RegistrarLog 'ETL.sp_CargarAval','Aval_Staging',0,@Dur,'Error',@ErrMsg;
        THROW;
    END CATCH;
END;
GO

PRINT '--- HECHOS BANCA  ---';
GO

-- MAESTRO BANCA BRONZE -> SILVER
IF OBJECT_ID('ETL.sp_CargarPlataBanca','P') IS NOT NULL DROP PROCEDURE ETL.sp_CargarPlataBanca;
GO
CREATE PROCEDURE ETL.sp_CargarPlataBanca AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @OK INT = 0, @Err INT = 0;
    PRINT 'ETL BANCA BRONZE -> SILVER';
    PRINT '========================================';

    BEGIN TRY EXEC ETL.sp_CargarCentro; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Centro: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarEntidadFinanciera; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR EntidadFin: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarClasificacionRiesgo; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR ClasifRiesgo: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarProducto; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Producto: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarCliente; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Cliente: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarPerfilRiesgo; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR PerfilRiesgo: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarGarantia; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Garantia: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarEmpleado; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Empleado: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarCuenta; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Cuenta: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarMovimiento; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Movimiento: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarSaldoDiario; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR SaldoDiario: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarCredito; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Credito: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarCuota; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Cuota: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarTransferencia; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Transferencia: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarProvision; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Provision: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarCIRBE; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR CIRBE: '+ERROR_MESSAGE(); END CATCH;
    BEGIN TRY EXEC ETL.sp_CargarAval; SET @OK+=1; END TRY BEGIN CATCH SET @Err+=1; PRINT 'ERROR Aval: '+ERROR_MESSAGE(); END CATCH;

    PRINT '========================================';
    PRINT 'OK: '+CAST(@OK AS VARCHAR)+' | Errores: '+CAST(@Err AS VARCHAR);
    PRINT 'Duración: '+CAST(DATEDIFF(SECOND,@Inicio,GETDATE()) AS VARCHAR)+' seg';
END;
GO

PRINT '';
PRINT 'ETL BANCA BRONZE->SILVER: 17 SPs y maestro sp_CargarPlataBanca';
PRINT 'Para ejecutar: EXEC ETL.sp_CargarPlataBanca';
GO
