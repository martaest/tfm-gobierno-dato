-- Creacion de la estructura de la extension bancaria en las tres capas.
-- Bronze va sobre WideWorldImporters (esquemas Cliente, Cuenta, Credito, Riesgo,
-- Producto, Transferencia, Organizacion) y Silver/Gold sobre WideWorldImportersDW
-- (Integration para los staging y Dimension/Fact para el modelo dimensional).
-- Notas de esta version: se anade FechaModificacion en las tablas transaccionales
-- principales, el avalista se integra dentro de Credito.Avales (en vez de tabla
-- aparte) y AlertasBlanqueoCapitales lleva campos pensados para casos de calidad.
-- BRONZE - USE WideWorldImporters

USE WideWorldImporters;
GO

-- Schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Cliente')    EXEC('CREATE SCHEMA Cliente');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Producto')   EXEC('CREATE SCHEMA Producto');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Cuenta')     EXEC('CREATE SCHEMA Cuenta');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Credito')    EXEC('CREATE SCHEMA Credito');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Transferencia') EXEC('CREATE SCHEMA Transferencia');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Riesgo')     EXEC('CREATE SCHEMA Riesgo');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Organizacion') EXEC('CREATE SCHEMA Organizacion');
GO
PRINT ' Schemas creados correctamente';
GO

-- DOMINIO 1: CLIENTE (12 tablas)

-- Tabla 1: Cliente.TiposDocumento
IF OBJECT_ID('Cliente.TiposDocumento', 'U') IS NOT NULL DROP TABLE Cliente.TiposDocumento;
GO
CREATE TABLE Cliente.TiposDocumento (
    TipoDocumentoID     INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTipo          NVARCHAR(10)  NOT NULL UNIQUE,
    NombreTipo          NVARCHAR(100) NOT NULL,
    PaisEmision         NVARCHAR(100),
    ValidacionPattern   NVARCHAR(200),
    EsVigente           BIT NOT NULL DEFAULT 1,
    FechaCreacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    UsuarioCreacion     NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER
);
GO

-- Tabla 2: Cliente.Segmentos
IF OBJECT_ID('Cliente.Segmentos', 'U') IS NOT NULL DROP TABLE Cliente.Segmentos;
GO
CREATE TABLE Cliente.Segmentos (
    SegmentoID      INT IDENTITY(1,1) PRIMARY KEY,
    CodigoSegmento  NVARCHAR(10)  NOT NULL UNIQUE,
    NombreSegmento  NVARCHAR(100) NOT NULL,
    Descripcion     NVARCHAR(500),
    NivelRiesgo     TINYINT CHECK (NivelRiesgo BETWEEN 1 AND 5),
    EsVigente       BIT NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME2(7) NOT NULL DEFAULT SYSDATETIME()
);
GO

-- Tabla 3: Cliente.Personas [MAPEADA]
IF OBJECT_ID('Cliente.Personas', 'U') IS NOT NULL DROP TABLE Cliente.Personas;
GO
CREATE TABLE Cliente.Personas (
    PersonaID           INT IDENTITY(1,1) PRIMARY KEY,
    TipoDocumentoID     INT NOT NULL,
    NumeroDocumento     NVARCHAR(20) NOT NULL,
    Nombre              NVARCHAR(100) NOT NULL,
    Apellido1           NVARCHAR(100) NOT NULL,
    Apellido2           NVARCHAR(100),
    FechaNacimiento     DATE,
    Sexo                CHAR(1) CHECK (Sexo IN ('M','F','O')),
    Nacionalidad        NVARCHAR(100),
    Email               NVARCHAR(255),
    TelefonoMovil       NVARCHAR(20),
    TelefonoFijo        NVARCHAR(20),
    SegmentoID          INT,
    EsClienteActivo     BIT NOT NULL DEFAULT 1,
    FechaAlta           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaBaja           DATE,
    CONSTRAINT FK_Personas_TipoDocumento FOREIGN KEY (TipoDocumentoID) REFERENCES Cliente.TiposDocumento(TipoDocumentoID),
    CONSTRAINT FK_Personas_Segmento      FOREIGN KEY (SegmentoID)      REFERENCES Cliente.Segmentos(SegmentoID),
    CONSTRAINT UQ_Personas_Documento     UNIQUE (TipoDocumentoID, NumeroDocumento)
);
GO

-- Tabla 4: Cliente.PersonasJuridicas [MAPEADA]
IF OBJECT_ID('Cliente.PersonasJuridicas', 'U') IS NOT NULL DROP TABLE Cliente.PersonasJuridicas;
GO
CREATE TABLE Cliente.PersonasJuridicas (
    PersonaJuridicaID   INT IDENTITY(1,1) PRIMARY KEY,
    CIF                 NVARCHAR(20)  NOT NULL UNIQUE,
    RazonSocial         NVARCHAR(200) NOT NULL,
    NombreComercial     NVARCHAR(200),
    FormaJuridica       NVARCHAR(100),
    FechaConstitucion   DATE,
    CNAE                NVARCHAR(10),
    Email               NVARCHAR(255),
    TelefonoContacto    NVARCHAR(20),
    SegmentoID          INT,
    EsClienteActivo     BIT NOT NULL DEFAULT 1,
    FechaAlta           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaBaja           DATE,
    CONSTRAINT FK_PersonasJuridicas_Segmento FOREIGN KEY (SegmentoID) REFERENCES Cliente.Segmentos(SegmentoID)
);
GO

-- Tabla 5: Cliente.DatosDemograficos [MAPEADA]
IF OBJECT_ID('Cliente.DatosDemograficos', 'U') IS NOT NULL DROP TABLE Cliente.DatosDemograficos;
GO
CREATE TABLE Cliente.DatosDemograficos (
    DatoDemograficoID           INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID                   INT NOT NULL,
    EstadoCivil                 NVARCHAR(50),
    NumeroHijos                 TINYINT,
    NivelEstudios               NVARCHAR(100),
    SituacionLaboral            NVARCHAR(100),
    Profesion                   NVARCHAR(200),
    IngresosMensualesEstimados  DECIMAL(18,2),
    PatrimonioEstimado          DECIMAL(18,2),
    FechaActualizacion          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT FK_DatosDemograficos_Persona FOREIGN KEY (PersonaID) REFERENCES Cliente.Personas(PersonaID)
);
GO

-- Tabla 6: Cliente.DireccionesFiscales [MAPEADA]
IF OBJECT_ID('Cliente.DireccionesFiscales', 'U') IS NOT NULL DROP TABLE Cliente.DireccionesFiscales;
GO
CREATE TABLE Cliente.DireccionesFiscales (
    DireccionID             INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    TipoDireccion           NVARCHAR(50)  NOT NULL,
    TipoVia                 NVARCHAR(50),
    NombreVia               NVARCHAR(200) NOT NULL,
    Numero                  NVARCHAR(20),
    Piso                    NVARCHAR(10),
    Puerta                  NVARCHAR(10),
    CodigoPostal            NVARCHAR(10)  NOT NULL,
    Localidad               NVARCHAR(100) NOT NULL,
    Provincia               NVARCHAR(100) NOT NULL,
    Pais                    NVARCHAR(100) NOT NULL DEFAULT 'España',
    EsDireccionPrincipal    BIT NOT NULL DEFAULT 0,
    FechaDesde              DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaHasta              DATE,
    CONSTRAINT FK_DireccionesFiscales_Persona          FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_DireccionesFiscales_PersonaJuridica  FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_DireccionesFiscales_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 7: Cliente.ContactosEmergencia [NO MAPEADA]
IF OBJECT_ID('Cliente.ContactosEmergencia', 'U') IS NOT NULL DROP TABLE Cliente.ContactosEmergencia;
GO
CREATE TABLE Cliente.ContactosEmergencia (
    ContactoEmergenciaID INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID            INT NOT NULL,
    NombreCompleto       NVARCHAR(200) NOT NULL,
    Relacion             NVARCHAR(100),
    TelefonoContacto     NVARCHAR(20)  NOT NULL,
    Email                NVARCHAR(255),
    Prioridad            TINYINT NOT NULL DEFAULT 1,
    FechaRegistro        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_ContactosEmergencia_Persona FOREIGN KEY (PersonaID) REFERENCES Cliente.Personas(PersonaID)
);
GO

-- Tabla 8: Cliente.DocumentosIdentidad [MAPEADA]
IF OBJECT_ID('Cliente.DocumentosIdentidad', 'U') IS NOT NULL DROP TABLE Cliente.DocumentosIdentidad;
GO
CREATE TABLE Cliente.DocumentosIdentidad (
    DocumentoIdentidadID        INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID                   INT NOT NULL,
    TipoDocumentoID             INT NOT NULL,
    NumeroDocumento             NVARCHAR(20) NOT NULL,
    FechaEmision                DATE,
    FechaCaducidad              DATE,
    PaisEmision                 NVARCHAR(100),
    AutoridadEmisora            NVARCHAR(200),
    DocumentoVerificado         BIT NOT NULL DEFAULT 0,
    FechaVerificacion           DATE,
    RutaDocumentoEscaneado      NVARCHAR(500),
    CONSTRAINT FK_DocumentosIdentidad_Persona        FOREIGN KEY (PersonaID)       REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_DocumentosIdentidad_TipoDocumento  FOREIGN KEY (TipoDocumentoID) REFERENCES Cliente.TiposDocumento(TipoDocumentoID)
);
GO

-- Tabla 9: Cliente.RelacionesFamiliares [NO MAPEADA]
IF OBJECT_ID('Cliente.RelacionesFamiliares', 'U') IS NOT NULL DROP TABLE Cliente.RelacionesFamiliares;
GO
CREATE TABLE Cliente.RelacionesFamiliares (
    RelacionFamiliarID      INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT NOT NULL,
    PersonaRelacionadaID    INT NOT NULL,
    TipoRelacion            NVARCHAR(100) NOT NULL,
    FechaRegistro           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Observaciones           NVARCHAR(500),
    CONSTRAINT FK_RelacionesFamiliares_Persona           FOREIGN KEY (PersonaID)            REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_RelacionesFamiliares_PersonaRelacionada FOREIGN KEY (PersonaRelacionadaID) REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT CHK_RelacionesFamiliares_Diferente CHECK (PersonaID <> PersonaRelacionadaID)
);
GO

-- Tabla 10: Cliente.HistorialCambiosCliente [NO MAPEADA - Auditoría]
IF OBJECT_ID('Cliente.HistorialCambiosCliente', 'U') IS NOT NULL DROP TABLE Cliente.HistorialCambiosCliente;
GO
CREATE TABLE Cliente.HistorialCambiosCliente (
    HistorialCambioID   INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID           INT,
    PersonaJuridicaID   INT,
    TablaCambiada       NVARCHAR(100) NOT NULL,
    CampoCambiado       NVARCHAR(100) NOT NULL,
    ValorAnterior       NVARCHAR(MAX),
    ValorNuevo          NVARCHAR(MAX),
    FechaCambio         DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    UsuarioCambio       NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    MotivosCambio       NVARCHAR(500),
    CONSTRAINT FK_HistorialCambiosCliente_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_HistorialCambiosCliente_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID)
);
GO

-- Tabla 11: Cliente.PreferenciasPrivacidad [NO MAPEADA - RGPD]
IF OBJECT_ID('Cliente.PreferenciasPrivacidad', 'U') IS NOT NULL DROP TABLE Cliente.PreferenciasPrivacidad;
GO
CREATE TABLE Cliente.PreferenciasPrivacidad (
    PreferenciaPrivacidadID             INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID                           INT,
    PersonaJuridicaID                   INT,
    AceptaComunicacionesComerciales     BIT NOT NULL DEFAULT 0,
    AceptaCesionDatosTerceros           BIT NOT NULL DEFAULT 0,
    AceptaPerfilado                     BIT NOT NULL DEFAULT 0,
    CanalPreferidoContacto              NVARCHAR(50),
    FechaConsentimiento                 DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaRevocacion                     DATE,
    IPConsentimiento                    NVARCHAR(50),
    CONSTRAINT FK_PreferenciasPrivacidad_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_PreferenciasPrivacidad_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_PreferenciasPrivacidad_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 12: Cliente.SegmentacionComercial [MAPEADA]
IF OBJECT_ID('Cliente.SegmentacionComercial', 'U') IS NOT NULL DROP TABLE Cliente.SegmentacionComercial;
GO
CREATE TABLE Cliente.SegmentacionComercial (
    SegmentacionComercialID INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    SegmentoID              INT NOT NULL,
    SubSegmento             NVARCHAR(100),
    ClasificacionComercial  NVARCHAR(100),
    PotencialNegocio        NVARCHAR(50) CHECK (PotencialNegocio IN ('Bajo','Medio','Alto','Premium')),
    FechaSegmentacion       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaProximaRevision    DATE,
    CONSTRAINT FK_SegmentacionComercial_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_SegmentacionComercial_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT FK_SegmentacionComercial_Segmento       FOREIGN KEY (SegmentoID)        REFERENCES Cliente.Segmentos(SegmentoID)
);
GO

-- Tabla 13: Cliente.ScoreCrediticio [MAPEADA]
IF OBJECT_ID('Cliente.ScoreCrediticio', 'U') IS NOT NULL DROP TABLE Cliente.ScoreCrediticio;
GO
CREATE TABLE Cliente.ScoreCrediticio (
    ScoreCrediticioID       INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    ScoreCredito            INT CHECK (ScoreCredito BETWEEN 300 AND 900),
    NivelRiesgo             NVARCHAR(50) CHECK (NivelRiesgo IN ('Muy Bajo','Bajo','Medio','Alto','Muy Alto')),
    ProbabilidadImpago      DECIMAL(5,2) CHECK (ProbabilidadImpago BETWEEN 0 AND 100),
    LimiteEndeudamiento     DECIMAL(18,2),
    FechaCalculoScore       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FuenteScore             NVARCHAR(100),
    ModeloScoring           NVARCHAR(100),
    CONSTRAINT FK_ScoreCrediticio_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_ScoreCrediticio_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_ScoreCrediticio_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 14: Cliente.PerfilTransaccional [MAPEADA]
IF OBJECT_ID('Cliente.PerfilTransaccional', 'U') IS NOT NULL DROP TABLE Cliente.PerfilTransaccional;
GO
CREATE TABLE Cliente.PerfilTransaccional (
    PerfilTransaccionalID               INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID                           INT,
    PersonaJuridicaID                   INT,
    NumeroTransaccionesMes              INT,
    ImportePromedioTransaccion          DECIMAL(18,2),
    VolumenMensualOperaciones           DECIMAL(18,2),
    NumeroTransferenciasInternacionales INT,
    PaisesDestinoFrecuentes             NVARCHAR(500),
    TieneOperativaInusual               BIT NOT NULL DEFAULT 0,
    FechaUltimaActualizacion            DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT FK_PerfilTransaccional_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_PerfilTransaccional_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_PerfilTransaccional_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO
PRINT ' FIN DOMINIO 1: Cliente (12 tablas)';
GO

-- DOMINIO 2: PRODUCTO (8 tablas)

IF OBJECT_ID('Producto.TiposProducto', 'U') IS NOT NULL DROP TABLE Producto.TiposProducto;
GO
CREATE TABLE Producto.TiposProducto (
    TipoProductoID          INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTipoProducto      NVARCHAR(20) NOT NULL UNIQUE,
    NombreTipoProducto      NVARCHAR(100) NOT NULL,
    Descripcion             NVARCHAR(500),
    Categoria               NVARCHAR(100),
    EsVigente               BIT NOT NULL DEFAULT 1,
    FechaCreacion           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID('Producto.CategoriasProducto', 'U') IS NOT NULL DROP TABLE Producto.CategoriasProducto;
GO
CREATE TABLE Producto.CategoriasProducto (
    CategoriaProductoID INT IDENTITY(1,1) PRIMARY KEY,
    CodigoCategoria     NVARCHAR(20)  NOT NULL UNIQUE,
    NombreCategoria     NVARCHAR(100) NOT NULL,
    CategoriaPadreID    INT,
    Nivel               TINYINT NOT NULL DEFAULT 1,
    EsVigente           BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_CategoriasProducto_Padre FOREIGN KEY (CategoriaPadreID) REFERENCES Producto.CategoriasProducto(CategoriaProductoID)
);
GO

-- Tabla 3: Producto.CatalogoProductos [MAPEADA]
IF OBJECT_ID('Producto.CatalogoProductos', 'U') IS NOT NULL DROP TABLE Producto.CatalogoProductos;
GO
CREATE TABLE Producto.CatalogoProductos (
    ProductoID          INT IDENTITY(1,1) PRIMARY KEY,
    CodigoProducto      NVARCHAR(50)   NOT NULL UNIQUE,
    NombreProducto      NVARCHAR(200)  NOT NULL,
    Descripcion         NVARCHAR(1000),
    TipoProductoID      INT NOT NULL,
    CategoriaProductoID INT NOT NULL,
    TAE                 DECIMAL(5,3),
    TIN                 DECIMAL(5,3),
    Comision            DECIMAL(18,2),
    ImporteMinimo       DECIMAL(18,2),
    ImporteMaximo       DECIMAL(18,2),
    PlazoMinimoDias     INT,
    PlazoMaximoDias     INT,
    RequiereGarantia    BIT NOT NULL DEFAULT 0,
    EdadMinima          INT,
    EdadMaxima          INT,
    EsComercializable   BIT NOT NULL DEFAULT 1,
    FechaLanzamiento    DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaRetiro         DATE,
    CONSTRAINT FK_CatalogoProductos_TipoProducto      FOREIGN KEY (TipoProductoID)      REFERENCES Producto.TiposProducto(TipoProductoID),
    CONSTRAINT FK_CatalogoProductos_CategoriaProducto FOREIGN KEY (CategoriaProductoID) REFERENCES Producto.CategoriasProducto(CategoriaProductoID)
);
GO

IF OBJECT_ID('Producto.CondicionesComerciales', 'U') IS NOT NULL DROP TABLE Producto.CondicionesComerciales;
GO
CREATE TABLE Producto.CondicionesComerciales (
    CondicionComercialID    INT IDENTITY(1,1) PRIMARY KEY,
    ProductoID              INT NOT NULL,
    SegmentoClienteID       INT,
    TipoCondicion           NVARCHAR(100) NOT NULL,
    TAEOfertado             DECIMAL(5,3),
    TINOfertado             DECIMAL(5,3),
    ComisionApertura        DECIMAL(18,2),
    ComisionMantenimiento   DECIMAL(18,2),
    BonificacionAplicable   DECIMAL(5,2),
    CondicionesEspeciales   NVARCHAR(1000),
    FechaVigenciaDesde      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVigenciaHasta      DATE,
    CONSTRAINT FK_CondicionesComerciales_Producto FOREIGN KEY (ProductoID)        REFERENCES Producto.CatalogoProductos(ProductoID),
    CONSTRAINT FK_CondicionesComerciales_Segmento FOREIGN KEY (SegmentoClienteID) REFERENCES Cliente.Segmentos(SegmentoID)
);
GO

IF OBJECT_ID('Producto.TarifasComisiones', 'U') IS NOT NULL DROP TABLE Producto.TarifasComisiones;
GO
CREATE TABLE Producto.TarifasComisiones (
    TarifaComisionID        INT IDENTITY(1,1) PRIMARY KEY,
    ProductoID              INT NOT NULL,
    TipoComision            NVARCHAR(100) NOT NULL,
    DescripcionComision     NVARCHAR(500),
    ImporteFijo             DECIMAL(18,2),
    PorcentajeVariable      DECIMAL(5,3),
    ImporteMinimo           DECIMAL(18,2),
    ImporteMaximo           DECIMAL(18,2),
    BaseCalculo             NVARCHAR(200),
    Periodicidad            NVARCHAR(50),
    FechaVigenciaDesde      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVigenciaHasta      DATE,
    CONSTRAINT FK_TarifasComisiones_Producto FOREIGN KEY (ProductoID) REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

IF OBJECT_ID('Producto.HistorialPrecios', 'U') IS NOT NULL DROP TABLE Producto.HistorialPrecios;
GO
CREATE TABLE Producto.HistorialPrecios (
    HistorialPrecioID   INT IDENTITY(1,1) PRIMARY KEY,
    ProductoID          INT NOT NULL,
    TAEAnterior         DECIMAL(5,3),
    TAENuevo            DECIMAL(5,3),
    TINAnterior         DECIMAL(5,3),
    TINNuevo            DECIMAL(5,3),
    FechaCambio         DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    MotivoCambio        NVARCHAR(500),
    UsuarioAutorizacion NVARCHAR(100),
    CONSTRAINT FK_HistorialPrecios_Producto FOREIGN KEY (ProductoID) REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

IF OBJECT_ID('Producto.ConfiguracionProducto', 'U') IS NOT NULL DROP TABLE Producto.ConfiguracionProducto;
GO
CREATE TABLE Producto.ConfiguracionProducto (
    ConfiguracionID         INT IDENTITY(1,1) PRIMARY KEY,
    ProductoID              INT NOT NULL,
    ParametroConfiguracion  NVARCHAR(100) NOT NULL,
    ValorConfiguracion      NVARCHAR(500),
    TipoDato                NVARCHAR(50),
    Descripcion             NVARCHAR(500),
    EsEditable              BIT NOT NULL DEFAULT 1,
    FechaActualizacion      DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_ConfiguracionProducto_Producto FOREIGN KEY (ProductoID) REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

IF OBJECT_ID('Producto.PaquetesProductos', 'U') IS NOT NULL DROP TABLE Producto.PaquetesProductos;
GO
CREATE TABLE Producto.PaquetesProductos (
    PaqueteProductoID   INT IDENTITY(1,1) PRIMARY KEY,
    CodigoPaquete       NVARCHAR(50)   NOT NULL UNIQUE,
    NombrePaquete       NVARCHAR(200)  NOT NULL,
    Descripcion         NVARCHAR(1000),
    ProductosPaquete    NVARCHAR(MAX),
    DescuentoAplicable  DECIMAL(5,2),
    ComisionPaquete     DECIMAL(18,2),
    SegmentoObjetivo    INT,
    EsActivo            BIT NOT NULL DEFAULT 1,
    FechaVigenciaDesde  DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVigenciaHasta  DATE,
    CONSTRAINT FK_PaquetesProductos_Segmento FOREIGN KEY (SegmentoObjetivo) REFERENCES Cliente.Segmentos(SegmentoID)
);
GO
PRINT ' FIN DOMINIO 2: Producto (8 tablas)';
GO

-- DOMINIO 3: CUENTA (7 tablas)
-- CAMBIO 1: FechaModificacion añadida en CuentasCorrientes, CuentasAhorro,
--           CuentasNomina y MovimientosCuenta

IF OBJECT_ID('Cuenta.TiposCuenta', 'U') IS NOT NULL DROP TABLE Cuenta.TiposCuenta;
GO
CREATE TABLE Cuenta.TiposCuenta (
    TipoCuentaID        INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTipoCuenta    NVARCHAR(20)  NOT NULL UNIQUE,
    NombreTipoCuenta    NVARCHAR(100) NOT NULL,
    Descripcion         NVARCHAR(500),
    RequiereNomina      BIT NOT NULL DEFAULT 0,
    PermiteDescubierto  BIT NOT NULL DEFAULT 0,
    EsVigente           BIT NOT NULL DEFAULT 1
);
GO

-- Tabla 2: Cuenta.CuentasCorrientes [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Cuenta.CuentasCorrientes', 'U') IS NOT NULL DROP TABLE Cuenta.CuentasCorrientes;
GO
CREATE TABLE Cuenta.CuentasCorrientes (
    CuentaCorrienteID   INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta        NVARCHAR(24) NOT NULL UNIQUE,
    TipoCuentaID        INT NOT NULL,
    ProductoID          INT NOT NULL,
    FechaApertura       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaCierre         DATE,
    SaldoActual         DECIMAL(18,2) NOT NULL DEFAULT 0,
    SaldoDisponible     DECIMAL(18,2) NOT NULL DEFAULT 0,
    SaldoRetenido       DECIMAL(18,2) NOT NULL DEFAULT 0,
    LimiteDescubierto   DECIMAL(18,2),
    EstadoCuenta        NVARCHAR(50) NOT NULL CHECK (EstadoCuenta IN ('Activa','Bloqueada','Cerrada','Suspendida')),
    SucursalGestion     INT,
    FechaModificacion   DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_CuentasCorrientes_TipoCuenta FOREIGN KEY (TipoCuentaID) REFERENCES Cuenta.TiposCuenta(TipoCuentaID),
    CONSTRAINT FK_CuentasCorrientes_Producto   FOREIGN KEY (ProductoID)   REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

-- Tabla 3: Cuenta.CuentasAhorro [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Cuenta.CuentasAhorro', 'U') IS NOT NULL DROP TABLE Cuenta.CuentasAhorro;
GO
CREATE TABLE Cuenta.CuentasAhorro (
    CuentaAhorroID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta                NVARCHAR(24) NOT NULL UNIQUE,
    TipoCuentaID                INT NOT NULL,
    ProductoID                  INT NOT NULL,
    FechaApertura               DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaCierre                 DATE,
    SaldoActual                 DECIMAL(18,2) NOT NULL DEFAULT 0,
    TAEAplicado                 DECIMAL(5,3),
    FechaProximoAbono           DATE,
    InteresesDevengadosMes      DECIMAL(18,2) NOT NULL DEFAULT 0,
    EstadoCuenta                NVARCHAR(50) NOT NULL CHECK (EstadoCuenta IN ('Activa','Bloqueada','Cerrada','Suspendida')),
    FechaModificacion           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_CuentasAhorro_TipoCuenta FOREIGN KEY (TipoCuentaID) REFERENCES Cuenta.TiposCuenta(TipoCuentaID),
    CONSTRAINT FK_CuentasAhorro_Producto   FOREIGN KEY (ProductoID)   REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

-- Tabla 4: Cuenta.CuentasNomina [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Cuenta.CuentasNomina', 'U') IS NOT NULL DROP TABLE Cuenta.CuentasNomina;
GO
CREATE TABLE Cuenta.CuentasNomina (
    CuentaNominaID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta                NVARCHAR(24) NOT NULL UNIQUE,
    TipoCuentaID                INT NOT NULL,
    ProductoID                  INT NOT NULL,
    FechaApertura               DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaCierre                 DATE,
    SaldoActual                 DECIMAL(18,2) NOT NULL DEFAULT 0,
    SaldoDisponible             DECIMAL(18,2) NOT NULL DEFAULT 0,
    ImporteNominaUltimaMes      DECIMAL(18,2),
    FechaUltimaNomina           DATE,
    TieneNominaDomiciliada      BIT NOT NULL DEFAULT 1,
    BonificacionesAplicadas     DECIMAL(18,2) NOT NULL DEFAULT 0,
    EstadoCuenta                NVARCHAR(50) NOT NULL CHECK (EstadoCuenta IN ('Activa','Bloqueada','Cerrada','Suspendida')),
    FechaModificacion           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_CuentasNomina_TipoCuenta FOREIGN KEY (TipoCuentaID) REFERENCES Cuenta.TiposCuenta(TipoCuentaID),
    CONSTRAINT FK_CuentasNomina_Producto   FOREIGN KEY (ProductoID)   REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

IF OBJECT_ID('Cuenta.TitularesCuenta', 'U') IS NOT NULL DROP TABLE Cuenta.TitularesCuenta;
GO
CREATE TABLE Cuenta.TitularesCuenta (
    TitularCuentaID     INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta        NVARCHAR(24) NOT NULL,
    PersonaID           INT,
    PersonaJuridicaID   INT,
    TipoTitularidad     NVARCHAR(50) NOT NULL CHECK (TipoTitularidad IN ('Titular','Cotitular','Autorizado','Apoderado')),
    PorcentajePropiedad DECIMAL(5,2),
    FechaAltaTitular    DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaBajaTitular    DATE,
    CONSTRAINT FK_TitularesCuenta_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_TitularesCuenta_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_TitularesCuenta_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 6: Cuenta.MovimientosCuenta [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Cuenta.MovimientosCuenta', 'U') IS NOT NULL DROP TABLE Cuenta.MovimientosCuenta;
GO
CREATE TABLE Cuenta.MovimientosCuenta (
    MovimientoCuentaID          INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta                NVARCHAR(24)  NOT NULL,
    FechaMovimiento             DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaValor                  DATE NOT NULL,
    TipoMovimiento              NVARCHAR(100) NOT NULL,
    Concepto                    NVARCHAR(500),
    ImporteMovimiento           DECIMAL(18,2) NOT NULL,
    SaldoDespuesMovimiento      DECIMAL(18,2) NOT NULL,
    NumeroCuentaContrapartida   NVARCHAR(24),
    CodigoTransaccion           NVARCHAR(100),
    CanalOperacion              NVARCHAR(50),
    SucursalOperacion           INT,
    FechaModificacion           DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    INDEX IX_MovimientosCuenta_Cuenta_Fecha (NumeroCuenta, FechaMovimiento)
);
GO

IF OBJECT_ID('Cuenta.BloqueosCuenta', 'U') IS NOT NULL DROP TABLE Cuenta.BloqueosCuenta;
GO
CREATE TABLE Cuenta.BloqueosCuenta (
    BloqueoID           INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta        NVARCHAR(24) NOT NULL,
    TipoBloqueo         NVARCHAR(100) NOT NULL,
    MotivoBloqueo       NVARCHAR(500),
    ImporteBloqueado    DECIMAL(18,2),
    FechaBloqueo        DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaDesbloqueo     DATE,
    UsuarioBloqueo      NVARCHAR(100) NOT NULL DEFAULT SYSTEM_USER,
    EstadoBloqueo       NVARCHAR(50) NOT NULL DEFAULT 'Activo' CHECK (EstadoBloqueo IN ('Activo','Liberado','Cancelado'))
);
GO
PRINT 'FIN DOMINIO 3: Cuenta (7 tablas) ';
GO

-- DOMINIO 4: CREDITO (10 tablas - Avalistas eliminada, integrada en Avales)
-- CAMBIO 1: FechaModificacion en Prestamos, PrestamosHipotecarios,
--           PrestamosConsumo, LineaCredito
-- CAMBIO 2: Credito.Avalistas eliminada - campos integrados en Credito.Avales

IF OBJECT_ID('Credito.TiposGarantia', 'U') IS NOT NULL DROP TABLE Credito.TiposGarantia;
GO
CREATE TABLE Credito.TiposGarantia (
    TipoGarantiaID      INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTipoGarantia  NVARCHAR(20)  NOT NULL UNIQUE,
    NombreTipoGarantia  NVARCHAR(100) NOT NULL,
    Descripcion         NVARCHAR(500),
    RequiereValoracion  BIT NOT NULL DEFAULT 1,
    RequiereSeguro      BIT NOT NULL DEFAULT 0,
    EsVigente           BIT NOT NULL DEFAULT 1
);
GO

-- Tabla 2: Credito.Prestamos [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Credito.Prestamos', 'U') IS NOT NULL DROP TABLE Credito.Prestamos;
GO
CREATE TABLE Credito.Prestamos (
    PrestamoID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL UNIQUE,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    ProductoID              INT NOT NULL,
    ImporteConcedido        DECIMAL(18,2) NOT NULL,
    ImportePendiente        DECIMAL(18,2) NOT NULL,
    TINAplicado             DECIMAL(5,3)  NOT NULL,
    TAEAplicado             DECIMAL(5,3)  NOT NULL,
    TipoInteres             NVARCHAR(50) CHECK (TipoInteres IN ('Fijo','Variable','Mixto')),
    PlazoMeses              INT NOT NULL,
    FrecuenciaPago          NVARCHAR(50) NOT NULL,
    ImporteCuota            DECIMAL(18,2) NOT NULL,
    FechaFormalizacion      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaPrimerVencimiento  DATE NOT NULL,
    FechaUltimoVencimiento  DATE NOT NULL,
    FechaLiquidacion        DATE,
    EstadoPrestamo          NVARCHAR(50) NOT NULL CHECK (EstadoPrestamo IN ('Vigente','Vencido','Dudoso','Cancelado','Prejubilado')),
    SucursalGestion         INT,
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_Prestamos_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_Prestamos_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT FK_Prestamos_Producto       FOREIGN KEY (ProductoID)        REFERENCES Producto.CatalogoProductos(ProductoID),
    CONSTRAINT CHK_Prestamos_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 3: Credito.PrestamosHipotecarios [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Credito.PrestamosHipotecarios', 'U') IS NOT NULL DROP TABLE Credito.PrestamosHipotecarios;
GO
CREATE TABLE Credito.PrestamosHipotecarios (
    PrestamoHipotecarioID   INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL UNIQUE,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    ProductoID              INT NOT NULL,
    ImporteConcedido        DECIMAL(18,2) NOT NULL,
    ImportePendiente        DECIMAL(18,2) NOT NULL,
    TINAplicado             DECIMAL(5,3)  NOT NULL,
    TAEAplicado             DECIMAL(5,3)  NOT NULL,
    TipoInteres             NVARCHAR(50) CHECK (TipoInteres IN ('Fijo','Variable','Mixto')),
    IndiceReferencia        NVARCHAR(100),
    DiferencialAplicado     DECIMAL(5,3),
    PlazoMeses              INT NOT NULL,
    ImporteCuota            DECIMAL(18,2) NOT NULL,
    ValorTasacionInmueble   DECIMAL(18,2) NOT NULL,
    DireccionInmueble       NVARCHAR(500) NOT NULL,
    ReferenciaRegistral     NVARCHAR(200),
    LTVPorcentaje           DECIMAL(5,2)  NOT NULL,
    TieneSeguroVida         BIT NOT NULL DEFAULT 0,
    TieneSeguroHogar        BIT NOT NULL DEFAULT 0,
    FechaFormalizacion      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaPrimerVencimiento  DATE NOT NULL,
    FechaUltimoVencimiento  DATE NOT NULL,
    EstadoPrestamo          NVARCHAR(50) NOT NULL CHECK (EstadoPrestamo IN ('Vigente','Vencido','Dudoso','Cancelado','Prejubilado')),
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_PrestamosHipotecarios_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_PrestamosHipotecarios_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT FK_PrestamosHipotecarios_Producto       FOREIGN KEY (ProductoID)        REFERENCES Producto.CatalogoProductos(ProductoID),
    CONSTRAINT CHK_PrestamosHipotecarios_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

-- Tabla 4: Credito.PrestamosConsumo [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Credito.PrestamosConsumo', 'U') IS NOT NULL DROP TABLE Credito.PrestamosConsumo;
GO
CREATE TABLE Credito.PrestamosConsumo (
    PrestamoConsumoID       INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL UNIQUE,
    PersonaID               INT NOT NULL,
    ProductoID              INT NOT NULL,
    ImporteConcedido        DECIMAL(18,2) NOT NULL,
    ImportePendiente        DECIMAL(18,2) NOT NULL,
    TINAplicado             DECIMAL(5,3)  NOT NULL,
    TAEAplicado             DECIMAL(5,3)  NOT NULL,
    Finalidad               NVARCHAR(200),
    PlazoMeses              INT NOT NULL,
    ImporteCuota            DECIMAL(18,2) NOT NULL,
    FechaFormalizacion      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaPrimerVencimiento  DATE NOT NULL,
    FechaUltimoVencimiento  DATE NOT NULL,
    EstadoPrestamo          NVARCHAR(50) NOT NULL CHECK (EstadoPrestamo IN ('Vigente','Vencido','Dudoso','Cancelado')),
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_PrestamosConsumo_Persona  FOREIGN KEY (PersonaID)  REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_PrestamosConsumo_Producto FOREIGN KEY (ProductoID) REFERENCES Producto.CatalogoProductos(ProductoID)
);
GO

-- Tabla 5: Credito.LineaCredito [MAPEADA] - con FechaModificacion
IF OBJECT_ID('Credito.LineaCredito', 'U') IS NOT NULL DROP TABLE Credito.LineaCredito;
GO
CREATE TABLE Credito.LineaCredito (
    LineaCreditoID          INT IDENTITY(1,1) PRIMARY KEY,
    NumeroLinea             NVARCHAR(50) NOT NULL UNIQUE,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    ProductoID              INT NOT NULL,
    LimiteCredito           DECIMAL(18,2) NOT NULL,
    SaldoDispuesto          DECIMAL(18,2) NOT NULL DEFAULT 0,
    SaldoDisponible         DECIMAL(18,2) NOT NULL,
    TINAplicado             DECIMAL(5,3)  NOT NULL,
    ComisionApertura        DECIMAL(18,2),
    ComisionDisponibilidad  DECIMAL(18,2),
    FechaApertura           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVencimiento        DATE NOT NULL,
    FechaRevision           DATE,
    EstadoLinea             NVARCHAR(50) NOT NULL CHECK (EstadoLinea IN ('Activa','Bloqueada','Vencida','Cancelada')),
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    CONSTRAINT FK_LineaCredito_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_LineaCredito_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT FK_LineaCredito_Producto       FOREIGN KEY (ProductoID)        REFERENCES Producto.CatalogoProductos(ProductoID),
    CONSTRAINT CHK_LineaCredito_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    )
);
GO

IF OBJECT_ID('Credito.CuotasPrestamo', 'U') IS NOT NULL DROP TABLE Credito.CuotasPrestamo;
GO
CREATE TABLE Credito.CuotasPrestamo (
    CuotaPrestamoID     INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato      NVARCHAR(50) NOT NULL,
    NumeroCuota         INT NOT NULL,
    FechaVencimiento    DATE NOT NULL,
    ImporteCuota        DECIMAL(18,2) NOT NULL,
    ImporteCapital      DECIMAL(18,2) NOT NULL,
    ImporteIntereses    DECIMAL(18,2) NOT NULL,
    ImporteComisiones   DECIMAL(18,2) NOT NULL DEFAULT 0,
    CapitalPendiente    DECIMAL(18,2) NOT NULL,
    FechaPago           DATE,
    ImportePagado       DECIMAL(18,2),
    EstadoCuota         NVARCHAR(50) NOT NULL CHECK (EstadoCuota IN ('Pendiente','Pagada','Impagada','Parcialmente Pagada')),
    DiasRetraso         INT NOT NULL DEFAULT 0,
    INDEX IX_CuotasPrestamo_Contrato_Cuota (NumeroContrato, NumeroCuota)
);
GO

IF OBJECT_ID('Credito.AmortizacionesPagadas', 'U') IS NOT NULL DROP TABLE Credito.AmortizacionesPagadas;
GO
CREATE TABLE Credito.AmortizacionesPagadas (
    AmortizacionID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato              NVARCHAR(50) NOT NULL,
    FechaAmortizacion           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    TipoAmortizacion            NVARCHAR(50) NOT NULL CHECK (TipoAmortizacion IN ('Parcial','Total','Extraordinaria')),
    ImporteAmortizado           DECIMAL(18,2) NOT NULL,
    CapitalAmortizado           DECIMAL(18,2) NOT NULL,
    InteresesAmortizados        DECIMAL(18,2) NOT NULL,
    ComisionAmortizacion        DECIMAL(18,2) NOT NULL DEFAULT 0,
    CapitalPendienteDespues     DECIMAL(18,2) NOT NULL,
    MedioPago                   NVARCHAR(100),
    INDEX IX_AmortizacionesPagadas_Contrato_Fecha (NumeroContrato, FechaAmortizacion)
);
GO

IF OBJECT_ID('Credito.Garantias', 'U') IS NOT NULL DROP TABLE Credito.Garantias;
GO
CREATE TABLE Credito.Garantias (
    GarantiaID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL,
    TipoGarantiaID          INT NOT NULL,
    DescripcionGarantia     NVARCHAR(1000),
    ValorTasacion           DECIMAL(18,2),
    FechaTasacion           DATE,
    EntidadTasadora         NVARCHAR(200),
    DireccionGarantia       NVARCHAR(500),
    ReferenciaRegistral     NVARCHAR(200),
    TieneSeguro             BIT NOT NULL DEFAULT 0,
    FechaConstitucion       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaLiberacion         DATE,
    EstadoGarantia          NVARCHAR(50) NOT NULL DEFAULT 'Vigente' CHECK (EstadoGarantia IN ('Vigente','Liberada','Ejecutada')),
    CONSTRAINT FK_Garantias_TipoGarantia FOREIGN KEY (TipoGarantiaID) REFERENCES Credito.TiposGarantia(TipoGarantiaID)
);
GO

-- Tabla 9: Credito.Avales [MAPEADA]
-- CAMBIO 2: Avalistas eliminada - campos AvaladorPersonaID / AvaladorEmpresaID
--           integrados directamente aquí
IF OBJECT_ID('Credito.Avales', 'U') IS NOT NULL DROP TABLE Credito.Avales;
GO
CREATE TABLE Credito.Avales (
    AvalID                      INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato              NVARCHAR(50) NOT NULL,
    NumeroAval                  NVARCHAR(50) NOT NULL UNIQUE,
    -- Avalista integrado (CAMBIO 2)
    AvaladorPersonaID           INT,
    AvaladorEmpresaID           INT,
    AvaladorNombre              NVARCHAR(200),  -- para avalistas externos al banco
    TipoAvalador                NVARCHAR(50) NOT NULL DEFAULT 'Persona' CHECK (TipoAvalador IN ('Persona','Empresa','Externo')),
    -- Resto de campos originales
    TipoAval                    NVARCHAR(100) NOT NULL,
    ImporteAvalado              DECIMAL(18,2) NOT NULL,
    PorcentajeCobertura         DECIMAL(5,2)  NOT NULL DEFAULT 100.00,
    PorcentajeResponsabilidad   DECIMAL(5,2)  NOT NULL DEFAULT 100.00,
    FechaConstitucion           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVencimiento            DATE,
    EstadoAval                  NVARCHAR(50) NOT NULL DEFAULT 'Vigente' CHECK (EstadoAval IN ('Vigente','Ejecutado','Liberado','Cancelado')),
    CONSTRAINT FK_Avales_AvaladorPersona  FOREIGN KEY (AvaladorPersonaID) REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_Avales_AvaladorEmpresa  FOREIGN KEY (AvaladorEmpresaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_Avales_Avalista CHECK (
        (AvaladorPersonaID IS NOT NULL AND AvaladorEmpresaID IS NULL) OR
        (AvaladorPersonaID IS NULL     AND AvaladorEmpresaID IS NOT NULL) OR
        (AvaladorPersonaID IS NULL     AND AvaladorEmpresaID IS NULL AND AvaladorNombre IS NOT NULL)
    )
);
GO

IF OBJECT_ID('Credito.NotificacionesMorosidad', 'U') IS NOT NULL DROP TABLE Credito.NotificacionesMorosidad;
GO
CREATE TABLE Credito.NotificacionesMorosidad (
    NotificacionID              INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato              NVARCHAR(50) NOT NULL,
    TipoNotificacion            NVARCHAR(100) NOT NULL,
    FechaNotificacion           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    DiasRetrasoNotificacion     INT NOT NULL,
    ImporteReclamado            DECIMAL(18,2) NOT NULL,
    CanalNotificacion           NVARCHAR(50),
    EstadoNotificacion          NVARCHAR(50) NOT NULL CHECK (EstadoNotificacion IN ('Enviada','Recibida','Pendiente Respuesta','Resuelta')),
    FechaRespuesta              DATE,
    Observaciones               NVARCHAR(1000)
);
GO
PRINT ' FIN DOMINIO 4: Credito (10 tablas)';
GO

-- DOMINIO 5: TRANSFERENCIA (6 tablas)
-- CAMBIO 1: FechaModificacion en TransferenciasInternas, TransferenciasExternas

IF OBJECT_ID('Transferencia.TiposOperacion', 'U') IS NOT NULL DROP TABLE Transferencia.TiposOperacion;
GO
CREATE TABLE Transferencia.TiposOperacion (
    TipoOperacionID         INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTipoOperacion     NVARCHAR(20)  NOT NULL UNIQUE,
    NombreTipoOperacion     NVARCHAR(100) NOT NULL,
    Descripcion             NVARCHAR(500),
    RequiereValidacion      BIT NOT NULL DEFAULT 0,
    EsVigente               BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('Transferencia.TransferenciasInternas', 'U') IS NOT NULL DROP TABLE Transferencia.TransferenciasInternas;
GO
CREATE TABLE Transferencia.TransferenciasInternas (
    TransferenciaInternaID  INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOperacion         NVARCHAR(50)  NOT NULL UNIQUE,
    CuentaOrigen            NVARCHAR(24)  NOT NULL,
    CuentaDestino           NVARCHAR(24)  NOT NULL,
    ImporteTransferencia    DECIMAL(18,2) NOT NULL,
    Concepto                NVARCHAR(500),
    FechaOperacion          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaValor              DATE NOT NULL,
    EstadoTransferencia     NVARCHAR(50) NOT NULL CHECK (EstadoTransferencia IN ('Pendiente','Ejecutada','Rechazada','Cancelada')),
    CanalOperacion          NVARCHAR(50),
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    INDEX IX_TransferenciasInternas_Origen_Fecha (CuentaOrigen, FechaOperacion)
);
GO

IF OBJECT_ID('Transferencia.TransferenciasExternas', 'U') IS NOT NULL DROP TABLE Transferencia.TransferenciasExternas;
GO
CREATE TABLE Transferencia.TransferenciasExternas (
    TransferenciaExternaID  INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOperacion         NVARCHAR(50)  NOT NULL UNIQUE,
    CuentaOrigen            NVARCHAR(24)  NOT NULL,
    IBANDestino             NVARCHAR(34)  NOT NULL,
    EntidadDestino          NVARCHAR(200),
    ImporteTransferencia    DECIMAL(18,2) NOT NULL,
    Concepto                NVARCHAR(500),
    BeneficiarioNombre      NVARCHAR(200),
    FechaOperacion          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaValor              DATE NOT NULL,
    ComisionAplicada        DECIMAL(18,2) NOT NULL DEFAULT 0,
    EstadoTransferencia     NVARCHAR(50) NOT NULL CHECK (EstadoTransferencia IN ('Pendiente','Ejecutada','Rechazada','Cancelada')),
    CanalOperacion          NVARCHAR(50),
    FechaModificacion       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),  -- CAMBIO 1
    INDEX IX_TransferenciasExternas_Origen_Fecha (CuentaOrigen, FechaOperacion)
);
GO

IF OBJECT_ID('Transferencia.TransferenciasSEPA', 'U') IS NOT NULL DROP TABLE Transferencia.TransferenciasSEPA;
GO
CREATE TABLE Transferencia.TransferenciasSEPA (
    TransferenciaSEPAID     INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOperacion         NVARCHAR(50)  NOT NULL UNIQUE,
    CuentaOrigen            NVARCHAR(24)  NOT NULL,
    IBANDestino             NVARCHAR(34)  NOT NULL,
    BICDestino              NVARCHAR(11),
    PaisDestino             NVARCHAR(2)   NOT NULL,
    ImporteTransferencia    DECIMAL(18,2) NOT NULL,
    Concepto                NVARCHAR(500),
    BeneficiarioNombre      NVARCHAR(200),
    TipoSEPA                NVARCHAR(50) CHECK (TipoSEPA IN ('SCT','INST','B2B')),
    FechaOperacion          DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaValor              DATE NOT NULL,
    ComisionAplicada        DECIMAL(18,2) NOT NULL DEFAULT 0,
    EstadoTransferencia     NVARCHAR(50) NOT NULL CHECK (EstadoTransferencia IN ('Pendiente','Ejecutada','Rechazada','Cancelada')),
    INDEX IX_TransferenciasSEPA_Origen_Fecha (CuentaOrigen, FechaOperacion)
);
GO

IF OBJECT_ID('Transferencia.PagosRecurrentes', 'U') IS NOT NULL DROP TABLE Transferencia.PagosRecurrentes;
GO
CREATE TABLE Transferencia.PagosRecurrentes (
    PagoRecurrenteID        INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOrdenPermanente   NVARCHAR(50)  NOT NULL UNIQUE,
    CuentaOrigen            NVARCHAR(24)  NOT NULL,
    CuentaDestino           NVARCHAR(24)  NOT NULL,
    ImporteFijo             DECIMAL(18,2),
    Concepto                NVARCHAR(500),
    Periodicidad            NVARCHAR(50) NOT NULL CHECK (Periodicidad IN ('Semanal','Quincenal','Mensual','Trimestral','Semestral','Anual')),
    FechaPrimerPago         DATE NOT NULL,
    FechaProximoPago        DATE NOT NULL,
    FechaUltimoPago         DATE,
    FechaFinVigencia        DATE,
    EstadoOrden             NVARCHAR(50) NOT NULL DEFAULT 'Activa' CHECK (EstadoOrden IN ('Activa','Suspendida','Cancelada','Finalizada'))
);
GO

IF OBJECT_ID('Transferencia.OrdenesRechazadas', 'U') IS NOT NULL DROP TABLE Transferencia.OrdenesRechazadas;
GO
CREATE TABLE Transferencia.OrdenesRechazadas (
    OrdenRechazadaID    INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOperacion     NVARCHAR(50)  NOT NULL,
    CuentaOrigen        NVARCHAR(24)  NOT NULL,
    CuentaDestino       NVARCHAR(24),
    ImporteIntentado    DECIMAL(18,2) NOT NULL,
    FechaRechazo        DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    MotivoRechazo       NVARCHAR(500) NOT NULL,
    CodigoRechazo       NVARCHAR(20),
    TipoOperacion       NVARCHAR(100),
    INDEX IX_OrdenesRechazadas_Origen_Fecha (CuentaOrigen, FechaRechazo)
);
GO
PRINT ' FIN DOMINIO 5: Transferencia (6 tablas)';
GO

-- DOMINIO 6: RIESGO (8 tablas)



IF OBJECT_ID('Riesgo.EntidadesFinancieras', 'U') IS NOT NULL DROP TABLE Riesgo.EntidadesFinancieras;
GO
CREATE TABLE Riesgo.EntidadesFinancieras (
    EntidadFinancieraID INT IDENTITY(1,1) PRIMARY KEY,
    CodigoEntidad       NVARCHAR(20)  NOT NULL UNIQUE,
    NombreEntidad       NVARCHAR(200) NOT NULL,
    NIF                 NVARCHAR(20),
    TipoEntidad         NVARCHAR(100),
    Pais                NVARCHAR(100),
    EsVigente           BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('Riesgo.DeclaracionesCIRBE', 'U') IS NOT NULL DROP TABLE Riesgo.DeclaracionesCIRBE;
GO
CREATE TABLE Riesgo.DeclaracionesCIRBE (
    DeclaracionCIRBEID      INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    FechaDeclaracion        DATE NOT NULL,
    PeriodoDeclaracion      NVARCHAR(7) NOT NULL,
    RiesgoDirecto           DECIMAL(18,2) NOT NULL DEFAULT 0,
    RiesgoIndirecto         DECIMAL(18,2) NOT NULL DEFAULT 0,
    RiesgoTotal             DECIMAL(18,2) NOT NULL DEFAULT 0,
    RiesgoDudoso            DECIMAL(18,2) NOT NULL DEFAULT 0,
    NumeroOperaciones       INT NOT NULL DEFAULT 0,
    ClasificacionRiesgo     NVARCHAR(100),
    CONSTRAINT FK_DeclaracionesCIRBE_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_DeclaracionesCIRBE_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID),
    CONSTRAINT CHK_DeclaracionesCIRBE_Cliente CHECK (
        (PersonaID IS NOT NULL AND PersonaJuridicaID IS NULL) OR
        (PersonaID IS NULL     AND PersonaJuridicaID IS NOT NULL)
    ),
    INDEX IX_DeclaracionesCIRBE_Periodo (PeriodoDeclaracion)
);
GO

IF OBJECT_ID('Riesgo.OperacionesCIRBE', 'U') IS NOT NULL DROP TABLE Riesgo.OperacionesCIRBE;
GO
CREATE TABLE Riesgo.OperacionesCIRBE (
    OperacionCIRBEID        INT IDENTITY(1,1) PRIMARY KEY,
    DeclaracionCIRBEID      INT NOT NULL,
    EntidadFinancieraID     INT NOT NULL,
    NumeroOperacion         NVARCHAR(50),
    TipoOperacion           NVARCHAR(100) NOT NULL,
    NaturalezaOperacion     NVARCHAR(100),
    ImporteOperacion        DECIMAL(18,2) NOT NULL,
    SaldoVivo               DECIMAL(18,2) NOT NULL,
    TipoGarantia            NVARCHAR(100),
    EsOperacionDudosa       BIT NOT NULL DEFAULT 0,
    FechaVencimiento        DATE,
    CONSTRAINT FK_OperacionesCIRBE_Declaracion       FOREIGN KEY (DeclaracionCIRBEID)  REFERENCES Riesgo.DeclaracionesCIRBE(DeclaracionCIRBEID),
    CONSTRAINT FK_OperacionesCIRBE_EntidadFinanciera FOREIGN KEY (EntidadFinancieraID) REFERENCES Riesgo.EntidadesFinancieras(EntidadFinancieraID)
);
GO

IF OBJECT_ID('Riesgo.ClasificacionesRiesgo', 'U') IS NOT NULL DROP TABLE Riesgo.ClasificacionesRiesgo;
GO
CREATE TABLE Riesgo.ClasificacionesRiesgo (
    ClasificacionRiesgoID   INT IDENTITY(1,1) PRIMARY KEY,
    CodigoClasificacion     NVARCHAR(20)  NOT NULL UNIQUE,
    NombreClasificacion     NVARCHAR(100) NOT NULL,
    Descripcion             NVARCHAR(500),
    NivelRiesgo             TINYINT CHECK (NivelRiesgo BETWEEN 1 AND 5),
    PorcentajeProvision     DECIMAL(5,2),
    EsVigente               BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('Riesgo.ProvisionesContables', 'U') IS NOT NULL DROP TABLE Riesgo.ProvisionesContables;
GO
CREATE TABLE Riesgo.ProvisionesContables (
    ProvisionID             INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL,
    FechaProvision          DATE NOT NULL,
    TipoProvision           NVARCHAR(100) NOT NULL,
    ImporteProvisionado     DECIMAL(18,2) NOT NULL,
    ImporteRecuperado       DECIMAL(18,2) NOT NULL DEFAULT 0,
    SaldoProvision          DECIMAL(18,2) NOT NULL,
    ClasificacionRiesgoID   INT,
    Observaciones           NVARCHAR(1000),
    CONSTRAINT FK_ProvisionesContables_Clasificacion FOREIGN KEY (ClasificacionRiesgoID) REFERENCES Riesgo.ClasificacionesRiesgo(ClasificacionRiesgoID),
    INDEX IX_ProvisionesContables_Contrato_Fecha (NumeroContrato, FechaProvision)
);
GO

IF OBJECT_ID('Riesgo.OperacionesDudosas', 'U') IS NOT NULL DROP TABLE Riesgo.OperacionesDudosas;
GO
CREATE TABLE Riesgo.OperacionesDudosas (
    OperacionDudosaID       INT IDENTITY(1,1) PRIMARY KEY,
    NumeroContrato          NVARCHAR(50) NOT NULL,
    FechaDeclaracionDudosa  DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    MotivoDudoso            NVARCHAR(500) NOT NULL,
    ImporteDudoso           DECIMAL(18,2) NOT NULL,
    DiasImpago              INT NOT NULL,
    ClasificacionRiesgoID   INT NOT NULL,
    FechaRecuperacion       DATE,
    ImporteRecuperado       DECIMAL(18,2) NOT NULL DEFAULT 0,
    EstadoOperacion         NVARCHAR(50) NOT NULL DEFAULT 'Dudoso' CHECK (EstadoOperacion IN ('Dudoso','Recuperado','Fallido')),
    CONSTRAINT FK_OperacionesDudosas_Clasificacion FOREIGN KEY (ClasificacionRiesgoID) REFERENCES Riesgo.ClasificacionesRiesgo(ClasificacionRiesgoID)
);
GO

-- Tabla 7: Riesgo.AlertasBlanqueoCapitales [MAPEADA] - CAMBIO 3
IF OBJECT_ID('Riesgo.AlertasBlanqueoCapitales', 'U') IS NOT NULL DROP TABLE Riesgo.AlertasBlanqueoCapitales;
GO
CREATE TABLE Riesgo.AlertasBlanqueoCapitales (
    AlertaID                INT IDENTITY(1,1) PRIMARY KEY,
    PersonaID               INT,
    PersonaJuridicaID       INT,
    TipoAlerta              NVARCHAR(100) NOT NULL,
    NivelGravedad           NVARCHAR(50)  NOT NULL CHECK (NivelGravedad IN ('Baja','Media','Alta','Crítica')),
    DescripcionAlerta       NVARCHAR(2000) NOT NULL,
    ImporteOperacion        DECIMAL(18,2) NULL,     -- NULL intencionado: dato sucio para DQ
    FechaAlerta             DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    EstadoAlerta            NVARCHAR(50) NOT NULL DEFAULT 'Pendiente'
                                CHECK (EstadoAlerta IN ('Pendiente','En Investigación','Resuelta','Reportada','Descartada')),
    FechaResolucion         DATE NULL,              -- NULL = alerta sin resolver (imperfección controlada)
    UsuarioAsignado         NVARCHAR(100),
    CONSTRAINT FK_AlertasBlanqueo_Persona        FOREIGN KEY (PersonaID)         REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_AlertasBlanqueo_PersonaJuridica FOREIGN KEY (PersonaJuridicaID) REFERENCES Cliente.PersonasJuridicas(PersonaJuridicaID)
);
GO

IF OBJECT_ID('Riesgo.RevisionesNormativas', 'U') IS NOT NULL DROP TABLE Riesgo.RevisionesNormativas;
GO
CREATE TABLE Riesgo.RevisionesNormativas (
    RevisionID              INT IDENTITY(1,1) PRIMARY KEY,
    TipoRevision            NVARCHAR(100) NOT NULL,
    FechaRevision           DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    AlcanceRevision         NVARCHAR(500),
    ResultadosRevision      NVARCHAR(MAX),
    HallazgosIdentificados  NVARCHAR(MAX),
    AccionesCorrectivas     NVARCHAR(MAX),
    ResponsableRevision     NVARCHAR(100),
    EstadoRevision          NVARCHAR(50) NOT NULL DEFAULT 'En Curso' CHECK (EstadoRevision IN ('Planificada','En Curso','Completada','Cerrada'))
);
GO
PRINT ' FIN DOMINIO 6: Riesgo (8 tablas)';
GO

-- DOMINIO 7: ORGANIZACION (6 tablas)

IF OBJECT_ID('Organizacion.Departamentos', 'U') IS NOT NULL DROP TABLE Organizacion.Departamentos;
GO
CREATE TABLE Organizacion.Departamentos (
    DepartamentoID          INT IDENTITY(1,1) PRIMARY KEY,
    CodigoDepartamento      NVARCHAR(20)  NOT NULL UNIQUE,
    NombreDepartamento      NVARCHAR(100) NOT NULL,
    DepartamentoPadreID     INT,
    Nivel                   TINYINT NOT NULL DEFAULT 1,
    EsVigente               BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Departamentos_Padre FOREIGN KEY (DepartamentoPadreID) REFERENCES Organizacion.Departamentos(DepartamentoID)
);
GO

IF OBJECT_ID('Organizacion.ZonasGeograficas', 'U') IS NOT NULL DROP TABLE Organizacion.ZonasGeograficas;
GO
CREATE TABLE Organizacion.ZonasGeograficas (
    ZonaGeograficaID    INT IDENTITY(1,1) PRIMARY KEY,
    CodigoZona          NVARCHAR(20)  NOT NULL UNIQUE,
    NombreZona          NVARCHAR(100) NOT NULL,
    TipoZona            NVARCHAR(50) CHECK (TipoZona IN ('Nacional','Autonómica','Provincial','Comarcal')),
    ZonaPadreID         INT,
    EsVigente           BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_ZonasGeograficas_Padre FOREIGN KEY (ZonaPadreID) REFERENCES Organizacion.ZonasGeograficas(ZonaGeograficaID)
);
GO

-- Tabla 3: Organizacion.Sucursales [MAPEADA]
IF OBJECT_ID('Organizacion.Sucursales', 'U') IS NOT NULL DROP TABLE Organizacion.Sucursales;
GO
CREATE TABLE Organizacion.Sucursales (
    SucursalID          INT IDENTITY(1,1) PRIMARY KEY,
    CodigoSucursal      NVARCHAR(20)  NOT NULL UNIQUE,
    NombreSucursal      NVARCHAR(200) NOT NULL,
    DireccionCompleta   NVARCHAR(500),
    CodigoPostal        NVARCHAR(10),
    Localidad           NVARCHAR(100),
    Provincia           NVARCHAR(100),
    ZonaGeograficaID    INT,
    Telefono            NVARCHAR(20),
    Email               NVARCHAR(255),
    DirectorSucursal    INT,
    NumeroEmpleados     INT NOT NULL DEFAULT 0,
    FechaApertura       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaCierre         DATE,
    EstadoSucursal      NVARCHAR(50) NOT NULL DEFAULT 'Activa' CHECK (EstadoSucursal IN ('Activa','Cerrada','En Obras')),
    CONSTRAINT FK_Sucursales_ZonaGeografica FOREIGN KEY (ZonaGeograficaID) REFERENCES Organizacion.ZonasGeograficas(ZonaGeograficaID)
);
GO

IF OBJECT_ID('Organizacion.CajeroAutomaticos', 'U') IS NOT NULL DROP TABLE Organizacion.CajeroAutomaticos;
GO
CREATE TABLE Organizacion.CajeroAutomaticos (
    CajeroID            INT IDENTITY(1,1) PRIMARY KEY,
    CodigoCajero        NVARCHAR(20)  NOT NULL UNIQUE,
    SucursalID          INT,
    Ubicacion           NVARCHAR(500) NOT NULL,
    TipoCajero          NVARCHAR(50) CHECK (TipoCajero IN ('Interno','Externo','Drive-Through')),
    DireccionCompleta   NVARCHAR(500),
    CodigoPostal        NVARCHAR(10),
    Localidad           NVARCHAR(100),
    Provincia           NVARCHAR(100),
    Disponibilidad      NVARCHAR(50),
    LimiteRetiroDiario  DECIMAL(18,2),
    FechaInstalacion    DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaRetiro         DATE,
    EstadoCajero        NVARCHAR(50) NOT NULL DEFAULT 'Operativo' CHECK (EstadoCajero IN ('Operativo','Fuera de Servicio','Mantenimiento','Retirado')),
    CONSTRAINT FK_CajeroAutomaticos_Sucursal FOREIGN KEY (SucursalID) REFERENCES Organizacion.Sucursales(SucursalID)
);
GO

-- Tabla 5: Organizacion.Empleados [MAPEADA]
IF OBJECT_ID('Organizacion.Empleados', 'U') IS NOT NULL DROP TABLE Organizacion.Empleados;
GO
CREATE TABLE Organizacion.Empleados (
    EmpleadoID      INT IDENTITY(1,1) PRIMARY KEY,
    NumeroEmpleado  NVARCHAR(20)  NOT NULL UNIQUE,
    PersonaID       INT NOT NULL,
    DepartamentoID  INT NOT NULL,
    SucursalID      INT,
    Puesto          NVARCHAR(200) NOT NULL,
    Categoria       NVARCHAR(100),
    SupervisorID    INT,
    FechaAlta       DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaBaja       DATE,
    EstadoEmpleado  NVARCHAR(50) NOT NULL DEFAULT 'Activo' CHECK (EstadoEmpleado IN ('Activo','Baja','Suspendido','Excedencia')),
    CONSTRAINT FK_Empleados_Persona      FOREIGN KEY (PersonaID)      REFERENCES Cliente.Personas(PersonaID),
    CONSTRAINT FK_Empleados_Departamento FOREIGN KEY (DepartamentoID) REFERENCES Organizacion.Departamentos(DepartamentoID),
    CONSTRAINT FK_Empleados_Sucursal     FOREIGN KEY (SucursalID)     REFERENCES Organizacion.Sucursales(SucursalID),
    CONSTRAINT FK_Empleados_Supervisor   FOREIGN KEY (SupervisorID)   REFERENCES Organizacion.Empleados(EmpleadoID)
);
GO

IF OBJECT_ID('Organizacion.ConfiguracionHorarios', 'U') IS NOT NULL DROP TABLE Organizacion.ConfiguracionHorarios;
GO
CREATE TABLE Organizacion.ConfiguracionHorarios (
    ConfiguracionHorarioID  INT IDENTITY(1,1) PRIMARY KEY,
    SucursalID              INT,
    CajeroID                INT,
    DiaSemana               TINYINT CHECK (DiaSemana BETWEEN 1 AND 7),
    HoraApertura            TIME,
    HoraCierre              TIME,
    EsFestivo               BIT NOT NULL DEFAULT 0,
    FechaVigenciaDesde      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    FechaVigenciaHasta      DATE,
    CONSTRAINT FK_ConfiguracionHorarios_Sucursal FOREIGN KEY (SucursalID) REFERENCES Organizacion.Sucursales(SucursalID),
    CONSTRAINT FK_ConfiguracionHorarios_Cajero   FOREIGN KEY (CajeroID)   REFERENCES Organizacion.CajeroAutomaticos(CajeroID),
    CONSTRAINT CHK_ConfiguracionHorarios_Ubicacion CHECK (
        (SucursalID IS NOT NULL AND CajeroID IS NULL) OR
        (SucursalID IS NULL     AND CajeroID IS NOT NULL)
    )
);
GO
PRINT ' FIN DOMINIO 7: Organizacion (6 tablas) ¡';
GO

-- RESUMEN BRONZE
PRINT '';
PRINT 'Schemas creados: 7';
PRINT '  - Cliente      (12 tablas)';
PRINT '  - Producto     ( 8 tablas)';
PRINT '  - Cuenta       ( 7 tablas)  - FechaModificacion añadida';
PRINT '  - Credito      (10 tablas)  - Avalistas integrada en Avales';
PRINT '  - Transferencia( 6 tablas)  - FechaModificacion añadida';
PRINT '  - Riesgo       ( 8 tablas)  - AlertasBlanqueoCapitales MAPEADA';
PRINT '  - Organizacion ( 6 tablas)';
PRINT '--------------------------------------------------------------------------------';


GO

-- PARTE 2: SILVER - USE WideWorldImportersDW
-- (sin cambios respecto al original - se incluye completa para ejecutar de una vez)

USE WideWorldImportersDW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Integration')
    EXEC('CREATE SCHEMA Integration');
GO
PRINT ' Schema Integration verificado correctamente';
GO

-- DOMINIO 1: CLIENTE - STAGING
IF OBJECT_ID('Integration.Cliente_Staging','U') IS NOT NULL DROP TABLE Integration.Cliente_Staging;
GO
CREATE TABLE Integration.Cliente_Staging (
    [Cliente Staging Key]               INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                    INT NOT NULL,
    [Tipo Cliente]                      NVARCHAR(50) NOT NULL CHECK ([Tipo Cliente] IN ('Persona Física','Persona Jurídica')),
    [Numero Documento]                  NVARCHAR(20) NOT NULL,
    [Nombre Completo]                   NVARCHAR(300) NOT NULL,
    [Fecha Nacimiento Constitucion]     DATE,
    [Edad]                              INT,
    [Sexo]                              NVARCHAR(20),
    [Nacionalidad]                      NVARCHAR(100),
    [Forma Juridica]                    NVARCHAR(100),
    [CNAE]                              NVARCHAR(10),
    [Email]                             NVARCHAR(255),
    [Telefono Movil]                    NVARCHAR(20),
    [Telefono Fijo]                     NVARCHAR(20),
    [Direccion Completa]                NVARCHAR(500),
    [Codigo Postal]                     NVARCHAR(5),
    [Localidad]                         NVARCHAR(100),
    [Provincia]                         NVARCHAR(100),
    [Pais]                              NVARCHAR(100),
    [Segmento]                          NVARCHAR(100),
    [Subsegmento]                       NVARCHAR(100),
    [Clasificacion Comercial]           NVARCHAR(100),
    [Potencial Negocio]                 NVARCHAR(50),
    [Es Cliente Activo]                 BIT NOT NULL DEFAULT 1,
    [Fecha Alta]                        DATE NOT NULL,
    [Fecha Baja]                        DATE,
    [Valid From]                        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                          DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                       INT NOT NULL DEFAULT 1,
    INDEX IX_Cliente_Staging_WWI_ID ([WWI Cliente ID])
);
GO

IF OBJECT_ID('Integration.PerfilRiesgo_Staging','U') IS NOT NULL DROP TABLE Integration.PerfilRiesgo_Staging;
GO
CREATE TABLE Integration.PerfilRiesgo_Staging (
    [Perfil Riesgo Staging Key]             INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                        INT NOT NULL,
    [Score Credito]                         INT,
    [Nivel Riesgo]                          NVARCHAR(50),
    [Probabilidad Impago]                   DECIMAL(5,2),
    [Limite Endeudamiento]                  DECIMAL(18,2),
    [Fecha Calculo Score]                   DATE,
    [Fuente Score]                          NVARCHAR(100),
    [Modelo Scoring]                        NVARCHAR(100),
    [Numero Transacciones Mes]              INT,
    [Importe Promedio Transaccion]          DECIMAL(18,2),
    [Volumen Mensual Operaciones]           DECIMAL(18,2),
    [Numero Transferencias Internacionales] INT,
    [Tiene Operativa Inusual]               BIT NOT NULL DEFAULT 0,
    [Fecha Actualizacion]                   DATE NOT NULL,
    [Valid From]                            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                           INT NOT NULL DEFAULT 1,
    INDEX IX_PerfilRiesgo_Staging_Cliente ([WWI Cliente ID])
);
GO

IF OBJECT_ID('Integration.DireccionCliente_Staging','U') IS NOT NULL DROP TABLE Integration.DireccionCliente_Staging;
GO
CREATE TABLE Integration.DireccionCliente_Staging (
    [Direccion Cliente Staging Key] INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                INT NOT NULL,
    [Tipo Direccion]                NVARCHAR(50) NOT NULL,
    [Via Completa]                  NVARCHAR(300),
    [Codigo Postal]                 NVARCHAR(5),
    [Localidad]                     NVARCHAR(100),
    [Provincia]                     NVARCHAR(100),
    [Pais]                          NVARCHAR(100) NOT NULL DEFAULT 'España',
    [Es Direccion Principal]        BIT NOT NULL DEFAULT 0,
    [Fecha Desde]                   DATE NOT NULL,
    [Fecha Hasta]                   DATE,
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_DireccionCliente_Staging_Cliente ([WWI Cliente ID])
);
GO

IF OBJECT_ID('Integration.DocumentoIdentidad_Staging','U') IS NOT NULL DROP TABLE Integration.DocumentoIdentidad_Staging;
GO
CREATE TABLE Integration.DocumentoIdentidad_Staging (
    [Documento Identidad Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                   INT NOT NULL,
    [Tipo Documento]                   NVARCHAR(100) NOT NULL,
    [Numero Documento]                 NVARCHAR(20) NOT NULL,
    [Fecha Emision]                    DATE,
    [Fecha Caducidad]                  DATE,
    [Pais Emision]                     NVARCHAR(100),
    [Documento Verificado]             BIT NOT NULL DEFAULT 0,
    [Fecha Verificacion]               DATE,
    [Valid From]                       DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                         DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                      INT NOT NULL DEFAULT 1,
    INDEX IX_DocumentoIdentidad_Staging_Cliente ([WWI Cliente ID])
);
GO

IF OBJECT_ID('Integration.SegmentacionCliente_Staging','U') IS NOT NULL DROP TABLE Integration.SegmentacionCliente_Staging;
GO
CREATE TABLE Integration.SegmentacionCliente_Staging (
    [Segmentacion Staging Key] INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]           INT NOT NULL,
    [Segmento]                 NVARCHAR(100),
    [Subsegmento]              NVARCHAR(100),
    [Cluster RFM]              NVARCHAR(50),
    [Valor Cliente]            DECIMAL(18,2),
    [Probabilidad Churn]       DECIMAL(5,2),
    [Fecha Segmentacion]       DATE NOT NULL,
    [Valid From]               DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                 DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]              INT NOT NULL DEFAULT 1
);
GO
PRINT ' FIN DOMINIO 1: Cliente Staging (5 tablas)';
GO

-- DOMINIO 2: PRODUCTO - STAGING
IF OBJECT_ID('Integration.Producto_Staging','U') IS NOT NULL DROP TABLE Integration.Producto_Staging;
GO
CREATE TABLE Integration.Producto_Staging (
    [Producto Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Producto ID]       INT NOT NULL,
    [Codigo Producto]       NVARCHAR(50) NOT NULL,
    [Nombre Producto]       NVARCHAR(200) NOT NULL,
    [Descripcion]           NVARCHAR(1000),
    [Tipo Producto]         NVARCHAR(100) NOT NULL,
    [Categoria Producto]    NVARCHAR(100) NOT NULL,
    [TAE]                   DECIMAL(5,3),
    [TIN]                   DECIMAL(5,3),
    [Comision]              DECIMAL(18,2),
    [Importe Minimo]        DECIMAL(18,2),
    [Importe Maximo]        DECIMAL(18,2),
    [Plazo Minimo Dias]     INT,
    [Plazo Maximo Dias]     INT,
    [Requiere Garantia]     BIT NOT NULL DEFAULT 0,
    [Edad Minima]           INT,
    [Edad Maxima]           INT,
    [Es Comercializable]    BIT NOT NULL DEFAULT 1,
    [Fecha Lanzamiento]     DATE NOT NULL,
    [Fecha Retiro]          DATE,
    [Valid From]            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]           INT NOT NULL DEFAULT 1,
    INDEX IX_Producto_Staging_WWI_ID ([WWI Producto ID])
);
GO

IF OBJECT_ID('Integration.Comision_Staging','U') IS NOT NULL DROP TABLE Integration.Comision_Staging;
GO
CREATE TABLE Integration.Comision_Staging (
    [Comision Staging Key]      INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Producto ID]           INT NOT NULL,
    [Tipo Comision]             NVARCHAR(100) NOT NULL,
    [Descripcion Comision]      NVARCHAR(500),
    [Importe Fijo]              DECIMAL(18,2),
    [Porcentaje Variable]       DECIMAL(5,3),
    [Importe Minimo]            DECIMAL(18,2),
    [Importe Maximo]            DECIMAL(18,2),
    [Base Calculo]              NVARCHAR(200),
    [Periodicidad]              NVARCHAR(50),
    [Fecha Vigencia Desde]      DATE NOT NULL,
    [Fecha Vigencia Hasta]      DATE,
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_Comision_Staging_Producto ([WWI Producto ID])
);
GO

IF OBJECT_ID('Integration.CondicionesProducto_Staging','U') IS NOT NULL DROP TABLE Integration.CondicionesProducto_Staging;
GO
CREATE TABLE Integration.CondicionesProducto_Staging (
    [Condiciones Staging Key]   INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Producto ID]           INT NOT NULL,
    [Segmento Cliente]          NVARCHAR(100),
    [Tipo Condicion]            NVARCHAR(100) NOT NULL,
    [TAE Ofertado]              DECIMAL(5,3),
    [TIN Ofertado]              DECIMAL(5,3),
    [Comision Apertura]         DECIMAL(18,2),
    [Comision Mantenimiento]    DECIMAL(18,2),
    [Bonificacion Aplicable]    DECIMAL(5,2),
    [Fecha Vigencia Desde]      DATE NOT NULL,
    [Fecha Vigencia Hasta]      DATE,
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_CondicionesProducto_Staging_Producto ([WWI Producto ID])
);
GO

IF OBJECT_ID('Integration.TarifaVigente_Staging','U') IS NOT NULL DROP TABLE Integration.TarifaVigente_Staging;
GO
CREATE TABLE Integration.TarifaVigente_Staging (
    [Tarifa Vigente Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Producto ID]               INT NOT NULL,
    [Tipo Comision]                 NVARCHAR(100) NOT NULL,
    [TAE Vigente]                   DECIMAL(5,3),
    [TIN Vigente]                   DECIMAL(5,3),
    [Comision Vigente]              DECIMAL(18,2),
    [Fecha Vigencia]                DATE NOT NULL,
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_TarifaVigente_Staging_Producto_Fecha ([WWI Producto ID],[Fecha Vigencia])
);
GO
PRINT ' FIN DOMINIO 2: Producto Staging (4 tablas)';
GO

-- DOMINIO 3: CUENTA - STAGING
IF OBJECT_ID('Integration.Cuenta_Staging','U') IS NOT NULL DROP TABLE Integration.Cuenta_Staging;
GO
CREATE TABLE Integration.Cuenta_Staging (
    [Cuenta Staging Key]        INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cuenta ID]             INT NOT NULL,
    [Numero Cuenta]             NVARCHAR(24) NOT NULL,
    [Tipo Cuenta]               NVARCHAR(100) NOT NULL,
    [Producto]                  NVARCHAR(200) NOT NULL,
    [Cliente ID]                INT NOT NULL,
    [Nombre Cliente]            NVARCHAR(300),
    [Fecha Apertura]            DATE NOT NULL,
    [Fecha Cierre]              DATE,
    [Saldo Actual]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Saldo Disponible]          DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Saldo Retenido]            DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Limite Descubierto]        DECIMAL(18,2),
    [TAE Aplicado]              DECIMAL(5,3),
    [Tiene Nomina Domiciliada]  BIT NOT NULL DEFAULT 0,
    [Estado Cuenta]             NVARCHAR(50) NOT NULL,
    [Sucursal Gestion]          NVARCHAR(200),
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_Cuenta_Staging_WWI_ID ([WWI Cuenta ID]),
    INDEX IX_Cuenta_Staging_Cliente ([Cliente ID])
);
GO

IF OBJECT_ID('Integration.Movimiento_Staging','U') IS NOT NULL DROP TABLE Integration.Movimiento_Staging;
GO
CREATE TABLE Integration.Movimiento_Staging (
    [Movimiento Staging Key]            INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Movimiento ID]                 INT NOT NULL,
    [Numero Cuenta]                     NVARCHAR(24) NOT NULL,
    [Fecha Movimiento]                  DATE NOT NULL,
    [Fecha Valor]                       DATE NOT NULL,
    [Tipo Movimiento]                   NVARCHAR(100) NOT NULL,
    [Concepto]                          NVARCHAR(500),
    [Importe Movimiento]                DECIMAL(18,2) NOT NULL,
    [Saldo Despues Movimiento]          DECIMAL(18,2) NOT NULL,
    [Numero Cuenta Contrapartida]       NVARCHAR(24),
    [Canal Operacion]                   NVARCHAR(50),
    [Sucursal Operacion]                NVARCHAR(200),
    [Valid From]                        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                          DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                       INT NOT NULL DEFAULT 1,
    INDEX IX_Movimiento_Staging_Cuenta_Fecha ([Numero Cuenta],[Fecha Movimiento])
);
GO

IF OBJECT_ID('Integration.SaldoDiario_Staging','U') IS NOT NULL DROP TABLE Integration.SaldoDiario_Staging;
GO
CREATE TABLE Integration.SaldoDiario_Staging (
    [Saldo Diario Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [Numero Cuenta]             NVARCHAR(24) NOT NULL,
    [Fecha]                     DATE NOT NULL,
    [Saldo Apertura]            DECIMAL(18,2) NOT NULL,
    [Saldo Cierre]              DECIMAL(18,2) NOT NULL,
    [Saldo Minimo]              DECIMAL(18,2) NOT NULL,
    [Saldo Maximo]              DECIMAL(18,2) NOT NULL,
    [Saldo Promedio]            DECIMAL(18,2) NOT NULL,
    [Numero Movimientos]        INT NOT NULL DEFAULT 0,
    [Importe Total Entradas]    DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Importe Total Salidas]     DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_SaldoDiario_Staging_Cuenta_Fecha ([Numero Cuenta],[Fecha])
);
GO

IF OBJECT_ID('Integration.TitularidadCuenta_Staging','U') IS NOT NULL DROP TABLE Integration.TitularidadCuenta_Staging;
GO
CREATE TABLE Integration.TitularidadCuenta_Staging (
    [Titularidad Staging Key]   INT IDENTITY(1,1) PRIMARY KEY,
    [Numero Cuenta]             NVARCHAR(24) NOT NULL,
    [Cliente ID]                INT NOT NULL,
    [Nombre Cliente]            NVARCHAR(300),
    [Tipo Titularidad]          NVARCHAR(50) NOT NULL,
    [Porcentaje Propiedad]      DECIMAL(5,2),
    [Fecha Alta Titular]        DATE NOT NULL,
    [Fecha Baja Titular]        DATE,
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_TitularidadCuenta_Staging_Cuenta ([Numero Cuenta]),
    INDEX IX_TitularidadCuenta_Staging_Cliente ([Cliente ID])
);
GO
PRINT 'FIN DOMINIO 3: Cuenta Staging (4 tablas) ';
GO

-- DOMINIO 4: CREDITO - STAGING
IF OBJECT_ID('Integration.Credito_Staging','U') IS NOT NULL DROP TABLE Integration.Credito_Staging;
GO
CREATE TABLE Integration.Credito_Staging (
    [Credito Staging Key]           INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Credito ID]                INT NOT NULL,
    [Numero Contrato]               NVARCHAR(50) NOT NULL,
    [Tipo Credito]                  NVARCHAR(100) NOT NULL,
    [Cliente ID]                    INT NOT NULL,
    [Nombre Cliente]                NVARCHAR(300),
    [Producto]                      NVARCHAR(200) NOT NULL,
    [Importe Concedido]             DECIMAL(18,2) NOT NULL,
    [Importe Pendiente]             DECIMAL(18,2) NOT NULL,
    [TIN Aplicado]                  DECIMAL(5,3) NOT NULL,
    [TAE Aplicado]                  DECIMAL(5,3) NOT NULL,
    [Tipo Interes]                  NVARCHAR(50),
    [Plazo Meses]                   INT NOT NULL,
    [Importe Cuota]                 DECIMAL(18,2) NOT NULL,
    [Fecha Formalizacion]           DATE NOT NULL,
    [Fecha Primer Vencimiento]      DATE NOT NULL,
    [Fecha Ultimo Vencimiento]      DATE NOT NULL,
    [Fecha Liquidacion]             DATE,
    [Estado Prestamo]               NVARCHAR(50) NOT NULL,
    [Valor Tasacion Garantia]       DECIMAL(18,2),
    [LTV Porcentaje]                DECIMAL(5,2),
    [Tiene Seguro Vida]             BIT NOT NULL DEFAULT 0,
    [Sucursal Gestion]              NVARCHAR(200),
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_Credito_Staging_WWI_ID ([WWI Credito ID]),
    INDEX IX_Credito_Staging_Cliente ([Cliente ID]),
    INDEX IX_Credito_Staging_Contrato ([Numero Contrato])
);
GO

IF OBJECT_ID('Integration.Cuota_Staging','U') IS NOT NULL DROP TABLE Integration.Cuota_Staging;
GO
CREATE TABLE Integration.Cuota_Staging (
    [Cuota Staging Key]     INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cuota ID]          INT NOT NULL,
    [Numero Contrato]       NVARCHAR(50) NOT NULL,
    [Numero Cuota]          INT NOT NULL,
    [Fecha Vencimiento]     DATE NOT NULL,
    [Importe Cuota]         DECIMAL(18,2) NOT NULL,
    [Importe Capital]       DECIMAL(18,2) NOT NULL,
    [Importe Intereses]     DECIMAL(18,2) NOT NULL,
    [Importe Comisiones]    DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Capital Pendiente]     DECIMAL(18,2) NOT NULL,
    [Fecha Pago]            DATE,
    [Importe Pagado]        DECIMAL(18,2),
    [Estado Cuota]          NVARCHAR(50) NOT NULL,
    [Dias Retraso]          INT NOT NULL DEFAULT 0,
    [Valid From]            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]           INT NOT NULL DEFAULT 1,
    INDEX IX_Cuota_Staging_Contrato_Cuota ([Numero Contrato],[Numero Cuota])
);
GO

IF OBJECT_ID('Integration.Amortizacion_Staging','U') IS NOT NULL DROP TABLE Integration.Amortizacion_Staging;
GO
CREATE TABLE Integration.Amortizacion_Staging (
    [Amortizacion Staging Key]      INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Amortizacion ID]           INT NOT NULL,
    [Numero Contrato]               NVARCHAR(50) NOT NULL,
    [Fecha Amortizacion]            DATE NOT NULL,
    [Tipo Amortizacion]             NVARCHAR(50) NOT NULL,
    [Importe Amortizado]            DECIMAL(18,2) NOT NULL,
    [Capital Amortizado]            DECIMAL(18,2) NOT NULL,
    [Intereses Amortizados]         DECIMAL(18,2) NOT NULL,
    [Comision Amortizacion]         DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Capital Pendiente Despues]     DECIMAL(18,2) NOT NULL,
    [Medio Pago]                    NVARCHAR(100),
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_Amortizacion_Staging_Contrato_Fecha ([Numero Contrato],[Fecha Amortizacion])
);
GO

IF OBJECT_ID('Integration.Garantia_Staging','U') IS NOT NULL DROP TABLE Integration.Garantia_Staging;
GO
CREATE TABLE Integration.Garantia_Staging (
    [Garantia Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Garantia ID]       INT NOT NULL,
    [Numero Contrato]       NVARCHAR(50) NOT NULL,
    [Tipo Garantia]         NVARCHAR(100) NOT NULL,
    [Descripcion Garantia]  NVARCHAR(1000),
    [Valor Tasacion]        DECIMAL(18,2),
    [Fecha Tasacion]        DATE,
    [Entidad Tasadora]      NVARCHAR(200),
    [Direccion Garantia]    NVARCHAR(500),
    [Tiene Seguro]          BIT NOT NULL DEFAULT 0,
    [Fecha Constitucion]    DATE NOT NULL,
    [Fecha Liberacion]      DATE,
    [Estado Garantia]       NVARCHAR(50) NOT NULL,
    [Valid From]            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]           INT NOT NULL DEFAULT 1,
    INDEX IX_Garantia_Staging_Contrato ([Numero Contrato])
);
GO

IF OBJECT_ID('Integration.Aval_Staging','U') IS NOT NULL DROP TABLE Integration.Aval_Staging;
GO
CREATE TABLE Integration.Aval_Staging (
    [Aval Staging Key]          INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Aval ID]               INT NOT NULL,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Numero Aval]               NVARCHAR(50) NOT NULL,
    [Cliente Avalista ID]       INT NOT NULL,
    [Nombre Avalista]           NVARCHAR(300),
    [Tipo Aval]                 NVARCHAR(100) NOT NULL,
    [Importe Avalado]           DECIMAL(18,2) NOT NULL,
    [Porcentaje Cobertura]      DECIMAL(5,2) NOT NULL,
    [Fecha Constitucion]        DATE NOT NULL,
    [Fecha Vencimiento]         DATE,
    [Estado Aval]               NVARCHAR(50) NOT NULL,
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_Aval_Staging_Contrato ([Numero Contrato]),
    INDEX IX_Aval_Staging_Avalista ([Cliente Avalista ID])
);
GO

IF OBJECT_ID('Integration.PosicionCredito_Staging','U') IS NOT NULL DROP TABLE Integration.PosicionCredito_Staging;
GO
CREATE TABLE Integration.PosicionCredito_Staging (
    [Posicion Credito Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [Numero Contrato]               NVARCHAR(50) NOT NULL,
    [Fecha Posicion]                DATE NOT NULL,
    [Importe Pendiente]             DECIMAL(18,2) NOT NULL,
    [Capital Pendiente]             DECIMAL(18,2) NOT NULL,
    [Intereses Devengados]          DECIMAL(18,2) NOT NULL,
    [Cuotas Pendientes]             INT NOT NULL,
    [Cuotas Impagadas]              INT NOT NULL DEFAULT 0,
    [Dias Retraso Maximo]           INT NOT NULL DEFAULT 0,
    [Provision Dotada]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_PosicionCredito_Staging_Contrato_Fecha ([Numero Contrato],[Fecha Posicion])
);
GO
PRINT 'FIN DOMINIO 4: Credito Staging (6 tablas)';
GO

-- DOMINIO 5: TRANSFERENCIA - STAGING
IF OBJECT_ID('Integration.Transferencia_Staging','U') IS NOT NULL DROP TABLE Integration.Transferencia_Staging;
GO
CREATE TABLE Integration.Transferencia_Staging (
    [Transferencia Staging Key]     INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Transferencia ID]          INT NOT NULL,
    [Numero Operacion]              NVARCHAR(50) NOT NULL,
    [Tipo Transferencia]            NVARCHAR(100) NOT NULL,
    [Cuenta Origen]                 NVARCHAR(24) NOT NULL,
    [Cuenta Destino]                NVARCHAR(34) NOT NULL,
    [Nombre Beneficiario]           NVARCHAR(200),
    [Entidad Destino]               NVARCHAR(200),
    [Pais Destino]                  NVARCHAR(100),
    [Importe Transferencia]         DECIMAL(18,2) NOT NULL,
    [Concepto]                      NVARCHAR(500),
    [Fecha Operacion]               DATE NOT NULL,
    [Fecha Valor]                   DATE NOT NULL,
    [Comision Aplicada]             DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Estado Transferencia]          NVARCHAR(50) NOT NULL,
    [Canal Operacion]               NVARCHAR(50),
    [Es Pago Recurrente]            BIT NOT NULL DEFAULT 0,
    [Es SEPA]                       BIT NOT NULL DEFAULT 0,
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_Transferencia_Staging_Origen_Fecha ([Cuenta Origen],[Fecha Operacion])
);
GO

IF OBJECT_ID('Integration.TransferenciaAgregada_Staging','U') IS NOT NULL DROP TABLE Integration.TransferenciaAgregada_Staging;
GO
CREATE TABLE Integration.TransferenciaAgregada_Staging (
    [Transferencia Agregada Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [Cuenta Origen]                         NVARCHAR(24) NOT NULL,
    [Fecha Operacion]                       DATE NOT NULL,
    [Tipo Transferencia]                    NVARCHAR(100) NOT NULL,
    [Numero Transferencias]                 INT NOT NULL DEFAULT 0,
    [Importe Total Transferido]             DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Importe Total Comisiones]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Importe Promedio]                      DECIMAL(18,2),
    [Valid From]                            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                           INT NOT NULL DEFAULT 1,
    INDEX IX_TransferenciaAgregada_Staging_Cuenta_Fecha ([Cuenta Origen],[Fecha Operacion])
);
GO

IF OBJECT_ID('Integration.ComisionTransferencia_Staging','U') IS NOT NULL DROP TABLE Integration.ComisionTransferencia_Staging;
GO
CREATE TABLE Integration.ComisionTransferencia_Staging (
    [Comision Transferencia Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [Numero Operacion]                      NVARCHAR(50) NOT NULL,
    [Tipo Comision]                         NVARCHAR(100) NOT NULL,
    [Fecha Cargo]                           DATE NOT NULL,
    [Importe Comision]                      DECIMAL(18,2) NOT NULL,
    [Base Calculo]                          DECIMAL(18,2),
    [Porcentaje Aplicado]                   DECIMAL(5,3),
    [Valid From]                            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                           INT NOT NULL DEFAULT 1,
    INDEX IX_ComisionTransferencia_Staging_Operacion ([Numero Operacion])
);
GO
PRINT ' FIN DOMINIO 5: Transferencia Staging (3 tablas) ';
GO

-- DOMINIO 6: RIESGO - STAGING
IF OBJECT_ID('Integration.CIRBE_Staging','U') IS NOT NULL DROP TABLE Integration.CIRBE_Staging;
GO
CREATE TABLE Integration.CIRBE_Staging (
    [CIRBE Staging Key]         INT IDENTITY(1,1) PRIMARY KEY,
    [WWI CIRBE ID]              INT NOT NULL,
    [Cliente ID]                INT NOT NULL,
    [Nombre Cliente]            NVARCHAR(300),
    [Periodo Declaracion]       NVARCHAR(7) NOT NULL,
    [Fecha Declaracion]         DATE NOT NULL,
    [Entidad Financiera]        NVARCHAR(200),
    [Tipo Operacion]            NVARCHAR(100),
    [Naturaleza Operacion]      NVARCHAR(100),
    [Importe Operacion]         DECIMAL(18,2) NOT NULL,
    [Saldo Vivo]                DECIMAL(18,2) NOT NULL,
    [Tipo Garantia]             NVARCHAR(100),
    [Es Operacion Dudosa]       BIT NOT NULL DEFAULT 0,
    [Clasificacion Riesgo]      NVARCHAR(100),
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_CIRBE_Staging_Cliente_Periodo ([Cliente ID],[Periodo Declaracion])
);
GO

IF OBJECT_ID('Integration.Provision_Staging','U') IS NOT NULL DROP TABLE Integration.Provision_Staging;
GO
CREATE TABLE Integration.Provision_Staging (
    [Provision Staging Key]     INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Provision ID]          INT NOT NULL,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Fecha Provision]           DATE NOT NULL,
    [Tipo Provision]            NVARCHAR(100) NOT NULL,
    [Importe Provisionado]      DECIMAL(18,2) NOT NULL,
    [Importe Recuperado]        DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Saldo Provision]           DECIMAL(18,2) NOT NULL,
    [Clasificacion Riesgo]      NVARCHAR(100),
    [Porcentaje Provision]      DECIMAL(5,2),
    [Valid From]                DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                  DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]               INT NOT NULL DEFAULT 1,
    INDEX IX_Provision_Staging_Contrato_Fecha ([Numero Contrato],[Fecha Provision])
);
GO

IF OBJECT_ID('Integration.ClasificacionRiesgo_Staging','U') IS NOT NULL DROP TABLE Integration.ClasificacionRiesgo_Staging;
GO
CREATE TABLE Integration.ClasificacionRiesgo_Staging (
    [Clasificacion Riesgo Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Clasificacion ID]              INT NOT NULL,
    [Codigo Clasificacion]              NVARCHAR(20) NOT NULL,
    [Nombre Clasificacion]              NVARCHAR(100) NOT NULL,
    [Descripcion]                       NVARCHAR(500),
    [Nivel Riesgo]                      TINYINT,
    [Porcentaje Provision]              DECIMAL(5,2),
    [Es Vigente]                        BIT NOT NULL DEFAULT 1,
    [Valid From]                        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                          DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                       INT NOT NULL DEFAULT 1,
    INDEX IX_ClasificacionRiesgo_Staging_Codigo ([Codigo Clasificacion])
);
GO

IF OBJECT_ID('Integration.RiesgoConsolidado_Staging','U') IS NOT NULL DROP TABLE Integration.RiesgoConsolidado_Staging;
GO
CREATE TABLE Integration.RiesgoConsolidado_Staging (
    [Riesgo Consolidado Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [Cliente ID]                        INT NOT NULL,
    [Fecha Consolidacion]               DATE NOT NULL,
    [Riesgo Directo Total]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Riesgo Indirecto Total]            DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Riesgo Total]                      DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Riesgo Dudoso Total]               DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Numero Operaciones]                INT NOT NULL DEFAULT 0,
    [Provision Total]                   DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Clasificacion Riesgo]              NVARCHAR(100),
    [Valid From]                        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                          DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                       INT NOT NULL DEFAULT 1,
    INDEX IX_RiesgoConsolidado_Staging_Cliente_Fecha ([Cliente ID],[Fecha Consolidacion])
);
GO

IF OBJECT_ID('Integration.ExposicionTotal_Staging','U') IS NOT NULL DROP TABLE Integration.ExposicionTotal_Staging;
GO
CREATE TABLE Integration.ExposicionTotal_Staging (
    [Exposicion Total Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [Cliente ID]                    INT NOT NULL,
    [Fecha Calculo]                 DATE NOT NULL,
    [Exposicion Creditos]           DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Exposicion Cuentas]            DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Exposicion Avales]             DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Exposicion Total]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Limite Riesgo]                 DECIMAL(18,2),
    [Porcentaje Utilizacion]        DECIMAL(5,2),
    [Valid From]                    DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                      DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                   INT NOT NULL DEFAULT 1,
    INDEX IX_ExposicionTotal_Staging_Cliente_Fecha ([Cliente ID],[Fecha Calculo])
);
GO

IF OBJECT_ID('Integration.EntidadFinanciera_Staging','U') IS NOT NULL DROP TABLE Integration.EntidadFinanciera_Staging;
GO
CREATE TABLE Integration.EntidadFinanciera_Staging (
    [Entidad Financiera Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Entidad ID]                    INT NOT NULL,
    [Codigo Entidad]                    NVARCHAR(20) NOT NULL,
    [Nombre Entidad]                    NVARCHAR(200) NOT NULL,
    [NIF]                               NVARCHAR(20),
    [Tipo Entidad]                      NVARCHAR(100),
    [Pais]                              NVARCHAR(100),
    [Es Vigente]                        BIT NOT NULL DEFAULT 1,
    [Valid From]                        DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                          DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                       INT NOT NULL DEFAULT 1,
    INDEX IX_EntidadFinanciera_Staging_Codigo ([Codigo Entidad])
);
GO
PRINT ' FIN DOMINIO 6: Riesgo Staging (6 tablas)';
GO

-- DOMINIO 7: ORGANIZACION - STAGING
IF OBJECT_ID('Integration.Centro_Staging','U') IS NOT NULL DROP TABLE Integration.Centro_Staging;
GO
CREATE TABLE Integration.Centro_Staging (
    [Centro Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Centro ID]         INT NOT NULL,
    [Codigo Centro]         NVARCHAR(20) NOT NULL,
    [Nombre Centro]         NVARCHAR(200) NOT NULL,
    [Tipo Centro]           NVARCHAR(50) NOT NULL CHECK ([Tipo Centro] IN ('Sucursal','Cajero Automático','Centro Corporativo')),
    [Direccion Completa]    NVARCHAR(500),
    [Codigo Postal]         NVARCHAR(5),
    [Localidad]             NVARCHAR(100),
    [Provincia]             NVARCHAR(100),
    [Zona Geografica]       NVARCHAR(100),
    [Telefono]              NVARCHAR(20),
    [Email]                 NVARCHAR(255),
    [Director Centro]       NVARCHAR(300),
    [Numero Empleados]      INT NOT NULL DEFAULT 0,
    [Fecha Apertura]        DATE NOT NULL,
    [Fecha Cierre]          DATE,
    [Estado Centro]         NVARCHAR(50) NOT NULL,
    [Centro Padre]          NVARCHAR(200),
    [Valid From]            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]           INT NOT NULL DEFAULT 1,
    INDEX IX_Centro_Staging_WWI_ID ([WWI Centro ID]),
    INDEX IX_Centro_Staging_Codigo ([Codigo Centro])
);
GO

IF OBJECT_ID('Integration.Empleado_Staging','U') IS NOT NULL DROP TABLE Integration.Empleado_Staging;
GO
CREATE TABLE Integration.Empleado_Staging (
    [Empleado Staging Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Empleado ID]       INT NOT NULL,
    [Numero Empleado]       NVARCHAR(20) NOT NULL,
    [Nombre Completo]       NVARCHAR(300) NOT NULL,
    [Email]                 NVARCHAR(255),
    [Telefono]              NVARCHAR(20),
    [Departamento]          NVARCHAR(100) NOT NULL,
    [Centro Asignado]       NVARCHAR(200),
    [Puesto]                NVARCHAR(200) NOT NULL,
    [Categoria]             NVARCHAR(100),
    [Supervisor]            NVARCHAR(300),
    [Fecha Alta]            DATE NOT NULL,
    [Fecha Baja]            DATE,
    [Estado Empleado]       NVARCHAR(50) NOT NULL,
    [Valid From]            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]           INT NOT NULL DEFAULT 1,
    INDEX IX_Empleado_Staging_WWI_ID ([WWI Empleado ID]),
    INDEX IX_Empleado_Staging_NumeroEmpleado ([Numero Empleado])
);
GO

IF OBJECT_ID('Integration.JerarquiaOrganizativa_Staging','U') IS NOT NULL DROP TABLE Integration.JerarquiaOrganizativa_Staging;
GO
CREATE TABLE Integration.JerarquiaOrganizativa_Staging (
    [Jerarquia Organizativa Staging Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [Centro ID]                             INT NOT NULL,
    [Centro Padre ID]                       INT,
    [Codigo Centro]                         NVARCHAR(20) NOT NULL,
    [Nombre Centro]                         NVARCHAR(200) NOT NULL,
    [Nivel Jerarquia]                       TINYINT NOT NULL DEFAULT 1,
    [Ruta Jerarquia]                        NVARCHAR(500),
    [Fecha Vigencia Desde]                  DATE NOT NULL,
    [Fecha Vigencia Hasta]                  DATE,
    [Valid From]                            DATETIME2(7) NOT NULL DEFAULT SYSDATETIME(),
    [Valid To]                              DATETIME2(7) NOT NULL DEFAULT '9999-12-31 23:59:59.9999999',
    [Lineage Key]                           INT NOT NULL DEFAULT 1,
    INDEX IX_JerarquiaOrganizativa_Staging_Centro ([Centro ID])
);
GO
PRINT ' FIN DOMINIO 7: Organizacion Staging (3 tablas)';
GO

PRINT '';

PRINT 'RESUMEN SILVER: 31 tablas staging bancarias creadas en Integration';


GO

-- GOLD - Dimension + Fact (sin cambios)

USE WideWorldImportersDW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Dimension') EXEC('CREATE SCHEMA Dimension');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Fact')      EXEC('CREATE SCHEMA Fact');
GO

-- DIMENSIONES
IF OBJECT_ID('Dimension.Cliente','U') IS NOT NULL DROP TABLE [Dimension].[Cliente];
GO
CREATE TABLE [Dimension].[Cliente] (
    [Cliente Key]                       INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                    INT NOT NULL,
    [Tipo Cliente]                      NVARCHAR(50) NOT NULL,
    [Numero Documento]                  NVARCHAR(20) NOT NULL,
    [Nombre Completo]                   NVARCHAR(300) NOT NULL,
    [Fecha Nacimiento Constitucion]     DATE,
    [Edad]                              INT,
    [Sexo]                              NVARCHAR(20),
    [Nacionalidad]                      NVARCHAR(100),
    [Forma Juridica]                    NVARCHAR(100),
    [CNAE]                              NVARCHAR(10),
    [Email]                             NVARCHAR(255),
    [Telefono Movil]                    NVARCHAR(20),
    [Direccion Completa]                NVARCHAR(500),
    [Codigo Postal]                     NVARCHAR(5),
    [Localidad]                         NVARCHAR(100),
    [Provincia]                         NVARCHAR(100),
    [Pais]                              NVARCHAR(100) NOT NULL DEFAULT 'España',
    [Segmento]                          NVARCHAR(100),
    [Subsegmento]                       NVARCHAR(100),
    [Potencial Negocio]                 NVARCHAR(50),
    [Es Cliente Activo]                 BIT NOT NULL DEFAULT 1,
    [Fecha Alta]                        DATE NOT NULL,
    [Fecha Baja]                        DATE,
    [Valid From]                        DATETIME2(7) NOT NULL,
    [Valid To]                          DATETIME2(7) NOT NULL,
    [Lineage Key]                       INT NOT NULL,
    INDEX IX_Cliente_WWI_ID ([WWI Cliente ID]),
    INDEX IX_Cliente_ValidFrom ([Valid From]),
    INDEX IX_Cliente_Activo ([Es Cliente Activo])
);
GO

IF OBJECT_ID('Dimension.PerfilRiesgo','U') IS NOT NULL DROP TABLE [Dimension].[PerfilRiesgo];
GO
CREATE TABLE [Dimension].[PerfilRiesgo] (
    [Perfil Riesgo Key]             INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cliente ID]                INT NOT NULL,
    [Score Credito]                 INT,
    [Nivel Riesgo]                  NVARCHAR(50),
    [Probabilidad Impago]           DECIMAL(5,2),
    [Limite Endeudamiento]          DECIMAL(18,2),
    [Modelo Scoring]                NVARCHAR(100),
    [Numero Transacciones Mes]      INT,
    [Volumen Mensual Operaciones]   DECIMAL(18,2),
    [Tiene Operativa Inusual]       BIT NOT NULL DEFAULT 0,
    [Valid From]                    DATETIME2(7) NOT NULL,
    [Valid To]                      DATETIME2(7) NOT NULL,
    [Lineage Key]                   INT NOT NULL,
    INDEX IX_PerfilRiesgo_Cliente ([WWI Cliente ID]),
    INDEX IX_PerfilRiesgo_NivelRiesgo ([Nivel Riesgo])
);
GO

IF OBJECT_ID('Dimension.Producto','U') IS NOT NULL DROP TABLE [Dimension].[Producto];
GO
CREATE TABLE [Dimension].[Producto] (
    [Producto Key]          INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Producto ID]       INT NOT NULL,
    [Codigo Producto]       NVARCHAR(50) NOT NULL,
    [Nombre Producto]       NVARCHAR(200) NOT NULL,
    [Descripcion]           NVARCHAR(1000),
    [Tipo Producto]         NVARCHAR(100) NOT NULL,
    [Categoria Producto]    NVARCHAR(100) NOT NULL,
    [TAE]                   DECIMAL(5,3),
    [TIN]                   DECIMAL(5,3),
    [Comision]              DECIMAL(18,2),
    [Requiere Garantia]     BIT NOT NULL DEFAULT 0,
    [Es Comercializable]    BIT NOT NULL DEFAULT 1,
    [Fecha Lanzamiento]     DATE NOT NULL,
    [Fecha Retiro]          DATE,
    [Valid From]            DATETIME2(7) NOT NULL,
    [Valid To]              DATETIME2(7) NOT NULL,
    [Lineage Key]           INT NOT NULL,
    INDEX IX_Producto_WWI_ID ([WWI Producto ID]),
    INDEX IX_Producto_Tipo ([Tipo Producto]),
    INDEX IX_Producto_Comercializable ([Es Comercializable])
);
GO

IF OBJECT_ID('Dimension.TipoComision','U') IS NOT NULL DROP TABLE [Dimension].[TipoComision];
GO
CREATE TABLE [Dimension].[TipoComision] (
    [Tipo Comision Key]     INT IDENTITY(1,1) PRIMARY KEY,
    [Codigo Tipo Comision]  NVARCHAR(50)  NOT NULL UNIQUE,
    [Nombre Tipo Comision]  NVARCHAR(100) NOT NULL,
    [Descripcion]           NVARCHAR(500),
    [Base Calculo]          NVARCHAR(200),
    [Periodicidad]          NVARCHAR(50),
    [Lineage Key]           INT NOT NULL
);
GO

IF OBJECT_ID('Dimension.Cuenta','U') IS NOT NULL DROP TABLE [Dimension].[Cuenta];
GO
CREATE TABLE [Dimension].[Cuenta] (
    [Cuenta Key]                    INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Cuenta ID]                 INT NOT NULL,
    [Numero Cuenta]                 NVARCHAR(24) NOT NULL,
    [Tipo Cuenta]                   NVARCHAR(100) NOT NULL,
    [Producto]                      NVARCHAR(200) NOT NULL,
    [Cliente Key]                   INT,
    [Nombre Cliente]                NVARCHAR(300),
    [Fecha Apertura]                DATE NOT NULL,
    [Fecha Cierre]                  DATE,
    [Tiene Nomina Domiciliada]      BIT NOT NULL DEFAULT 0,
    [TAE Aplicado]                  DECIMAL(5,3),
    [Estado Cuenta]                 NVARCHAR(50) NOT NULL,
    [Sucursal Gestion]              NVARCHAR(200),
    [Valid From]                    DATETIME2(7) NOT NULL,
    [Valid To]                      DATETIME2(7) NOT NULL,
    [Lineage Key]                   INT NOT NULL,
    INDEX IX_Cuenta_WWI_ID ([WWI Cuenta ID]),
    INDEX IX_Cuenta_NumeroCuenta ([Numero Cuenta]),
    INDEX IX_Cuenta_Estado ([Estado Cuenta])
);
GO

IF OBJECT_ID('Dimension.Garantia','U') IS NOT NULL DROP TABLE [Dimension].[Garantia];
GO
CREATE TABLE [Dimension].[Garantia] (
    [Garantia Key]          INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Garantia ID]       INT NOT NULL,
    [Tipo Garantia]         NVARCHAR(100) NOT NULL,
    [Descripcion Garantia]  NVARCHAR(1000),
    [Valor Tasacion]        DECIMAL(18,2),
    [Fecha Tasacion]        DATE,
    [Entidad Tasadora]      NVARCHAR(200),
    [Tiene Seguro]          BIT NOT NULL DEFAULT 0,
    [Estado Garantia]       NVARCHAR(50) NOT NULL,
    [Valid From]            DATETIME2(7) NOT NULL,
    [Valid To]              DATETIME2(7) NOT NULL,
    [Lineage Key]           INT NOT NULL,
    INDEX IX_Garantia_WWI_ID ([WWI Garantia ID]),
    INDEX IX_Garantia_Tipo ([Tipo Garantia])
);
GO

IF OBJECT_ID('Dimension.ClasificacionRiesgo','U') IS NOT NULL DROP TABLE [Dimension].[ClasificacionRiesgo];
GO
CREATE TABLE [Dimension].[ClasificacionRiesgo] (
    [Clasificacion Riesgo Key]  INT IDENTITY(1,1) PRIMARY KEY,
    [Codigo Clasificacion]      NVARCHAR(20)  NOT NULL UNIQUE,
    [Nombre Clasificacion]      NVARCHAR(100) NOT NULL,
    [Descripcion]               NVARCHAR(500),
    [Nivel Riesgo]              TINYINT,
    [Porcentaje Provision]      DECIMAL(5,2),
    [Es Vigente]                BIT NOT NULL DEFAULT 1,
    [Lineage Key]               INT NOT NULL
);
GO

IF OBJECT_ID('Dimension.EntidadFinanciera','U') IS NOT NULL DROP TABLE [Dimension].[EntidadFinanciera];
GO
CREATE TABLE [Dimension].[EntidadFinanciera] (
    [Entidad Financiera Key]    INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Entidad ID]            INT NOT NULL,
    [Codigo Entidad]            NVARCHAR(20)  NOT NULL,
    [Nombre Entidad]            NVARCHAR(200) NOT NULL,
    [NIF]                       NVARCHAR(20),
    [Tipo Entidad]              NVARCHAR(100),
    [Pais]                      NVARCHAR(100),
    [Es Vigente]                BIT NOT NULL DEFAULT 1,
    [Valid From]                DATETIME2(7) NOT NULL,
    [Valid To]                  DATETIME2(7) NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_EntidadFinanciera_Codigo ([Codigo Entidad])
);
GO

IF OBJECT_ID('Dimension.Centro','U') IS NOT NULL DROP TABLE [Dimension].[Centro];
GO
CREATE TABLE [Dimension].[Centro] (
    [Centro Key]            INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Centro ID]         INT NOT NULL,
    [Codigo Centro]         NVARCHAR(20)  NOT NULL,
    [Nombre Centro]         NVARCHAR(200) NOT NULL,
    [Tipo Centro]           NVARCHAR(50)  NOT NULL,
    [Direccion Completa]    NVARCHAR(500),
    [Codigo Postal]         NVARCHAR(5),
    [Localidad]             NVARCHAR(100),
    [Provincia]             NVARCHAR(100),
    [Zona Geografica]       NVARCHAR(100),
    [Numero Empleados]      INT NOT NULL DEFAULT 0,
    [Fecha Apertura]        DATE NOT NULL,
    [Fecha Cierre]          DATE,
    [Estado Centro]         NVARCHAR(50) NOT NULL,
    [Centro Padre Key]      INT,
    [Valid From]            DATETIME2(7) NOT NULL,
    [Valid To]              DATETIME2(7) NOT NULL,
    [Lineage Key]           INT NOT NULL,
    INDEX IX_Centro_WWI_ID ([WWI Centro ID]),
    INDEX IX_Centro_Codigo ([Codigo Centro]),
    INDEX IX_Centro_Tipo ([Tipo Centro])
);
GO

IF OBJECT_ID('Dimension.Empleado','U') IS NOT NULL DROP TABLE [Dimension].[Empleado];
GO
CREATE TABLE [Dimension].[Empleado] (
    [Empleado Key]      INT IDENTITY(1,1) PRIMARY KEY,
    [WWI Empleado ID]   INT NOT NULL,
    [Numero Empleado]   NVARCHAR(20)  NOT NULL,
    [Nombre Completo]   NVARCHAR(300) NOT NULL,
    [Email]             NVARCHAR(255),
    [Departamento]      NVARCHAR(100) NOT NULL,
    [Centro Asignado]   NVARCHAR(200),
    [Puesto]            NVARCHAR(200) NOT NULL,
    [Categoria]         NVARCHAR(100),
    [Supervisor]        NVARCHAR(300),
    [Fecha Alta]        DATE NOT NULL,
    [Fecha Baja]        DATE,
    [Estado Empleado]   NVARCHAR(50) NOT NULL,
    [Valid From]        DATETIME2(7) NOT NULL,
    [Valid To]          DATETIME2(7) NOT NULL,
    [Lineage Key]       INT NOT NULL,
    INDEX IX_Empleado_WWI_ID ([WWI Empleado ID]),
    INDEX IX_Empleado_NumeroEmpleado ([Numero Empleado]),
    INDEX IX_Empleado_Departamento ([Departamento])
);
GO
PRINT ' Dimensiones (10 tablas)';
GO

-- HECHOS
IF OBJECT_ID('Fact.Movimiento','U') IS NOT NULL DROP TABLE [Fact].[Movimiento];
GO
CREATE TABLE [Fact].[Movimiento] (
    [Movimiento Key]            BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Movimiento Key]      INT NOT NULL,
    [Fecha Valor Key]           INT NOT NULL,
    [Cuenta Key]                INT NOT NULL,
    [Cliente Key]               INT,
    [Tipo Movimiento]           NVARCHAR(100) NOT NULL,
    [Concepto]                  NVARCHAR(500),
    [Importe Movimiento]        DECIMAL(18,2) NOT NULL,
    [Saldo Despues Movimiento]  DECIMAL(18,2) NOT NULL,
    [Canal Operacion]           NVARCHAR(50),
    [Centro Key]                INT,
    [WWI Movimiento ID]         INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_Movimiento_Fecha ([Fecha Movimiento Key]),
    INDEX IX_Movimiento_Cuenta ([Cuenta Key]),
    INDEX IX_Movimiento_Cliente ([Cliente Key])
);
GO

IF OBJECT_ID('Fact.SaldoCuenta','U') IS NOT NULL DROP TABLE [Fact].[SaldoCuenta];
GO
CREATE TABLE [Fact].[SaldoCuenta] (
    [Saldo Cuenta Key]          BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Key]                 INT NOT NULL,
    [Cuenta Key]                INT NOT NULL,
    [Cliente Key]               INT,
    [Producto Key]              INT,
    [Saldo Apertura]            DECIMAL(18,2) NOT NULL,
    [Saldo Cierre]              DECIMAL(18,2) NOT NULL,
    [Saldo Promedio]            DECIMAL(18,2) NOT NULL,
    [Numero Movimientos]        INT NOT NULL DEFAULT 0,
    [Importe Total Entradas]    DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Importe Total Salidas]     DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_SaldoCuenta_Fecha ([Fecha Key]),
    INDEX IX_SaldoCuenta_Cuenta ([Cuenta Key]),
    INDEX IX_SaldoCuenta_Cliente ([Cliente Key])
);
GO

IF OBJECT_ID('Fact.Credito','U') IS NOT NULL DROP TABLE [Fact].[Credito];
GO
CREATE TABLE [Fact].[Credito] (
    [Credito Key]               BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Formalizacion Key]   INT NOT NULL,
    [Fecha Snapshot Key]        INT NOT NULL,
    [Cliente Key]               INT NOT NULL,
    [Producto Key]              INT NOT NULL,
    [Garantia Key]              INT,
    [Centro Key]                INT,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Tipo Credito]              NVARCHAR(100) NOT NULL,
    [Importe Concedido]         DECIMAL(18,2) NOT NULL,
    [Importe Pendiente]         DECIMAL(18,2) NOT NULL,
    [Capital Pendiente]         DECIMAL(18,2) NOT NULL,
    [Intereses Devengados]      DECIMAL(18,2) NOT NULL DEFAULT 0,
    [TIN Aplicado]              DECIMAL(5,3) NOT NULL,
    [TAE Aplicado]              DECIMAL(5,3) NOT NULL,
    [Plazo Meses]               INT NOT NULL,
    [Cuotas Pendientes]         INT NOT NULL,
    [Cuotas Impagadas]          INT NOT NULL DEFAULT 0,
    [Dias Retraso Maximo]       INT NOT NULL DEFAULT 0,
    [Provision Dotada]          DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Estado Prestamo]           NVARCHAR(50) NOT NULL,
    [WWI Credito ID]            INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_Credito_FechaFormalizacion ([Fecha Formalizacion Key]),
    INDEX IX_Credito_FechaSnapshot ([Fecha Snapshot Key]),
    INDEX IX_Credito_Cliente ([Cliente Key]),
    INDEX IX_Credito_Contrato ([Numero Contrato]),
    INDEX IX_Credito_Estado ([Estado Prestamo])
);
GO

IF OBJECT_ID('Fact.CuotaPrestamo','U') IS NOT NULL DROP TABLE [Fact].[CuotaPrestamo];
GO
CREATE TABLE [Fact].[CuotaPrestamo] (
    [Cuota Prestamo Key]        BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Vencimiento Key]     INT NOT NULL,
    [Fecha Pago Key]            INT,
    [Cliente Key]               INT NOT NULL,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Numero Cuota]              INT NOT NULL,
    [Importe Cuota]             DECIMAL(18,2) NOT NULL,
    [Importe Capital]           DECIMAL(18,2) NOT NULL,
    [Importe Intereses]         DECIMAL(18,2) NOT NULL,
    [Importe Comisiones]        DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Capital Pendiente]         DECIMAL(18,2) NOT NULL,
    [Importe Pagado]            DECIMAL(18,2),
    [Estado Cuota]              NVARCHAR(50) NOT NULL,
    [Dias Retraso]              INT NOT NULL DEFAULT 0,
    [WWI Cuota ID]              INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_CuotaPrestamo_FechaVencimiento ([Fecha Vencimiento Key]),
    INDEX IX_CuotaPrestamo_Cliente ([Cliente Key]),
    INDEX IX_CuotaPrestamo_Contrato ([Numero Contrato]),
    INDEX IX_CuotaPrestamo_Estado ([Estado Cuota])
);
GO

IF OBJECT_ID('Fact.Aval','U') IS NOT NULL DROP TABLE [Fact].[Aval];
GO
CREATE TABLE [Fact].[Aval] (
    [Aval Key]                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Constitucion Key]    INT NOT NULL,
    [Fecha Vencimiento Key]     INT,
    [Cliente Titular Key]       INT NOT NULL,
    [Cliente Avalista Key]      INT NOT NULL,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Numero Aval]               NVARCHAR(50) NOT NULL,
    [Tipo Aval]                 NVARCHAR(100) NOT NULL,
    [Importe Avalado]           DECIMAL(18,2) NOT NULL,
    [Porcentaje Cobertura]      DECIMAL(5,2) NOT NULL,
    [Estado Aval]               NVARCHAR(50) NOT NULL,
    [WWI Aval ID]               INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_Aval_FechaConstitucion ([Fecha Constitucion Key]),
    INDEX IX_Aval_ClienteTitular ([Cliente Titular Key]),
    INDEX IX_Aval_ClienteAvalista ([Cliente Avalista Key]),
    INDEX IX_Aval_Contrato ([Numero Contrato])
);
GO

IF OBJECT_ID('Fact.Transferencia','U') IS NOT NULL DROP TABLE [Fact].[Transferencia];
GO
CREATE TABLE [Fact].[Transferencia] (
    [Transferencia Key]         BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Operacion Key]       INT NOT NULL,
    [Fecha Valor Key]           INT NOT NULL,
    [Cuenta Origen Key]         INT NOT NULL,
    [Cliente Key]               INT NOT NULL,
    [Tipo Transferencia]        NVARCHAR(100) NOT NULL,
    [Numero Operacion]          NVARCHAR(50) NOT NULL,
    [Nombre Beneficiario]       NVARCHAR(200),
    [Pais Destino]              NVARCHAR(100),
    [Importe Transferencia]     DECIMAL(18,2) NOT NULL,
    [Comision Aplicada]         DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Estado Transferencia]      NVARCHAR(50) NOT NULL,
    [Canal Operacion]           NVARCHAR(50),
    [Es Pago Recurrente]        BIT NOT NULL DEFAULT 0,
    [Es SEPA]                   BIT NOT NULL DEFAULT 0,
    [WWI Transferencia ID]      INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_Transferencia_FechaOperacion ([Fecha Operacion Key]),
    INDEX IX_Transferencia_Cliente ([Cliente Key]),
    INDEX IX_Transferencia_CuentaOrigen ([Cuenta Origen Key]),
    INDEX IX_Transferencia_TipoTransferencia ([Tipo Transferencia])
);
GO

IF OBJECT_ID('Fact.Comision','U') IS NOT NULL DROP TABLE [Fact].[Comision];
GO
CREATE TABLE [Fact].[Comision] (
    [Comision Key]          BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Cargo Key]       INT NOT NULL,
    [Cliente Key]           INT NOT NULL,
    [Producto Key]          INT,
    [Tipo Comision Key]     INT NOT NULL,
    [Numero Operacion]      NVARCHAR(50),
    [Tipo Operacion]        NVARCHAR(100),
    [Importe Comision]      DECIMAL(18,2) NOT NULL,
    [Base Calculo]          DECIMAL(18,2),
    [Porcentaje Aplicado]   DECIMAL(5,3),
    [Canal Operacion]       NVARCHAR(50),
    [Lineage Key]           INT NOT NULL,
    INDEX IX_Comision_FechaCargo ([Fecha Cargo Key]),
    INDEX IX_Comision_Cliente ([Cliente Key]),
    INDEX IX_Comision_TipoComision ([Tipo Comision Key])
);
GO

IF OBJECT_ID('Fact.CIRBE','U') IS NOT NULL DROP TABLE [Fact].[CIRBE];
GO
CREATE TABLE [Fact].[CIRBE] (
    [CIRBE Key]                     BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Declaracion Key]         INT NOT NULL,
    [Cliente Key]                   INT NOT NULL,
    [Entidad Financiera Key]        INT NOT NULL,
    [Clasificacion Riesgo Key]      INT,
    [Periodo Declaracion]           NVARCHAR(7) NOT NULL,
    [Tipo Operacion]                NVARCHAR(100),
    [Naturaleza Operacion]          NVARCHAR(100),
    [Importe Operacion]             DECIMAL(18,2) NOT NULL,
    [Saldo Vivo]                    DECIMAL(18,2) NOT NULL,
    [Tipo Garantia]                 NVARCHAR(100),
    [Es Operacion Dudosa]           BIT NOT NULL DEFAULT 0,
    [Riesgo Directo]                DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Riesgo Indirecto]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Provision Dotada]              DECIMAL(18,2) NOT NULL DEFAULT 0,
    [WWI CIRBE ID]                  INT NOT NULL,
    [Lineage Key]                   INT NOT NULL,
    INDEX IX_CIRBE_FechaDeclaracion ([Fecha Declaracion Key]),
    INDEX IX_CIRBE_Cliente ([Cliente Key]),
    INDEX IX_CIRBE_Periodo ([Periodo Declaracion]),
    INDEX IX_CIRBE_EntidadFinanciera ([Entidad Financiera Key])
);
GO

IF OBJECT_ID('Fact.Provision','U') IS NOT NULL DROP TABLE [Fact].[Provision];
GO
CREATE TABLE [Fact].[Provision] (
    [Provision Key]             BIGINT IDENTITY(1,1) PRIMARY KEY,
    [Fecha Provision Key]       INT NOT NULL,
    [Cliente Key]               INT NOT NULL,
    [Clasificacion Riesgo Key]  INT NOT NULL,
    [Numero Contrato]           NVARCHAR(50) NOT NULL,
    [Tipo Provision]            NVARCHAR(100) NOT NULL,
    [Importe Provisionado]      DECIMAL(18,2) NOT NULL,
    [Importe Recuperado]        DECIMAL(18,2) NOT NULL DEFAULT 0,
    [Saldo Provision]           DECIMAL(18,2) NOT NULL,
    [Porcentaje Provision]      DECIMAL(5,2),
    [WWI Provision ID]          INT NOT NULL,
    [Lineage Key]               INT NOT NULL,
    INDEX IX_Provision_FechaProvision ([Fecha Provision Key]),
    INDEX IX_Provision_Cliente ([Cliente Key]),
    INDEX IX_Provision_Contrato ([Numero Contrato]),
    INDEX IX_Provision_ClasificacionRiesgo ([Clasificacion Riesgo Key])
);
GO
PRINT ' Hechos (9 tablas)';
GO

PRINT '';

PRINT 'RESUMEN GOLD: 10 Dimensiones y 9 Hechos en Dimension/Fact';

GO

