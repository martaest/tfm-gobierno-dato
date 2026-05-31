-- Generador de datos sinteticos para la capa Bronze de banca.
-- Sigue el mismo enfoque que el DataLoadSimulation original de WideWorldImporters:
-- arranca en 2013-01-01 y va generando hasta ayer, de forma incremental (toma el
-- MAX(FechaMovimiento) ya cargado, asi se puede relanzar sin duplicar).
-- Los IBAN se generan con su digito de control mod-97 correcto,
-- dejando a proposito un pequeno porcentaje invalido para tener casos de calidad.

USE WideWorldImporters;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='Banca') EXEC('CREATE SCHEMA Banca');
GO

-- DROP todos los SPs para recrear limpios
IF OBJECT_ID('Banca.PopulateDataToCurrentDate','P')   IS NOT NULL DROP PROCEDURE Banca.PopulateDataToCurrentDate;
IF OBJECT_ID('Banca.DailyProcessToCreateHistory','P') IS NOT NULL DROP PROCEDURE Banca.DailyProcessToCreateHistory;
IF OBJECT_ID('Banca.AddProductoCatalogo','P')         IS NOT NULL DROP PROCEDURE Banca.AddProductoCatalogo;
IF OBJECT_ID('Banca.AddRiesgoAmpliado','P')           IS NOT NULL DROP PROCEDURE Banca.AddRiesgoAmpliado;
IF OBJECT_ID('Banca.AddTransferenciasCompleto','P')   IS NOT NULL DROP PROCEDURE Banca.AddTransferenciasCompleto;
IF OBJECT_ID('Banca.AddOperacionesCredito','P')       IS NOT NULL DROP PROCEDURE Banca.AddOperacionesCredito;
IF OBJECT_ID('Banca.AddMovimientos','P')              IS NOT NULL DROP PROCEDURE Banca.AddMovimientos;
IF OBJECT_ID('Banca.AddCuentas','P')                  IS NOT NULL DROP PROCEDURE Banca.AddCuentas;
IF OBJECT_ID('Banca.AddClientes','P')                 IS NOT NULL DROP PROCEDURE Banca.AddClientes;
IF OBJECT_ID('Banca.CargarCatalogosSiVacio','P')      IS NOT NULL DROP PROCEDURE Banca.CargarCatalogosSiVacio;
GO

-- SP 1: CargarCatalogosSiVacio - idempotente, solo ejecuta si vacío
CREATE PROCEDURE Banca.CargarCatalogosSiVacio
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Cliente.TiposDocumento)
    BEGIN
        SET IDENTITY_INSERT Cliente.TiposDocumento ON;
        INSERT INTO Cliente.TiposDocumento (TipoDocumentoID,CodigoTipo,NombreTipo,PaisEmision,ValidacionPattern,EsVigente) VALUES
            (1,'DNI','Documento Nacional de Identidad','España','^[0-9]{8}[A-Z]$',1),
            (2,'NIE','Número de Identidad de Extranjero','España','^[XYZ][0-9]{7}[A-Z]$',1),
            (3,'PASAPORTE','Pasaporte','Internacional','^[A-Z]{3}[0-9]{6}$',1),
            (4,'CIF','Código de Identificación Fiscal','España','^[A-Z][0-9]{8}$',1),
            (5,'NIF','Número de Identificación Fiscal','España','^[0-9]{8}[A-Z]$',1);
        SET IDENTITY_INSERT Cliente.TiposDocumento OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Cliente.Segmentos)
    BEGIN
        SET IDENTITY_INSERT Cliente.Segmentos ON;
        INSERT INTO Cliente.Segmentos (SegmentoID,CodigoSegmento,NombreSegmento,Descripcion,NivelRiesgo,EsVigente) VALUES
            (1,'NORMAL','Normal','Cliente estándar',3,1),(2,'GOLD','Gold','Volumen medio',2,1),
            (3,'PREMIUM','Premium','Condiciones preferenciales',1,1),(4,'PYME','PYME','PYME',3,1),
            (5,'EMPRESA','Empresarial','Gran empresa',2,1),(6,'CORPORATE','Corporate','Multinacional',1,1);
        SET IDENTITY_INSERT Cliente.Segmentos OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Cuenta.TiposCuenta)
    BEGIN
        SET IDENTITY_INSERT Cuenta.TiposCuenta ON;
        INSERT INTO Cuenta.TiposCuenta (TipoCuentaID,CodigoTipoCuenta,NombreTipoCuenta,RequiereNomina,PermiteDescubierto,EsVigente) VALUES
            (1,'CC_ESTANDAR','Cuenta Corriente Estándar',0,1,1),(2,'CC_PREMIUM','Cuenta Corriente Premium',0,1,1),
            (3,'CA_AHORRO','Cuenta Ahorro',0,0,1),(4,'CA_PLAZO','Cuenta Ahorro Plazo Fijo',0,0,1),
            (5,'CN_NOMINA','Cuenta Nómina',1,1,1),(6,'CN_PENSION','Cuenta Pensión',0,0,1);
        SET IDENTITY_INSERT Cuenta.TiposCuenta OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Credito.TiposGarantia)
    BEGIN
        SET IDENTITY_INSERT Credito.TiposGarantia ON;
        INSERT INTO Credito.TiposGarantia (TipoGarantiaID,CodigoTipoGarantia,NombreTipoGarantia,RequiereValoracion,RequiereSeguro,EsVigente) VALUES
            (1,'HIPOTECA','Hipoteca Inmobiliaria',1,1,1),(2,'PIGNORAC','Pignoración de Activos',1,0,1),
            (3,'AVAL_PERS','Aval Personal',0,0,1),(4,'GARANTIA_D','Garantía Dineraria',0,0,1),
            (5,'SIN_GARAN','Sin Garantía',0,0,1);
        SET IDENTITY_INSERT Credito.TiposGarantia OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Transferencia.TiposOperacion)
    BEGIN
        SET IDENTITY_INSERT Transferencia.TiposOperacion ON;
        INSERT INTO Transferencia.TiposOperacion (TipoOperacionID,CodigoTipoOperacion,NombreTipoOperacion,RequiereValidacion,EsVigente) VALUES
            (1,'TRANSF_INT','Transferencia Interna',0,1),(2,'TRANSF_EXT','Transferencia Externa',0,1),
            (3,'SEPA_SCT','SEPA Credit Transfer',0,1),(4,'SEPA_INST','SEPA Instant',0,1),
            (5,'PAGO_RECUR','Pago Recurrente',0,1),(6,'BIZUM','Bizum',0,1);
        SET IDENTITY_INSERT Transferencia.TiposOperacion OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Riesgo.ClasificacionesRiesgo)
    BEGIN
        SET IDENTITY_INSERT Riesgo.ClasificacionesRiesgo ON;
        INSERT INTO Riesgo.ClasificacionesRiesgo (ClasificacionRiesgoID,CodigoClasificacion,NombreClasificacion,NivelRiesgo,PorcentajeProvision,EsVigente) VALUES
            (1,'NORMAL','Riesgo Normal',1,0.00,1),(2,'VIGILANCIA','Vigilancia Especial',2,1.00,1),
            (3,'SUBESTAND','Substandard',3,15.00,1),(4,'DUDOSO','Dudoso',4,25.00,1),(5,'FALLIDO','Fallido',5,100.00,1);
        SET IDENTITY_INSERT Riesgo.ClasificacionesRiesgo OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Riesgo.EntidadesFinancieras)
    BEGIN
        SET IDENTITY_INSERT Riesgo.EntidadesFinancieras ON;
        INSERT INTO Riesgo.EntidadesFinancieras (EntidadFinancieraID,CodigoEntidad,NombreEntidad,TipoEntidad,Pais,EsVigente) VALUES
            (1,'0049','Banco Santander','Banco','España',1),(2,'0075','Banco Popular','Banco','España',1),
            (3,'0182','BBVA','Banco','España',1),(4,'2100','CaixaBank','Banco','España',1),
            (5,'0081','Banco Sabadell','Banco','España',1),(6,'0128','Bankinter','Banco','España',1),
            (7,'2038','Bankia','Banco','España',1),(8,'3058','Cajamar','Cooperativa','España',1),
            (9,'0239','Banco Mediolanum','Banco','España',1),(10,'0487','Banco Mare Nostrum','Banco','España',1);
        SET IDENTITY_INSERT Riesgo.EntidadesFinancieras OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Organizacion.ZonasGeograficas)
    BEGIN
        SET IDENTITY_INSERT Organizacion.ZonasGeograficas ON;
        INSERT INTO Organizacion.ZonasGeograficas (ZonaGeograficaID,CodigoZona,NombreZona,TipoZona,ZonaPadreID,EsVigente) VALUES
            (1,'NAC','Nacional','Nacional',NULL,1),(2,'NORTE','Zona Norte','Autonómica',1,1),
            (3,'SUR','Zona Sur','Autonómica',1,1),(4,'ESTE','Zona Este','Autonómica',1,1),
            (5,'CENTRO','Zona Centro','Autonómica',1,1),(6,'MAD','Madrid','Provincial',5,1),
            (7,'BCN','Barcelona','Provincial',4,1),(8,'VAL','Valencia','Provincial',4,1),
            (9,'SEV','Sevilla','Provincial',3,1),(10,'BIL','Bilbao','Provincial',2,1);
        SET IDENTITY_INSERT Organizacion.ZonasGeograficas OFF;
        SET IDENTITY_INSERT Organizacion.Departamentos ON;
        INSERT INTO Organizacion.Departamentos (DepartamentoID,CodigoDepartamento,NombreDepartamento,DepartamentoPadreID,Nivel,EsVigente) VALUES
            (1,'DIR','Dirección General',NULL,1,1),(2,'RRHH','Recursos Humanos',1,2,1),
            (3,'TEC','Tecnología',1,2,1),(4,'BANCA','Banca Comercial',1,2,1),
            (5,'RIESGO','Gestión de Riesgos',1,2,1),(6,'COMPL','Compliance',1,2,1),
            (7,'PART','Banca Particulares',4,3,1),(8,'EMPRES','Banca Empresas',4,3,1),
            (9,'HIPOT','Hipotecas',4,3,1),(10,'INVERS','Inversión',4,3,1);
        SET IDENTITY_INSERT Organizacion.Departamentos OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Organizacion.Sucursales)
    BEGIN
        DECLARE @SD TABLE (Nombre NVARCHAR(200),Loc NVARCHAR(100),Prov NVARCHAR(100),CP NVARCHAR(10),ZID INT);
        INSERT INTO @SD VALUES
            ('Sucursal Madrid Centro','Madrid','Madrid','28001',6),
            ('Sucursal Madrid Norte','Madrid','Madrid','28020',6),
            ('Sucursal Madrid Sur','Madrid','Madrid','28041',6),
            ('Sucursal Madrid Este','Madrid','Madrid','28017',6),
            ('Sucursal Madrid Oeste','Madrid','Madrid','28008',6),
            ('Sucursal Alcalá de Henares','Alcalá de Henares','Madrid','28801',6),
            ('Sucursal Getafe','Getafe','Madrid','28901',6),
            ('Sucursal Móstoles','Móstoles','Madrid','28933',6),
            ('Sucursal Leganés','Leganés','Madrid','28911',6),
            ('Sucursal Pozuelo','Pozuelo','Madrid','28224',6),
            ('Sucursal Barcelona Centro','Barcelona','Barcelona','08001',7),
            ('Sucursal Barcelona Gracia','Barcelona','Barcelona','08012',7),
            ('Sucursal Barcelona Sants','Barcelona','Barcelona','08014',7),
            ('Sucursal Hospitalet','L''Hospitalet','Barcelona','08901',7),
            ('Sucursal Badalona','Badalona','Barcelona','08911',7),
            ('Sucursal Valencia Centro','Valencia','Valencia','46001',8),
            ('Sucursal Valencia Norte','Valencia','Valencia','46020',8),
            ('Sucursal Alicante','Alicante','Alicante','03001',8),
            ('Sucursal Murcia','Murcia','Murcia','30001',8),
            ('Sucursal Castellón','Castellón','Castellón','12001',8),
            ('Sucursal Sevilla Centro','Sevilla','Sevilla','41001',9),
            ('Sucursal Sevilla Norte','Sevilla','Sevilla','41010',9),
            ('Sucursal Málaga','Málaga','Málaga','29001',9),
            ('Sucursal Córdoba','Córdoba','Córdoba','14001',9),
            ('Sucursal Granada','Granada','Granada','18001',9),
            ('Sucursal Bilbao Centro','Bilbao','Vizcaya','48001',10),
            ('Sucursal Bilbao Indautxu','Bilbao','Vizcaya','48010',10),
            ('Sucursal San Sebastián','San Sebastián','Guipúzcoa','20001',10),
            ('Sucursal Vitoria','Vitoria','Álava','01001',10),
            ('Sucursal Pamplona','Pamplona','Navarra','31001',2),
            ('Sucursal Zaragoza','Zaragoza','Zaragoza','50001',2),
            ('Sucursal Logroño','Logroño','La Rioja','26001',2),
            ('Sucursal Burgos','Burgos','Burgos','09001',5),
            ('Sucursal Valladolid','Valladolid','Valladolid','47001',5),
            ('Sucursal Salamanca','Salamanca','Salamanca','37001',5),
            ('Sucursal Toledo','Toledo','Toledo','45001',5),
            ('Sucursal Ciudad Real','Ciudad Real','Ciudad Real','13001',5),
            ('Sucursal Albacete','Albacete','Albacete','02001',5),
            ('Sucursal Cuenca','Cuenca','Cuenca','16001',5),
            ('Sucursal Guadalajara','Guadalajara','Guadalajara','19001',5),
            ('Sucursal A Coruña','A Coruña','A Coruña','15001',2),
            ('Sucursal Vigo','Vigo','Pontevedra','36201',2),
            ('Sucursal Oviedo','Oviedo','Asturias','33001',2),
            ('Sucursal Santander','Santander','Cantabria','39001',2),
            ('Sucursal Palma','Palma','Baleares','07001',4),
            ('Sucursal Las Palmas','Las Palmas','Las Palmas','35001',3),
            ('Sucursal Santa Cruz','Santa Cruz','Tenerife','38001',3),
            ('Sucursal Badajoz','Badajoz','Badajoz','06001',5),
            ('Sucursal Cáceres','Cáceres','Cáceres','10001',5),
            ('Sucursal Huelva','Huelva','Huelva','21001',3);
        INSERT INTO Organizacion.Sucursales (CodigoSucursal,NombreSucursal,DireccionCompleta,CodigoPostal,Localidad,Provincia,ZonaGeograficaID,NumeroEmpleados,FechaApertura,EstadoSucursal)
        SELECT 'SUC-'+RIGHT('000'+CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(3)),3),
               Nombre,'Calle Mayor 1, '+Loc,CP,Loc,Prov,ZID,
               5+ABS(CHECKSUM(NEWID()))%20,
               DATEADD(YEAR,-(2+ABS(CHECKSUM(NEWID()))%15),'2013-01-01'),'Activa'
        FROM @SD;
    END

    IF NOT EXISTS (SELECT 1 FROM Organizacion.CajeroAutomaticos)
        INSERT INTO Organizacion.CajeroAutomaticos (CodigoCajero,SucursalID,Ubicacion,TipoCajero,Localidad,Provincia,LimiteRetiroDiario,FechaInstalacion,EstadoCajero)
        SELECT TOP 80 'ATM-'+RIGHT('0000'+CAST(ROW_NUMBER() OVER (ORDER BY s.SucursalID) AS VARCHAR(4)),4),
            s.SucursalID,'Vestíbulo - '+s.NombreSucursal,
            CASE WHEN ROW_NUMBER() OVER (ORDER BY s.SucursalID)%3=0 THEN 'Externo' ELSE 'Interno' END,
            s.Localidad,s.Provincia,
            CASE WHEN ROW_NUMBER() OVER (ORDER BY s.SucursalID)%4=0 THEN 600.00 ELSE 1000.00 END,
            DATEADD(YEAR,-(ABS(CHECKSUM(NEWID()))%8),'2013-01-01'),'Operativo'
        FROM Organizacion.Sucursales s CROSS JOIN (SELECT TOP 2 1 x FROM sys.objects) d;

    IF NOT EXISTS (SELECT 1 FROM Producto.TiposProducto)
    BEGIN
        SET IDENTITY_INSERT Producto.TiposProducto ON;
        INSERT INTO Producto.TiposProducto (TipoProductoID,CodigoTipoProducto,NombreTipoProducto,Categoria,EsVigente) VALUES
            (1,'CTA_CORR','Cuentas Corrientes','Pasivo',1),(2,'CTA_AHORR','Cuentas de Ahorro','Pasivo',1),
            (3,'CTA_NOMIN','Cuentas Nómina','Pasivo',1),(4,'PREST_HIP','Préstamos Hipotecarios','Activo',1),
            (5,'PREST_CONS','Préstamos Consumo','Activo',1),(6,'PREST_PERS','Préstamos Personales','Activo',1),
            (7,'LINEA_CRED','Líneas de Crédito','Activo',1),(8,'TARJ_CRED','Tarjetas de Crédito','Activo',1),
            (9,'INVERSION','Fondos de Inversión','Pasivo',1),(10,'SEGURO','Seguros','Servicio',1);
        SET IDENTITY_INSERT Producto.TiposProducto OFF;
        SET IDENTITY_INSERT Producto.CategoriasProducto ON;
        INSERT INTO Producto.CategoriasProducto (CategoriaProductoID,CodigoCategoria,NombreCategoria,CategoriaPadreID,Nivel,EsVigente) VALUES
            (1,'BANCA_PART','Banca Particulares',NULL,1,1),(2,'BANCA_EMP','Banca Empresas',NULL,1,1),
            (3,'PASIVO','Productos Pasivo',1,2,1),(4,'ACTIVO','Productos Activo',1,2,1),(5,'SERVICIOS','Servicios',1,2,1);
        SET IDENTITY_INSERT Producto.CategoriasProducto OFF;
    END

    IF NOT EXISTS (SELECT 1 FROM Producto.CatalogoProductos)
        INSERT INTO Producto.CatalogoProductos (CodigoProducto,NombreProducto,Descripcion,TipoProductoID,CategoriaProductoID,TAE,TIN,Comision,ImporteMinimo,ImporteMaximo,PlazoMinimoDias,PlazoMaximoDias,RequiereGarantia,EdadMinima,EsComercializable,FechaLanzamiento) VALUES
            ('CC-001','Cuenta Corriente Estándar','Sin comisiones',1,3,NULL,NULL,0,0,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('CC-002','Cuenta Corriente Premium','Con beneficios',1,3,NULL,NULL,0,0,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('CC-003','Cuenta Corriente Joven','18-25 años',1,3,NULL,NULL,0,0,NULL,NULL,NULL,0,18,1,'2015-01-01'),
            ('CA-001','Cuenta Ahorro Plus','TAE 1.5%',2,3,1.500,1.480,0,500,50000,30,730,0,18,1,'2012-01-01'),
            ('CA-002','Cuenta Ahorro Infantil','Para menores',2,3,2.000,1.980,0,100,10000,NULL,NULL,0,0,1,'2015-06-01'),
            ('CA-003','Depósito Plazo 12M','Plazo fijo 12M',2,3,2.500,2.460,0,1000,100000,365,365,0,18,1,'2016-01-01'),
            ('CN-001','Cuenta Nómina Básica','Sin comisiones',3,3,NULL,NULL,0,0,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('CN-002','Cuenta Nómina Plus','Con bonificaciones',3,3,NULL,NULL,0,0,NULL,NULL,NULL,0,18,1,'2015-01-01'),
            ('PH-001','Hipoteca Fija 25 años','TIN 2.5%',4,4,2.600,2.500,500,50000,500000,1825,9125,1,18,1,'2012-01-01'),
            ('PH-002','Hipoteca Variable Euribor+0.9','Variable',4,4,1.800,1.700,500,50000,600000,1825,9125,1,18,1,'2012-01-01'),
            ('PH-003','Hipoteca Mixta','10 años fijo+variable',4,4,2.200,2.100,500,80000,500000,3650,9125,1,18,1,'2015-01-01'),
            ('PH-004','Hipoteca Joven','Menores 35 años',4,4,2.400,2.300,300,50000,300000,3650,9125,1,18,1,'2018-01-01'),
            ('PC-001','Préstamo Consumo Estándar','TIN 6%',5,4,6.200,6.000,300,1000,30000,180,1825,0,18,1,'2012-01-01'),
            ('PC-002','Préstamo Auto','Financiación vehículo',5,4,5.500,5.300,300,5000,50000,365,2920,0,18,1,'2012-01-01'),
            ('PC-003','Préstamo Reformas','Reformas hogar',5,4,7.000,6.800,200,2000,40000,180,1825,0,18,1,'2016-01-01'),
            ('PP-001','Préstamo Personal Urgente','Rápido',6,4,9.000,8.700,150,500,10000,90,730,0,18,1,'2012-01-01'),
            ('PP-002','Préstamo Estudios','Formación',6,4,4.500,4.300,0,1000,20000,365,2190,0,18,1,'2015-09-01'),
            ('LC-001','Línea Crédito Empresas','Empresas',7,4,4.500,4.300,500,10000,250000,NULL,365,0,18,1,'2012-01-01'),
            ('LC-002','Línea Crédito PYME','PYMES',7,4,5.000,4.800,300,5000,100000,NULL,365,0,18,1,'2012-01-01'),
            ('LC-003','Línea Crédito Comercial','Comercial',7,4,4.500,4.300,300,25000,250000,NULL,365,0,18,1,'2016-01-01'),
            ('TC-001','Tarjeta Crédito Visa Classic','Límite 3000€',8,4,26.820,24.000,36,0,3000,NULL,NULL,0,18,1,'2012-01-01'),
            ('TC-002','Tarjeta Crédito Gold','Límite 10000€',8,4,24.180,21.600,60,0,10000,NULL,NULL,0,18,1,'2012-01-01'),
            ('FI-001','Fondo Inversión Conservador','Renta fija',9,3,2.000,1.800,150,500,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('FI-002','Fondo Inversión Moderado','Mixto',9,3,4.000,3.600,150,1000,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('FI-003','Fondo Inversión Dinámico','Renta variable',9,3,7.000,6.300,150,1000,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('SEG-001','Seguro Vida','Vinculado hipoteca',10,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('SEG-002','Seguro Hogar','Multirriesgo hogar',10,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,18,1,'2012-01-01'),
            ('SEG-003','Seguro Accidentes','Accidentes personal',10,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,18,1,'2016-01-01'),
            ('PK-001','Pack Básico','CC + Tarjeta Débito',1,5,NULL,NULL,0,NULL,NULL,NULL,NULL,0,18,1,'2016-01-01'),
            ('PK-002','Pack Premium','Nómina+Tarjeta+Seguro',3,5,NULL,NULL,0,NULL,NULL,NULL,NULL,0,18,1,'2018-01-01');
END;
GO

-- SP 2: AddClientes - 6 personas/día + 1 empresa/día laborable
-- Sin BEGIN TRAN explícito = autocommit = log vacía continuamente
CREATE PROCEDURE Banca.AddClientes
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT,
    @PctDQ           INT = 15
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FechaAlta DATE = CAST(@CurrentDateTime AS DATE);
    DECLARE @NClientesHoy INT = 6;  -- fijo, predecible, ~21k en 13 años

    -- Arrays nombres/apellidos para selección aleatoria
    DECLARE @LN TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    DECLARE @LA TABLE (n INT IDENTITY(1,1), v NVARCHAR(80));
    INSERT INTO @LN (v) VALUES
        ('Juan'),('María'),('Antonio'),('Carmen'),('José'),('Ana'),
        ('Francisco'),('Isabel'),('Manuel'),('Dolores'),('David'),('Pilar'),
        ('Daniel'),('Teresa'),('Carlos'),('Rosa'),('Miguel'),('Laura'),
        ('Rafael'),('Marta'),('Pedro'),('Cristina'),('Javier'),('Elena'),
        ('Luis'),('Lucía'),('Sergio'),('Patricia'),('Alejandro'),('Raquel'),
        ('Pablo'),('Sandra'),('Alberto'),('Silvia'),('Fernando'),('Mónica'),
        ('Jorge'),('Beatriz'),('Ángel'),('Natalia'),('Roberto'),('Sofía'),
        ('Andrés'),('Inés'),('Ricardo'),('Amparo'),('Enrique'),('Consuelo'),
        ('Agustín'),('Esperanza'),('Diego'),('Verónica'),('Marcos'),('Nuria'),
        ('Víctor'),('Irene'),('Rubén'),('Esther'),('Iván'),('Lorena'),
        ('Óscar'),('Rebeca'),('Adrián'),('Alicia'),('Hugo'),('Rocío'),
        ('Gonzalo'),('Eva'),('Ignacio'),('Yolanda'),('Jaime'),('Miriam');
    INSERT INTO @LA (v) VALUES
        ('García'),('Rodríguez'),('González'),('Fernández'),('López'),
        ('Martínez'),('Sánchez'),('Pérez'),('Gómez'),('Martín'),
        ('Jiménez'),('Ruiz'),('Hernández'),('Díaz'),('Moreno'),
        ('Álvarez'),('Muñoz'),('Romero'),('Alonso'),('Gutiérrez'),
        ('Navarro'),('Torres'),('Domínguez'),('Vázquez'),('Ramos'),
        ('Gil'),('Ramírez'),('Serrano'),('Blanco'),('Suárez'),
        ('Molina'),('Morales'),('Ortega'),('Delgado'),('Castro'),
        ('Ortiz'),('Rubio'),('Marín'),('Sanz'),('Iglesias'),
        ('Núñez'),('Medina'),('Garrido'),('Santos'),('Castillo'),
        ('Cortés'),('Lozano'),('Guerrero'),('Cano'),('Méndez'),
        ('Vargas'),('Cruz'),('Prieto'),('Flores'),('Herrera'),
        ('Peña'),('León'),('Márquez'),('Cabrera'),('Gallego'),
        ('Calvo'),('Vidal'),('Campos'),('Reyes'),('Vega'),
        ('Fuentes'),('Carrasco'),('Diez'),('Aguilar'),('Nieto'),
        ('Pascual'),('Ibáñez'),('Hidalgo'),('Parra'),('Mora');
    DECLARE @TN INT = (SELECT COUNT(*) FROM @LN);
    DECLARE @TA INT = (SELECT COUNT(*) FROM @LA);

    DECLARE @Counter    INT = 0;
    DECLARE @PersonaID  INT;
    DECLARE @DNombre    NVARCHAR(50);
    DECLARE @DApellido1 NVARCHAR(80);
    DECLARE @DApellido2 NVARCHAR(80);

    WHILE @Counter < @NClientesHoy
    BEGIN
        -- Nombres aleatorios sin límite - CHECKSUM(NEWID()) en vez de RAND()
        SELECT TOP(1) @DNombre    = v FROM @LN ORDER BY NEWID();
        SELECT TOP(1) @DApellido1 = v FROM @LA ORDER BY NEWID();
        SELECT TOP(1) @DApellido2 = v FROM @LA ORDER BY NEWID();

        DECLARE @NuevoID INT = ISNULL((SELECT MAX(PersonaID) FROM Cliente.Personas),0) + 1;
        DECLARE @DNINum  INT = 20000000 + @NuevoID;

        -- Letra DNI: ~3% incorrecta (DQ)
        DECLARE @LetraOK CHAR(1) = SUBSTRING('TRWAGMYFPDXBNJZSQVHLCKE',(@DNINum%23)+1,1);
        DECLARE @LetraKO CHAR(1) = SUBSTRING('WTRWAGMYFPDXBNJZSQVHLCKE',(@DNINum%23)+1,1);
        DECLARE @DNI NVARCHAR(20) = RIGHT('00000000'+CAST(@DNINum AS VARCHAR(8)),8) +
            CASE WHEN @NuevoID%33=0 THEN @LetraKO ELSE @LetraOK END;

        -- Email: ~5% sin @ (DQ)
        DECLARE @Email NVARCHAR(255) = CASE WHEN @NuevoID%20=0
            THEN LOWER(@DNombre)+'.'+LOWER(@DApellido1)+'gmail.com'
            ELSE LOWER(@DNombre)+'.'+LOWER(@DApellido1)+'@'+
                 (SELECT TOP(1) d FROM (VALUES('gmail.com'),('hotmail.com'),('yahoo.es'),('outlook.com')) AS q(d) ORDER BY NEWID()) END;

        -- Teléfono: ~5% de 8 dígitos (DQ)
        DECLARE @Tel NVARCHAR(20) = CASE WHEN @NuevoID%20=0
            THEN '6'+RIGHT('0000000'+CAST(ABS(CHECKSUM(NEWID()))%10000000 AS VARCHAR(7)),7)
            ELSE '6'+RIGHT('00000000'+CAST(ABS(CHECKSUM(NEWID()))%100000000 AS VARCHAR(8)),8) END;

        -- Segmento
        DECLARE @Seg INT = CASE WHEN @NuevoID%20<3 THEN 3 WHEN @NuevoID%20<8 THEN 2 ELSE 1 END;

        -- Fecha baja: ~2.5% inactivos, ~3% de esos con fecha incorrecta (DQ)
        DECLARE @FechaBaja DATE = NULL;
        IF @NuevoID%40=0
            SET @FechaBaja = CASE WHEN @NuevoID%120=0
                THEN DATEADD(DAY,-1,@FechaAlta)  -- fecha baja ANTES de alta (DQ)
                ELSE DATEADD(MONTH,6+ABS(CHECKSUM(NEWID()))%18,@FechaAlta) END;

        -- Score: ~2% con ProbabilidadImpago > 30 (fuera de rango real, DQ)
        DECLARE @ProbImpago DECIMAL(5,2) = CASE WHEN @NuevoID%50=0
            THEN CAST(30+ABS(CHECKSUM(NEWID()))%70 AS DECIMAL(5,2))  -- DQ: valor irreal
            ELSE CAST(ABS(CHECKSUM(NEWID()))%30 AS DECIMAL(5,2)) END;

        -- CP: ~4% de 4 dígitos (DQ)
        DECLARE @Localidades TABLE (Loc NVARCHAR(100),Prov NVARCHAR(100),CP NVARCHAR(10));
        INSERT INTO @Localidades VALUES
            ('Madrid','Madrid','28001'),('Barcelona','Barcelona','08001'),
            ('Valencia','Valencia','46001'),('Sevilla','Sevilla','41001'),
            ('Bilbao','Vizcaya','48001'),('Zaragoza','Zaragoza','50001'),
            ('Málaga','Málaga','29001'),('Murcia','Murcia','30001'),
            ('Vigo','Pontevedra','36201'),('Oviedo','Asturias','33001'),
            ('Granada','Granada','18001'),('Pamplona','Navarra','31001'),
            ('Santander','Cantabria','39001'),('Alicante','Alicante','03001'),
            ('Valladolid','Valladolid','47001'),('Toledo','Toledo','45001');
        DECLARE @LocRow TABLE (Loc NVARCHAR(100),Prov NVARCHAR(100),CP NVARCHAR(10));
        INSERT INTO @LocRow SELECT TOP(1) * FROM @Localidades ORDER BY NEWID();
        DECLARE @CPFinal NVARCHAR(10) = (SELECT CASE WHEN @NuevoID%25=0 THEN LEFT(CP,4) ELSE CP END FROM @LocRow);
        DECLARE @LocFinal NVARCHAR(100) = (SELECT Loc FROM @LocRow);
        DECLARE @ProvFinal NVARCHAR(100) = (SELECT Prov FROM @LocRow);

        -- ── INSERT Personas (autocommit) ──
        INSERT INTO Cliente.Personas (TipoDocumentoID,NumeroDocumento,Nombre,Apellido1,Apellido2,
            FechaNacimiento,Sexo,Nacionalidad,Email,TelefonoMovil,TelefonoFijo,
            SegmentoID,EsClienteActivo,FechaAlta,FechaBaja)
        VALUES (CASE WHEN @NuevoID%50=0 THEN 2 ELSE 1 END,
            @DNI,@DNombre,@DApellido1,@DApellido2,
            DATEADD(DAY,-(18*365+ABS(CHECKSUM(NEWID()))%16425),'2006-01-01'),
            CASE WHEN @NuevoID%2=0 THEN 'M' ELSE 'F' END,
            CASE WHEN @NuevoID%20=0 THEN 'Francia' WHEN @NuevoID%25=0 THEN 'Italia'
                 WHEN @NuevoID%30=0 THEN 'Portugal' ELSE 'España' END,
            @Email,@Tel,
            CASE WHEN @NuevoID%3=0 THEN '9'+RIGHT('00000000'+CAST(ABS(CHECKSUM(NEWID()))%100000000 AS VARCHAR(8)),8) ELSE NULL END,
            @Seg,CASE WHEN @FechaBaja IS NOT NULL AND @FechaBaja<=@FechaAlta THEN 0 ELSE 1 END,
            @FechaAlta,@FechaBaja);
        SET @PersonaID = SCOPE_IDENTITY();

        -- ── Score crediticio ──
        INSERT INTO Cliente.ScoreCrediticio (PersonaID,ScoreCredito,NivelRiesgo,ProbabilidadImpago,
            LimiteEndeudamiento,FechaCalculoScore,FuenteScore,ModeloScoring)
        VALUES (@PersonaID,300+ABS(CHECKSUM(NEWID()))%601,
            CASE WHEN @Seg=3 THEN 'Muy Bajo' WHEN @Seg=2 THEN 'Bajo'
                 WHEN @NuevoID%10=0 THEN 'Muy Alto' WHEN @NuevoID%7=0 THEN 'Alto'
                 ELSE 'Medio' END,
            @ProbImpago,
            CASE WHEN @PersonaID%5=0 THEN NULL ELSE CAST(10000+ABS(CHECKSUM(NEWID()))%90000 AS DECIMAL(18,2)) END,
            @FechaAlta,'EQUIFAX','SCORE_V5');

        -- ── Segmentación comercial ──
        INSERT INTO Cliente.SegmentacionComercial (PersonaID,SegmentoID,SubSegmento,ClasificacionComercial,PotencialNegocio,FechaSegmentacion)
        VALUES (@PersonaID,@Seg,
            CASE @Seg WHEN 1 THEN 'RETAIL' WHEN 2 THEN 'PREFERENTE' ELSE 'BANCA_PERSONAL' END,
            CASE @Seg WHEN 3 THEN 'A' WHEN 2 THEN 'B' ELSE 'C' END,
            CASE @Seg WHEN 3 THEN 'Premium' WHEN 2 THEN 'Alto' ELSE 'Medio' END,
            @FechaAlta);

        -- ── Dirección fiscal - CP ~4% incompleto (DQ) ──
        INSERT INTO Cliente.DireccionesFiscales (PersonaID,TipoDireccion,TipoVia,NombreVia,Numero,
            CodigoPostal,Localidad,Provincia,Pais,EsDireccionPrincipal,FechaDesde)
        VALUES (@PersonaID,'Fiscal',
            (SELECT TOP(1) v FROM (VALUES('Calle'),('Avenida'),('Paseo')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('Mayor'),('Goya'),('Serrano'),('Castellana'),('Alcalá'),('Gran Vía'),('Velázquez'),('Fuencarral')) AS q(v) ORDER BY NEWID()),
            CAST(1+ABS(CHECKSUM(NEWID()))%200 AS NVARCHAR(20)),
            @CPFinal,@LocFinal,@ProvFinal,'España',1,@FechaAlta);

        -- ── Documento identidad - ~20% no verificado (DQ) ──
        DECLARE @Verif BIT = CASE WHEN @PersonaID%5=0 THEN 0 ELSE 1 END;
        INSERT INTO Cliente.DocumentosIdentidad (PersonaID,TipoDocumentoID,NumeroDocumento,
            FechaEmision,FechaCaducidad,PaisEmision,DocumentoVerificado,FechaVerificacion)
        VALUES (@PersonaID,CASE WHEN @NuevoID%50=0 THEN 2 ELSE 1 END,@DNI,
            DATEADD(YEAR,-(ABS(CHECKSUM(NEWID()))%10),@FechaAlta),
            DATEADD(YEAR,5+ABS(CHECKSUM(NEWID()))%5,@FechaAlta),
            'España',@Verif,
            CASE WHEN @Verif=1 THEN DATEADD(DAY,ABS(CHECKSUM(NEWID()))%30,@FechaAlta) ELSE NULL END);

        -- DNI duplicado en DocumentosIdentidad: ~2% (DQ - inconsistencia entre tablas)
        IF @NuevoID%50=0
        BEGIN
            DECLARE @DNIDup NVARCHAR(20);
            SELECT TOP(1) @DNIDup=NumeroDocumento FROM Cliente.Personas
            WHERE PersonaID<>@PersonaID AND TipoDocumentoID=1 ORDER BY NEWID();
            IF @DNIDup IS NOT NULL
            BEGIN
                UPDATE Cliente.DocumentosIdentidad SET NumeroDocumento=@DNIDup WHERE PersonaID=@PersonaID;
                BEGIN TRY UPDATE Cliente.Personas SET NumeroDocumento=@DNIDup WHERE PersonaID=@PersonaID; END TRY BEGIN CATCH END CATCH
            END
        END

        -- ── DatosDemograficos - ingresos ~10% NULL, patrimonio ~15% NULL (DQ) ──
        INSERT INTO Cliente.DatosDemograficos (PersonaID,EstadoCivil,NumeroHijos,NivelEstudios,
            SituacionLaboral,Profesion,IngresosMensualesEstimados,PatrimonioEstimado,FechaActualizacion)
        VALUES (@PersonaID,
            (SELECT TOP(1) v FROM (VALUES('Soltero/a'),('Casado/a'),('Casado/a'),('Casado/a'),('Divorciado/a'),('Viudo/a')) AS q(v) ORDER BY NEWID()),
            ABS(CHECKSUM(NEWID()))%4,
            (SELECT TOP(1) v FROM (VALUES('Primaria'),('Secundaria'),('Bachillerato'),('FP'),('Universitaria'),('Universitaria'),('Universitaria'),('Postgrado')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('Empleado'),('Empleado'),('Empleado'),('Autónomo'),('Desempleado'),('Jubilado'),('Estudiante')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('Administrativo'),('Técnico'),('Directivo'),('Comercial'),('Docente'),('Sanitario'),('Ingeniero'),('Abogado')) AS q(v) ORDER BY NEWID()),
            CASE WHEN @PersonaID%10=0 THEN NULL ELSE CAST(800+ABS(CHECKSUM(NEWID()))%4200 AS DECIMAL(18,2)) END,  -- ~10% NULL (DQ)
            CASE WHEN @PersonaID%7=0 THEN NULL ELSE CAST(5000+ABS(CHECKSUM(NEWID()))%195000 AS DECIMAL(18,2)) END, -- ~15% NULL (DQ)
            @FechaAlta);

        -- ── PreferenciasPrivacidad RGPD ──
        INSERT INTO Cliente.PreferenciasPrivacidad (PersonaID,AceptaComunicacionesComerciales,
            AceptaCesionDatosTerceros,AceptaPerfilado,CanalPreferidoContacto,FechaConsentimiento)
        VALUES (@PersonaID,
            CASE WHEN ABS(CHECKSUM(NEWID()))%5<2 THEN 1 ELSE 0 END,
            CASE WHEN ABS(CHECKSUM(NEWID()))%5<1 THEN 1 ELSE 0 END,
            CASE WHEN ABS(CHECKSUM(NEWID()))%5<2 THEN 1 ELSE 0 END,
            (SELECT TOP(1) v FROM (VALUES('Email'),('Teléfono'),('App'),('Correo postal')) AS q(v) ORDER BY NEWID()),
            @FechaAlta);

        -- ── Empleado: ~1 de cada 5 clientes (hasta 600) ──
        IF (SELECT COUNT(*) FROM Organizacion.Empleados)<600 AND @PersonaID%5=0
            INSERT INTO Organizacion.Empleados (NumeroEmpleado,PersonaID,DepartamentoID,SucursalID,Puesto,Categoria,FechaAlta,EstadoEmpleado)
            VALUES ('EMP-'+RIGHT('00000'+CAST(@PersonaID AS VARCHAR(5)),5),@PersonaID,
                (SELECT TOP 1 DepartamentoID FROM Organizacion.Departamentos ORDER BY NEWID()),
                (SELECT TOP 1 SucursalID FROM Organizacion.Sucursales ORDER BY NEWID()),
                (SELECT TOP(1) v FROM (VALUES('Director de Oficina'),('Gestor Comercial'),('Asesor Financiero'),('Analista de Riesgos'),('Cajero'),('Técnico Hipotecario'),('Gestor Empresas'),('Administrativo')) AS q(v) ORDER BY NEWID()),
                (SELECT TOP(1) v FROM (VALUES('Senior'),('Junior'),('Mid'),('Manager')) AS q(v) ORDER BY NEWID()),
                @FechaAlta,'Activo');

        DELETE FROM @Localidades;
        DELETE FROM @LocRow;
        SET @Counter += 1;
    END

    -- ── Empresa: 1 por día laborable (~3.500 en 13 años) ──
    DECLARE @EmpID INT = ISNULL((SELECT MAX(PersonaJuridicaID) FROM Cliente.PersonasJuridicas),0)+1;
    DECLARE @RB NVARCHAR(100) =
        (SELECT TOP(1) v FROM (VALUES('Construcciones'),('Transportes'),('Servicios'),('Tecnología'),
            ('Inmobiliaria'),('Logística'),('Hostelería'),('Ingeniería'),('Informática'),('Asesoría'),
            ('Distribuciones'),('Energía'),('Telecomunicaciones'),('Seguridad'),('Formación')) AS q(v) ORDER BY NEWID())
        +' '+(SELECT TOP(1) v FROM (VALUES('Iberia'),('Global'),('Norte'),('Sur'),('Central'),('Hispana'),('Europea'),('Atlántico')) AS q(v) ORDER BY NEWID());

    INSERT INTO Cliente.PersonasJuridicas (CIF,RazonSocial,NombreComercial,FormaJuridica,
        FechaConstitucion,CNAE,Email,TelefonoContacto,SegmentoID,EsClienteActivo,FechaAlta)
    VALUES (CHAR(65+(@EmpID%26))+RIGHT('00000000'+CAST(60000000+@EmpID AS VARCHAR(8)),8),
        @RB+' '+(SELECT TOP(1) v FROM (VALUES('SL'),('SL'),('SA'),('COOP')) AS q(v) ORDER BY NEWID()),
        LEFT(@RB,CHARINDEX(' ',@RB+' ')-1),
        (SELECT TOP(1) v FROM (VALUES('Sociedad Limitada'),('Sociedad Limitada'),('Sociedad Anónima'),('Autónomo')) AS q(v) ORDER BY NEWID()),
        DATEADD(YEAR,-(ABS(CHECKSUM(NEWID()))%15),@FechaAlta),
        CAST(1000+(@EmpID%8000) AS NVARCHAR(10)),
        CASE WHEN @EmpID%20=0 THEN NULL  -- ~5% sin email (DQ)
             ELSE LOWER(REPLACE(LEFT(@RB,CHARINDEX(' ',@RB+' ')-1),' ',''))+'@empresa.es' END,
        '9'+RIGHT('00000000'+CAST(ABS(CHECKSUM(NEWID()))%100000000 AS VARCHAR(8)),8),
        CASE WHEN @EmpID%10<2 THEN 6 WHEN @EmpID%10<5 THEN 5 ELSE 4 END,
        1,@FechaAlta);
END;
GO

-- SP 3: AddCuentas - corriente + ahorro (30%) + nómina (40%)
-- CHECKSUM(NEWID()) en vez de RAND() para evitar repetición en cursores
-- IBAN ES00 inválido ~4% (DQ)
CREATE PROCEDURE Banca.AddCuentas
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha   DATE = CAST(@CurrentDateTime AS DATE);
    DECLARE @ProdCC1 INT = (SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='CC-001');
    DECLARE @ProdCC2 INT = (SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='CC-002');
    DECLARE @ProdCA  INT = (SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='CA-001');
    DECLARE @ProdCN  INT = (SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='CN-001');

    DECLARE @pID INT; DECLARE @seg INT;
    DECLARE cCli CURSOR FAST_FORWARD READ_ONLY FOR
        SELECT p.PersonaID,p.SegmentoID FROM Cliente.Personas p
        WHERE p.FechaAlta=@Fecha AND p.EsClienteActivo=1
          AND NOT EXISTS (SELECT 1 FROM Cuenta.CuentasCorrientes cc WHERE cc.CuentaCorrienteID=p.PersonaID);

    OPEN cCli; FETCH NEXT FROM cCli INTO @pID,@seg;
    WHILE @@FETCH_STATUS=0
    BEGIN
        -- IBAN: ~4% ES00 (check digits inválidos, DQ)
        DECLARE @UsarIBANKO BIT = CASE WHEN @pID%25=0 THEN 1 ELSE 0 END;
        -- BBAN fijo basado en ID para reproducibilidad
        DECLARE @BBAN_CC NVARCHAR(20) =
            RIGHT('0000'+CAST(ABS(@pID*7+1234)%10000 AS VARCHAR(4)),4)+
            RIGHT('0000'+CAST(ABS(@pID*3+5678)%10000 AS VARCHAR(4)),4)+
            '00'+RIGHT('0000000000'+CAST(1000000000+@pID*97 AS VARCHAR(10)),10);
        -- ~4% ES00 (DQ: módulo 97 inválido intencional), resto válidos
        DECLARE @IBAN NVARCHAR(24) = CASE WHEN @UsarIBANKO=1
            THEN 'ES00'+@BBAN_CC
            ELSE 'ES'+Banca.fn_CalcIBANCheckDigits(@BBAN_CC)+@BBAN_CC END;

        -- Cuenta corriente (autocommit)
        INSERT INTO Cuenta.CuentasCorrientes (NumeroCuenta,TipoCuentaID,ProductoID,FechaApertura,
            SaldoActual,SaldoDisponible,SaldoRetenido,EstadoCuenta,SucursalGestion,FechaModificacion)
        VALUES (@IBAN,CASE WHEN @seg=3 THEN 2 ELSE 1 END,
            CASE WHEN @seg=3 THEN @ProdCC2 ELSE @ProdCC1 END,
            @Fecha,CAST(ABS(CHECKSUM(NEWID()))%5000 AS DECIMAL(18,2)),
            CAST(ABS(CHECKSUM(NEWID()))%5000 AS DECIMAL(18,2)),
            CAST(ABS(CHECKSUM(NEWID()))%100 AS DECIMAL(18,2)),
            'Activa',(SELECT TOP 1 SucursalID FROM Organizacion.Sucursales ORDER BY NEWID()),@Fecha);

        INSERT INTO Cuenta.TitularesCuenta (NumeroCuenta,PersonaID,TipoTitularidad,PorcentajePropiedad,FechaAltaTitular)
        VALUES (@IBAN,@pID,'Titular',100.00,@Fecha);

        -- Cuenta ahorro: 30% - CHECKSUM evita repetición en cursor
        IF ABS(CHECKSUM(NEWID()))%10 < 3
        BEGIN
        DECLARE @BBAN_AH NVARCHAR(20)=
                RIGHT('0000'+CAST(ABS(@pID*7+1234)%10000 AS VARCHAR(4)),4)+
                RIGHT('0000'+CAST(ABS(@pID*3+5678)%10000 AS VARCHAR(4)),4)+
                '00'+RIGHT('0000000000'+CAST(2000000000+@pID*97 AS VARCHAR(10)),10);
        DECLARE @IBAN_AH NVARCHAR(24)='ES'+Banca.fn_CalcIBANCheckDigits(@BBAN_AH)+@BBAN_AH;
            IF NOT EXISTS (SELECT 1 FROM Cuenta.CuentasAhorro WHERE NumeroCuenta=@IBAN_AH)
                INSERT INTO Cuenta.CuentasAhorro (NumeroCuenta,TipoCuentaID,ProductoID,FechaApertura,
                    SaldoActual,TAEAplicado,InteresesDevengadosMes,EstadoCuenta,FechaModificacion)
                VALUES (@IBAN_AH,3,@ProdCA,@Fecha,
                    CAST(500+ABS(CHECKSUM(NEWID()))%9500 AS DECIMAL(18,2)),1.500,
                    CAST(ABS(CHECKSUM(NEWID()))%50 AS DECIMAL(18,2)),'Activa',@Fecha);
        END

        -- Cuenta nómina: 40% - nómina ~10% NULL (DQ)
        IF ABS(CHECKSUM(NEWID()))%10 < 4
        BEGIN
        DECLARE @BBAN_NOM NVARCHAR(20)=
                RIGHT('0000'+CAST(ABS(@pID*7+1234)%10000 AS VARCHAR(4)),4)+
                RIGHT('0000'+CAST(ABS(@pID*3+5678)%10000 AS VARCHAR(4)),4)+
                '00'+RIGHT('0000000000'+CAST(3000000000+@pID*97 AS VARCHAR(10)),10);
        DECLARE @IBAN_NOM NVARCHAR(24)='ES'+Banca.fn_CalcIBANCheckDigits(@BBAN_NOM)+@BBAN_NOM;
            DECLARE @ImpNomina DECIMAL(18,2) = CASE WHEN @pID%10=0 THEN NULL  -- ~10% NULL (DQ)
                ELSE CAST(1000+ABS(CHECKSUM(NEWID()))%3500 AS DECIMAL(18,2)) END;
            IF NOT EXISTS (SELECT 1 FROM Cuenta.CuentasNomina WHERE NumeroCuenta=@IBAN_NOM)
                INSERT INTO Cuenta.CuentasNomina (NumeroCuenta,TipoCuentaID,ProductoID,FechaApertura,
                    SaldoActual,SaldoDisponible,ImporteNominaUltimaMes,FechaUltimaNomina,
                    TieneNominaDomiciliada,BonificacionesAplicadas,EstadoCuenta,FechaModificacion)
                VALUES (@IBAN_NOM,5,@ProdCN,@Fecha,
                    CAST(ABS(CHECKSUM(NEWID()))%3000 AS DECIMAL(18,2)),
                    CAST(ABS(CHECKSUM(NEWID()))%3000 AS DECIMAL(18,2)),
                    @ImpNomina,
                    CASE WHEN @ImpNomina IS NOT NULL THEN DATEADD(DAY,-(ABS(CHECKSUM(NEWID()))%31),@Fecha) ELSE NULL END,
                    1,CAST(ABS(CHECKSUM(NEWID()))%100 AS DECIMAL(18,2)),'Activa',@Fecha);
        END

        FETCH NEXT FROM cCli INTO @pID,@seg;
    END
    CLOSE cCli; DEALLOCATE cCli;
END;
GO

-- SP 4: AddMovimientos - 50 cuentas/día × 3 movs × multiplicador anual
-- También actualiza PerfilTransaccional el día 1 de cada mes
CREATE PROCEDURE Banca.AddMovimientos
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha DATE = CAST(@CurrentDateTime AS DATE);
    -- Multiplicador anual igual que WWI (crecimiento negocio)
    DECLARE @Mult DECIMAL(5,2) = CASE YEAR(@Fecha)
        WHEN 2013 THEN 1.00 WHEN 2014 THEN 1.12 WHEN 2015 THEN 1.21
        WHEN 2016 THEN 1.26 WHEN 2017 THEN 1.30 WHEN 2018 THEN 1.35
        WHEN 2019 THEN 1.40 WHEN 2020 THEN 1.20  -- caída COVID
        WHEN 2021 THEN 1.35 WHEN 2022 THEN 1.42
        ELSE 1.45 END;
    DECLARE @NCuentas INT = CAST(500 * @Mult AS INT);

    -- Movimientos en cuentas corrientes aleatorias
    INSERT INTO Cuenta.MovimientosCuenta (NumeroCuenta,FechaMovimiento,FechaValor,
        TipoMovimiento,Concepto,ImporteMovimiento,SaldoDespuesMovimiento,
        CanalOperacion,FechaModificacion)
    SELECT cc.NumeroCuenta,@Fecha,@Fecha,
        (SELECT TOP(1) v FROM (VALUES
            ('Transferencia Recibida'),('Transferencia Recibida'),
            ('Transferencia Emitida'),('Transferencia Emitida'),
            ('Domiciliación'),('Domiciliación'),('Domiciliación'),
            ('Nómina'),('Cajero'),('Compra TPV'),
            ('Comisión'),('Cuota Préstamo'),('Intereses'),('Cargo')
        ) AS q(v) ORDER BY NEWID()),
        (SELECT TOP(1) v FROM (VALUES
            ('Pago recibo luz'),('Compra supermercado'),('Transferencia'),
            ('Retirada cajero'),('Cuota hipoteca'),('Gasolinera'),
            ('Restaurante'),('Seguro'),('Varios')
        ) AS q(v) ORDER BY NEWID()),
        CASE WHEN ABS(CHECKSUM(NEWID()))%3=0
             THEN  CAST(10+ABS(CHECKSUM(NEWID()))%3000 AS DECIMAL(18,2))
             ELSE -CAST(10+ABS(CHECKSUM(NEWID()))%500  AS DECIMAL(18,2)) END,
        cc.SaldoActual+CAST(ABS(CHECKSUM(NEWID()))%1000-500 AS DECIMAL(18,2)),
        (SELECT TOP(1) v FROM (VALUES
            ('App Móvil'),('App Móvil'),('Web'),('Web'),('Oficina'),('Cajero')
        ) AS q(v) ORDER BY NEWID()),
        @Fecha
    FROM (SELECT TOP(@NCuentas) NumeroCuenta,SaldoActual
          FROM Cuenta.CuentasCorrientes WHERE EstadoCuenta='Activa'
          ORDER BY NEWID()) cc
    CROSS JOIN (SELECT TOP(3) ROW_NUMBER() OVER (ORDER BY object_id) n FROM sys.objects) nums
    WHERE nums.n <= 1 + ABS(CHECKSUM(NEWID()))%3;

    -- PerfilTransaccional: día 1 de cada mes, 100 clientes aleatorios
    IF DAY(@Fecha)=1
        INSERT INTO Cliente.PerfilTransaccional (PersonaID,NumeroTransaccionesMes,
            ImportePromedioTransaccion,VolumenMensualOperaciones,
            NumeroTransferenciasInternacionales,TieneOperativaInusual,FechaUltimaActualizacion)
        SELECT p.PersonaID,
            5+ABS(CHECKSUM(NEWID()))%45,
            CAST(50+ABS(CHECKSUM(NEWID()))%950 AS DECIMAL(18,2)),
            CAST(500+ABS(CHECKSUM(NEWID()))%9500 AS DECIMAL(18,2)),
            ABS(CHECKSUM(NEWID()))%5,
            CASE WHEN p.PersonaID%20=0 THEN 1 ELSE 0 END,
            @Fecha
        FROM (SELECT TOP 500 PersonaID FROM Cliente.Personas
              WHERE EsClienteActivo=1 ORDER BY NEWID()) p
        WHERE NOT EXISTS (SELECT 1 FROM Cliente.PerfilTransaccional pt WHERE pt.PersonaID=p.PersonaID);
END;
GO

-- SP 5: AddOperacionesCredito
-- Préstamos personales: Lun+Mié+Vie (SIN restricción NOT EXISTS = múltiples/cliente)
-- Hipotecas:           Lun+Vie (CON NOT EXISTS = 1 máximo/cliente)
-- Consumo:             Mar+Jue (SIN restricción)
-- Líneas crédito:      1/semana, solo empresas
-- LTV >80% ~3% (DQ), Cuota impagada DiasRetraso=0 ~5% (DQ)
CREATE PROCEDURE Banca.AddOperacionesCredito
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT,
    @PctDQ           INT = 15
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha     DATE = CAST(@CurrentDateTime AS DATE);
    DECLARE @DiaSemana INT  = DATEPART(WEEKDAY,@Fecha);

    -- ── Préstamos personales: Lun(2) Mié(4) Vie(6) ──
    IF @DiaSemana IN (2,4,6)
    BEGIN
        DECLARE @ProdPC  INT=(SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='PC-001');
        DECLARE @SeqPRE  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroContrato,6) AS INT)) FROM Credito.Prestamos),0)+1;
        DECLARE @NConPRE NVARCHAR(50)='PRE-'+RIGHT('000000'+CAST(@SeqPRE AS VARCHAR(6)),6);
        -- SIN NOT EXISTS: un cliente puede tener varios préstamos personales
        DECLARE @CliPRE  INT;
        SELECT TOP(1) @CliPRE=PersonaID FROM Cliente.Personas WHERE EsClienteActivo=1 ORDER BY NEWID();
        IF @CliPRE IS NOT NULL
        BEGIN
            DECLARE @ImpPRE  DECIMAL(18,2)=CAST(3000+ABS(CHECKSUM(NEWID()))%27000 AS DECIMAL(18,2));
            DECLARE @PlazPRE INT=12+ABS(CHECKSUM(NEWID()))%72;
            DECLARE @EstPRE  NVARCHAR(50)=CASE WHEN @CliPRE%20=0 THEN 'Dudoso'
                WHEN @CliPRE%15=0 THEN 'Vencido' WHEN @CliPRE%40=0 THEN 'Cancelado' ELSE 'Vigente' END;
            DECLARE @CuotPRE DECIMAL(18,2)=CAST(@ImpPRE/@PlazPRE AS DECIMAL(18,2));
            DECLARE @SucPRE  INT=(SELECT TOP 1 SucursalID FROM Organizacion.Sucursales ORDER BY NEWID());

            INSERT INTO Credito.Prestamos (NumeroContrato,PersonaID,ProductoID,
                ImporteConcedido,ImportePendiente,TINAplicado,TAEAplicado,TipoInteres,
                PlazoMeses,FrecuenciaPago,ImporteCuota,FechaFormalizacion,
                FechaPrimerVencimiento,FechaUltimoVencimiento,EstadoPrestamo,
                SucursalGestion,FechaModificacion)
            VALUES (@NConPRE,@CliPRE,@ProdPC,@ImpPRE,@ImpPRE*0.9,6.000,6.200,'Fijo',
                @PlazPRE,'Mensual',@CuotPRE,@Fecha,DATEADD(MONTH,1,@Fecha),
                DATEADD(MONTH,@PlazPRE,@Fecha),@EstPRE,@SucPRE,@Fecha);
            DECLARE @PRE_ID INT=SCOPE_IDENTITY();

            -- 12 cuotas iniciales
            INSERT INTO Credito.CuotasPrestamo (NumeroContrato,NumeroCuota,FechaVencimiento,
                ImporteCuota,ImporteCapital,ImporteIntereses,ImporteComisiones,CapitalPendiente,
                FechaPago,ImportePagado,EstadoCuota,DiasRetraso)
            SELECT @NConPRE,n,DATEADD(MONTH,n,@Fecha),@CuotPRE,
                CAST(@CuotPRE*0.85 AS DECIMAL(18,2)),CAST(@CuotPRE*0.15 AS DECIMAL(18,2)),0,
                CAST(@ImpPRE-@CuotPRE*0.85*(n-1) AS DECIMAL(18,2)),
                CASE WHEN n<=3 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN DATEADD(MONTH,n,@Fecha) ELSE NULL END,
                CASE WHEN n<=3 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN @CuotPRE ELSE NULL END,
                CASE WHEN n<=3 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN 'Pagada'
                     WHEN @EstPRE='Dudoso' AND n=4 THEN 'Impagada' ELSE 'Pendiente' END,
                -- DiasRetraso=0 en impagada: ~5% (DQ)
                CASE WHEN @EstPRE='Dudoso' AND n=4
                     THEN CASE WHEN @PRE_ID%20=0 THEN 0 ELSE 30+ABS(CHECKSUM(NEWID()))%60 END
                     ELSE 0 END
            FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),
                        (13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24)) AS v(n);
        END
    END

    -- ── Hipotecas: Lun(2) Vie(6) - 1 máxima por cliente ──
    IF @DiaSemana IN (2,6)
    BEGIN
        DECLARE @ProdHIP INT=(SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='PH-001');
        DECLARE @SeqHIP  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroContrato,6) AS INT)) FROM Credito.PrestamosHipotecarios),0)+1;
        DECLARE @NConHIP NVARCHAR(50)='HIP-'+RIGHT('000000'+CAST(@SeqHIP AS VARCHAR(6)),6);
        DECLARE @CliHIP  INT;
        -- SIN restricción: múltiples hipotecas por cliente (realista)
        SELECT TOP(1) @CliHIP=PersonaID FROM Cliente.Personas WHERE EsClienteActivo=1 ORDER BY NEWID();
        IF @CliHIP IS NOT NULL
        BEGIN
            DECLARE @ImpHIP  DECIMAL(18,2)=CAST(80000+ABS(CHECKSUM(NEWID()))%320000 AS DECIMAL(18,2));
            DECLARE @TasHIP  DECIMAL(18,2)=@ImpHIP*(1.0+CAST(ABS(CHECKSUM(NEWID()))%30 AS DECIMAL(5,2))/100.0);
            DECLARE @TIntHIP NVARCHAR(50)=CASE WHEN ABS(CHECKSUM(NEWID()))%4=0 THEN 'Fijo' ELSE 'Variable' END;
            DECLARE @PlazoH  INT=240+ABS(CHECKSUM(NEWID()))%120;
            -- LTV: ~3% > 80% (DQ)
            DECLARE @LTV DECIMAL(5,2)=CASE WHEN @CliHIP%33=0
                THEN CAST(80+ABS(CHECKSUM(NEWID()))%20 AS DECIMAL(5,2))
                ELSE CAST(40+ABS(CHECKSUM(NEWID()))%40 AS DECIMAL(5,2)) END;

            INSERT INTO Credito.PrestamosHipotecarios (NumeroContrato,PersonaID,ProductoID,
                ImporteConcedido,ImportePendiente,TINAplicado,TAEAplicado,TipoInteres,
                IndiceReferencia,DiferencialAplicado,PlazoMeses,ImporteCuota,
                ValorTasacionInmueble,DireccionInmueble,LTVPorcentaje,
                TieneSeguroVida,TieneSeguroHogar,FechaFormalizacion,
                FechaPrimerVencimiento,FechaUltimoVencimiento,EstadoPrestamo,FechaModificacion)
            VALUES (@NConHIP,@CliHIP,@ProdHIP,@ImpHIP,@ImpHIP*0.95,
                CASE @TIntHIP WHEN 'Fijo' THEN 2.500 ELSE 1.800 END,
                CASE @TIntHIP WHEN 'Fijo' THEN 2.600 ELSE 1.900 END,
                @TIntHIP,
                CASE @TIntHIP WHEN 'Variable' THEN 'Euribor 12M' ELSE NULL END,
                CASE @TIntHIP WHEN 'Variable' THEN 0.900 ELSE NULL END,
                @PlazoH,CAST(@ImpHIP*0.95/@PlazoH AS DECIMAL(18,2)),
                @TasHIP,'Calle Mayor '+CAST(ABS(CHECKSUM(NEWID()))%200 AS NVARCHAR(10))+', Madrid',
                @LTV,CASE WHEN ABS(CHECKSUM(NEWID()))%4>0 THEN 1 ELSE 0 END,
                CASE WHEN ABS(CHECKSUM(NEWID()))%3>0 THEN 1 ELSE 0 END,
                @Fecha,DATEADD(MONTH,1,@Fecha),DATEADD(YEAR,20+ABS(CHECKSUM(NEWID()))%10,@Fecha),
                'Vigente',@Fecha);

            -- Garantía hipotecaria
            INSERT INTO Credito.Garantias (NumeroContrato,TipoGarantiaID,DescripcionGarantia,
                ValorTasacion,FechaTasacion,EntidadTasadora,DireccionGarantia,
                TieneSeguro,FechaConstitucion,EstadoGarantia)
            VALUES (@NConHIP,1,'Hipoteca sobre inmueble residencial',@TasHIP,@Fecha,
                (SELECT TOP(1) v FROM (VALUES('Tasaciones SA'),('Valtecnic'),('Tinsa'),('Alia Tasaciones')) AS q(v) ORDER BY NEWID()),
                'Calle Mayor '+CAST(ABS(CHECKSUM(NEWID()))%200 AS NVARCHAR(10))+', Madrid',
                1,@Fecha,'Vigente');

            -- 24 cuotas hipoteca (más volumen en CuotasPrestamo)
            DECLARE @CuotHIP DECIMAL(18,2)=CAST(@ImpHIP*0.95/@PlazoH AS DECIMAL(18,2));
            INSERT INTO Credito.CuotasPrestamo (NumeroContrato,NumeroCuota,FechaVencimiento,
                ImporteCuota,ImporteCapital,ImporteIntereses,ImporteComisiones,CapitalPendiente,
                FechaPago,ImportePagado,EstadoCuota,DiasRetraso)
            SELECT @NConHIP,n,DATEADD(MONTH,n,@Fecha),@CuotHIP,
                CAST(@CuotHIP*0.85 AS DECIMAL(18,2)),CAST(@CuotHIP*0.15 AS DECIMAL(18,2)),0,
                CAST(@ImpHIP*0.95-@CuotHIP*0.85*(n-1) AS DECIMAL(18,2)),
                CASE WHEN n<=6 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN DATEADD(MONTH,n,@Fecha) ELSE NULL END,
                CASE WHEN n<=6 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN @CuotHIP ELSE NULL END,
                CASE WHEN n<=6 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN 'Pagada' ELSE 'Pendiente' END,0
            FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),
                        (13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24)) AS v(n);
        END
    END

    -- ── Préstamos consumo: Mar(3) Jue(5) - sin restricción ──
    IF @DiaSemana IN (3,5)
    BEGIN
        DECLARE @ProdPCO INT=(SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='PC-001');
        DECLARE @SeqPCO  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroContrato,6) AS INT)) FROM Credito.PrestamosConsumo),0)+1;
        DECLARE @NConPCO NVARCHAR(50)='PCO-'+RIGHT('000000'+CAST(@SeqPCO AS VARCHAR(6)),6);
        DECLARE @CliPCO  INT;
        SELECT TOP(1) @CliPCO=PersonaID FROM Cliente.Personas WHERE EsClienteActivo=1 ORDER BY NEWID();
        IF @CliPCO IS NOT NULL
        BEGIN
            DECLARE @ImpPCO  DECIMAL(18,2)=CAST(500+ABS(CHECKSUM(NEWID()))%9500 AS DECIMAL(18,2));
            DECLARE @PlazPCO INT=6+ABS(CHECKSUM(NEWID()))%54;
            DECLARE @EstPCO  NVARCHAR(50)=CASE WHEN @CliPCO%15=0 THEN 'Vencido'
                WHEN @CliPCO%30=0 THEN 'Cancelado' ELSE 'Vigente' END;
            DECLARE @CuotPCO DECIMAL(18,2)=CAST(@ImpPCO/@PlazPCO AS DECIMAL(18,2));

            INSERT INTO Credito.PrestamosConsumo (NumeroContrato,PersonaID,ProductoID,
                ImporteConcedido,ImportePendiente,TINAplicado,TAEAplicado,Finalidad,
                PlazoMeses,ImporteCuota,FechaFormalizacion,FechaPrimerVencimiento,
                FechaUltimoVencimiento,EstadoPrestamo,FechaModificacion)
            VALUES (@NConPCO,@CliPCO,@ProdPCO,@ImpPCO,@ImpPCO*0.85,7.500,7.800,
                (SELECT TOP(1) v FROM (VALUES('Vacaciones'),('Electrodomésticos'),('Vehículo'),('Reformas'),('Estudios'),('Varios')) AS q(v) ORDER BY NEWID()),
                @PlazPCO,@CuotPCO,@Fecha,DATEADD(MONTH,1,@Fecha),
                DATEADD(MONTH,@PlazPCO,@Fecha),@EstPCO,@Fecha);

            -- 6 cuotas consumo
            INSERT INTO Credito.CuotasPrestamo (NumeroContrato,NumeroCuota,FechaVencimiento,
                ImporteCuota,ImporteCapital,ImporteIntereses,ImporteComisiones,CapitalPendiente,
                FechaPago,ImportePagado,EstadoCuota,DiasRetraso)
            SELECT @NConPCO,n,DATEADD(MONTH,n,@Fecha),@CuotPCO,
                CAST(@CuotPCO*0.85 AS DECIMAL(18,2)),CAST(@CuotPCO*0.15 AS DECIMAL(18,2)),0,
                CAST(@ImpPCO-@CuotPCO*0.85*(n-1) AS DECIMAL(18,2)),
                CASE WHEN n<=2 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN DATEADD(MONTH,n,@Fecha) ELSE NULL END,
                CASE WHEN n<=2 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN @CuotPCO ELSE NULL END,
                CASE WHEN n<=2 AND DATEADD(MONTH,n,@Fecha)<=@Fecha THEN 'Pagada' ELSE 'Pendiente' END,0
            FROM (VALUES(1),(2),(3),(4),(5),(6)) AS v(n);
        END
    END

    -- ── Líneas de crédito: 1/semana, solo empresas ──
    IF @DiaSemana=4 -- miércoles
    BEGIN
        DECLARE @ProdLC  INT=(SELECT TOP 1 ProductoID FROM Producto.CatalogoProductos WHERE CodigoProducto='LC-001');
        DECLARE @SeqLC   INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroLinea,6) AS INT)) FROM Credito.LineaCredito),0)+1;
        DECLARE @NLinea  NVARCHAR(50)='LC-'+RIGHT('000000'+CAST(@SeqLC AS VARCHAR(6)),6);
        DECLARE @EmpLC   INT;
        SELECT TOP(1) @EmpLC=PersonaJuridicaID FROM Cliente.PersonasJuridicas
            WHERE EsClienteActivo=1 ORDER BY NEWID();
        IF @EmpLC IS NOT NULL
        BEGIN
            DECLARE @LimLC DECIMAL(18,2)=CAST(10000+ABS(CHECKSUM(NEWID()))%240000 AS DECIMAL(18,2));
            DECLARE @DispLC DECIMAL(18,2)=@LimLC*CAST(ABS(CHECKSUM(NEWID()))%100 AS DECIMAL(5,2))/100.0;
            INSERT INTO Credito.LineaCredito (NumeroLinea,PersonaJuridicaID,ProductoID,
                LimiteCredito,SaldoDispuesto,SaldoDisponible,TINAplicado,
                ComisionApertura,ComisionDisponibilidad,FechaApertura,FechaVencimiento,
                FechaRevision,EstadoLinea,FechaModificacion)
            VALUES (@NLinea,@EmpLC,@ProdLC,@LimLC,@DispLC,@LimLC-@DispLC,4.500,
                CAST(@LimLC*0.005 AS DECIMAL(18,2)),CAST(@LimLC*0.001 AS DECIMAL(18,2)),
                @Fecha,DATEADD(YEAR,1,@Fecha),DATEADD(MONTH,6,@Fecha),'Activa',@Fecha);
        END
    END
END;
GO

-- SP 6: AddTransferenciasCompleto - internas + externas + SEPA + rechazadas
-- 15 internas + 5 externas + 3 SEPA (días pares) + 1 rechazada (1/semana)
CREATE PROCEDURE Banca.AddTransferenciasCompleto
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha   DATE = CAST(@CurrentDateTime AS DATE);
    DECLARE @SeqTRI  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroOperacion,6) AS INT)) FROM Transferencia.TransferenciasInternas),0);
    DECLARE @SeqTRE  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroOperacion,6) AS INT)) FROM Transferencia.TransferenciasExternas),0);
    DECLARE @SeqSEPA INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroOperacion,6) AS INT)) FROM Transferencia.TransferenciasSEPA),0);
    DECLARE @SeqREJ  INT=ISNULL((SELECT MAX(CAST(RIGHT(NumeroOperacion,6) AS INT)) FROM Transferencia.OrdenesRechazadas),0);

    -- Pares cuentas origen-destino
    DECLARE @Pares TABLE (rn INT IDENTITY(1,1), cO NVARCHAR(24), cD NVARCHAR(24));
    INSERT INTO @Pares (cO,cD)
    SELECT TOP 200 c1.NumeroCuenta,c2.NumeroCuenta
    FROM (SELECT TOP 400 NumeroCuenta,ROW_NUMBER() OVER (ORDER BY NEWID()) rn FROM Cuenta.CuentasCorrientes WHERE EstadoCuenta='Activa') c1
    JOIN (SELECT TOP 400 NumeroCuenta,ROW_NUMBER() OVER (ORDER BY NEWID()) rn FROM Cuenta.CuentasCorrientes WHERE EstadoCuenta='Activa') c2
      ON c1.rn=c2.rn AND c1.NumeroCuenta<>c2.NumeroCuenta;

    -- Transferencias internas (15/día)
    INSERT INTO Transferencia.TransferenciasInternas (NumeroOperacion,CuentaOrigen,CuentaDestino,
        ImporteTransferencia,Concepto,FechaOperacion,FechaValor,EstadoTransferencia,
        CanalOperacion,FechaModificacion)
    SELECT TOP 150
        'TRI-'+RIGHT('000000'+CAST(@SeqTRI+rn AS VARCHAR(6)),6),
        cO,cD,CAST(10+ABS(CHECKSUM(NEWID()))%9990 AS DECIMAL(18,2)),
        (SELECT TOP(1) v FROM (VALUES('Pago alquiler'),('Transferencia familiar'),
            ('Pago factura'),('Reembolso'),('Entre cuentas'),('Pago servicios')) AS q(v) ORDER BY NEWID()),
        @Fecha,@Fecha,
        CASE WHEN rn%20=0 THEN 'Rechazada' ELSE 'Ejecutada' END,
        (SELECT TOP(1) v FROM (VALUES('App Móvil'),('App Móvil'),('Web'),('Web'),('Oficina'),('Cajero')) AS q(v) ORDER BY NEWID()),
        @Fecha
    FROM @Pares;

    -- Transferencias externas (5/día)
    INSERT INTO Transferencia.TransferenciasExternas (NumeroOperacion,CuentaOrigen,IBANDestino,
        EntidadDestino,ImporteTransferencia,Concepto,BeneficiarioNombre,
        FechaOperacion,FechaValor,ComisionAplicada,EstadoTransferencia,CanalOperacion,FechaModificacion)
    SELECT TOP 50
        'TRE-'+RIGHT('000000'+CAST(@SeqTRE+rn AS VARCHAR(6)),6),
        cO,
        'ES'+RIGHT('00'+CAST(21+ABS(CHECKSUM(NEWID()))%79 AS VARCHAR(2)),2)
           +RIGHT('0000'+CAST(ABS(CHECKSUM(NEWID()))%10000 AS VARCHAR(4)),4)
           +RIGHT('00'+CAST(ABS(CHECKSUM(NEWID()))%100 AS VARCHAR(2)),2)
           +RIGHT('0000000000'+CAST(ABS(CHECKSUM(NEWID()))%9999999999 AS VARCHAR(10)),10),
        (SELECT TOP(1) v FROM (VALUES('Banco Santander'),('BBVA'),('CaixaBank'),('Bankinter'),('ING')) AS q(v) ORDER BY NEWID()),
        CAST(50+ABS(CHECKSUM(NEWID()))%4950 AS DECIMAL(18,2)),
        (SELECT TOP(1) v FROM (VALUES('Pago proveedor'),('Transferencia'),('Factura'),('Liquidación')) AS q(v) ORDER BY NEWID()),
        (SELECT TOP(1) v FROM (VALUES('Ana García'),('Luis Pérez'),('Carmen López'),('Pedro Martín'),('Empresa SL')) AS q(v) ORDER BY NEWID()),
        @Fecha,@Fecha,CAST(CAST(ABS(CHECKSUM(NEWID()))%300 AS DECIMAL(18,2))/100.0 AS DECIMAL(18,2)),
        CASE WHEN rn%10=0 THEN 'Rechazada' ELSE 'Ejecutada' END,
        (SELECT TOP(1) v FROM (VALUES('App Móvil'),('Web'),('Oficina')) AS q(v) ORDER BY NEWID()),@Fecha
    FROM @Pares;

    -- SEPA: 3/día en días pares
    IF DAY(@Fecha)%2=0
        INSERT INTO Transferencia.TransferenciasSEPA (NumeroOperacion,CuentaOrigen,IBANDestino,
            BICDestino,PaisDestino,ImporteTransferencia,Concepto,BeneficiarioNombre,
            TipoSEPA,FechaOperacion,FechaValor,ComisionAplicada,EstadoTransferencia)
        SELECT TOP 20
            'SEPA-'+RIGHT('000000'+CAST(@SeqSEPA+rn AS VARCHAR(6)),6),
            cO,
            (SELECT TOP(1) v FROM (VALUES('DE89370400440532013000'),('FR7614508359952742033X'),('IT60X0542811101000000123456'),('PT50000201231234567890154')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('DEUTDEDB'),('BNPAFRPP'),('BCITITMM'),('BPPIPT')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('DE'),('FR'),('IT'),('PT')) AS q(v) ORDER BY NEWID()),
            CAST(100+ABS(CHECKSUM(NEWID()))%9900 AS DECIMAL(18,2)),
            'Pago internacional','Beneficiario Internacional',
            (SELECT TOP(1) v FROM (VALUES('SCT'),('SCT'),('INST'),('B2B')) AS q(v) ORDER BY NEWID()),
            @Fecha,@Fecha,
            CAST(CAST(50+ABS(CHECKSUM(NEWID()))%200 AS DECIMAL(18,2))/100.0 AS DECIMAL(18,2)),
            'Ejecutada'
        FROM @Pares;

    -- Orden rechazada: 1/semana (miércoles)
    IF DATEPART(WEEKDAY,@Fecha)=4
        INSERT INTO Transferencia.OrdenesRechazadas (NumeroOperacion,CuentaOrigen,CuentaDestino,
            ImporteIntentado,FechaRechazo,MotivoRechazo,CodigoRechazo,TipoOperacion)
        SELECT TOP 1
            'REJ-'+RIGHT('000000'+CAST(@SeqREJ+1 AS VARCHAR(6)),6),
            cO,cD,CAST(10+ABS(CHECKSUM(NEWID()))%4990 AS DECIMAL(18,2)),@Fecha,
            (SELECT TOP(1) v FROM (VALUES('Saldo insuficiente'),('IBAN inválido'),('Cuenta bloqueada'),('Límite diario superado'),('Datos incorrectos')) AS q(v) ORDER BY NEWID()),
            (SELECT TOP(1) v FROM (VALUES('ERR001'),('ERR002'),('ERR003'),('ERR004'),('ERR005')) AS q(v) ORDER BY NEWID()),
            'Transferencia'
        FROM @Pares;
END;
GO

-- SP 7: AddRiesgoAmpliado - alertas + CIRBE + provisiones + dudosos (fin de mes)
-- Alerta sin importe ~30% (DQ), sin resolución ~50% pendientes (DQ)
CREATE PROCEDURE Banca.AddRiesgoAmpliado
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Fecha DATE = CAST(@CurrentDateTime AS DATE);

    -- Alerta blanqueo: ~1/50 días
    IF ABS(CHECKSUM(NEWID()))%50=0
    BEGIN
        DECLARE @CliAlerta INT;
        SELECT TOP(1) @CliAlerta=PersonaID FROM Cliente.Personas WHERE EsClienteActivo=1 ORDER BY NEWID();
        IF @CliAlerta IS NOT NULL
        BEGIN
            DECLARE @EstAl NVARCHAR(50)=(SELECT TOP(1) v FROM (VALUES
                ('Pendiente'),('Pendiente'),('Pendiente'),
                ('En Investigación'),('En Investigación'),
                ('Resuelta'),('Resuelta'),('Resuelta'),('Resuelta'),('Resuelta')) AS q(v) ORDER BY NEWID());
            INSERT INTO Riesgo.AlertasBlanqueoCapitales (PersonaID,TipoAlerta,NivelGravedad,
                DescripcionAlerta,ImporteOperacion,FechaAlerta,EstadoAlerta,FechaResolucion,UsuarioAsignado)
            VALUES (@CliAlerta,
                (SELECT TOP(1) v FROM (VALUES('Operación inusual'),('Transferencia sospechosa'),('Fraccionamiento'),('Actividad atípica')) AS q(v) ORDER BY NEWID()),
                (SELECT TOP(1) v FROM (VALUES('Baja'),('Media'),('Alta'),('Crítica')) AS q(v) ORDER BY NEWID()),
                'Actividad transaccional fuera del patrón habitual del cliente',
                CASE WHEN @CliAlerta%3=0 THEN NULL  -- ~30% sin importe (DQ)
                     ELSE CAST(5000+ABS(CHECKSUM(NEWID()))%95000 AS DECIMAL(18,2)) END,
                @Fecha,@EstAl,
                CASE WHEN @EstAl IN ('Pendiente','En Investigación') THEN NULL  -- sin resolución (DQ)
                     ELSE DATEADD(DAY,ABS(CHECKSUM(NEWID()))%30,@Fecha) END,
                (SELECT TOP 1 'EMP-'+RIGHT('00000'+CAST(EmpleadoID AS VARCHAR(5)),5)
                 FROM Organizacion.Empleados ORDER BY NEWID()));
        END
    END

    -- Fin de mes: CIRBE + OperacionesCIRBE + Provisiones + Dudosos
    IF @Fecha=EOMONTH(@Fecha)
    BEGIN
        DECLARE @Periodo NVARCHAR(7)=CAST(YEAR(@Fecha) AS NVARCHAR(4))+'-'
            +RIGHT('0'+CAST(MONTH(@Fecha) AS NVARCHAR(2)),2);

        -- DeclaracionesCIRBE para todos los préstamos activos
        INSERT INTO Riesgo.DeclaracionesCIRBE (PersonaID,FechaDeclaracion,PeriodoDeclaracion,
            RiesgoDirecto,RiesgoIndirecto,RiesgoTotal,RiesgoDudoso,NumeroOperaciones,ClasificacionRiesgo)
        SELECT pr.PersonaID,@Fecha,@Periodo,
            pr.ImportePendiente,0,pr.ImportePendiente,
            CASE WHEN pr.EstadoPrestamo='Dudoso' THEN pr.ImportePendiente ELSE 0 END,
            1,CASE pr.EstadoPrestamo WHEN 'Dudoso' THEN 'Dudoso' WHEN 'Vigente' THEN 'Normal' ELSE 'Substandard' END
        FROM Credito.Prestamos pr
        WHERE pr.EstadoPrestamo IN ('Vigente','Dudoso','Vencido')
          AND NOT EXISTS (SELECT 1 FROM Riesgo.DeclaracionesCIRBE dc
                          WHERE dc.PersonaID=pr.PersonaID AND dc.PeriodoDeclaracion=@Periodo);

        -- OperacionesCIRBE (detalle)
        INSERT INTO Riesgo.OperacionesCIRBE (DeclaracionCIRBEID,EntidadFinancieraID,
            TipoOperacion,NaturalezaOperacion,ImporteOperacion,SaldoVivo,EsOperacionDudosa)
        SELECT dc.DeclaracionCIRBEID,
            (SELECT TOP 1 EntidadFinancieraID FROM Riesgo.EntidadesFinancieras ORDER BY NEWID()),
            'Préstamo Personal','Financiación',
            pr.ImporteConcedido,pr.ImportePendiente,
            CASE WHEN pr.EstadoPrestamo='Dudoso' THEN 1 ELSE 0 END
        FROM Riesgo.DeclaracionesCIRBE dc
        JOIN Credito.Prestamos pr ON pr.PersonaID=dc.PersonaID AND dc.PeriodoDeclaracion=@Periodo
        WHERE NOT EXISTS (SELECT 1 FROM Riesgo.OperacionesCIRBE oc WHERE oc.DeclaracionCIRBEID=dc.DeclaracionCIRBEID);

        -- ProvisionesContables para dudosos
        INSERT INTO Riesgo.ProvisionesContables (NumeroContrato,FechaProvision,TipoProvision,
            ImporteProvisionado,ImporteRecuperado,SaldoProvision,ClasificacionRiesgoID)
        SELECT pr.NumeroContrato,@Fecha,'Específica',
            CAST(pr.ImportePendiente*0.25 AS DECIMAL(18,2)),0,
            CAST(pr.ImportePendiente*0.25 AS DECIMAL(18,2)),4
        FROM Credito.Prestamos pr
        WHERE pr.EstadoPrestamo='Dudoso'
          AND NOT EXISTS (SELECT 1 FROM Riesgo.ProvisionesContables pv
                          WHERE pv.NumeroContrato=pr.NumeroContrato AND pv.FechaProvision=@Fecha);

        -- OperacionesDudosas
        INSERT INTO Riesgo.OperacionesDudosas (NumeroContrato,FechaDeclaracionDudosa,MotivoDudoso,
            ImporteDudoso,DiasImpago,ClasificacionRiesgoID,EstadoOperacion)
        SELECT pr.NumeroContrato,@Fecha,'Impago superior a 90 días',
            pr.ImportePendiente,90+ABS(CHECKSUM(NEWID()))%180,4,'Dudoso'
        FROM Credito.Prestamos pr
        WHERE pr.EstadoPrestamo='Dudoso'
          AND NOT EXISTS (SELECT 1 FROM Riesgo.OperacionesDudosas od WHERE od.NumeroContrato=pr.NumeroContrato);
    END
END;
GO

-- SP 8: AddProductoCatalogo - TarifasComisiones + CondicionesComerciales (día 1/mes)
CREATE PROCEDURE Banca.AddProductoCatalogo
    @CurrentDateTime DATETIME2(7),
    @IsSilentMode    BIT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF DAY(CAST(@CurrentDateTime AS DATE))<>1 RETURN;
    DECLARE @Fecha DATE = CAST(@CurrentDateTime AS DATE);

    INSERT INTO Producto.TarifasComisiones (ProductoID,TipoComision,DescripcionComision,
        ImporteFijo,PorcentajeVariable,ImporteMinimo,ImporteMaximo,BaseCalculo,Periodicidad,FechaVigenciaDesde)
    SELECT p.ProductoID,'Comisión mantenimiento','Comisión mensual de mantenimiento',
        CASE WHEN p.Comision IS NOT NULL THEN p.Comision ELSE 0 END,
        NULL,0,NULL,'Saldo medio mensual','Mensual',@Fecha
    FROM Producto.CatalogoProductos p WHERE p.EsComercializable=1
      AND NOT EXISTS (SELECT 1 FROM Producto.TarifasComisiones tc WHERE tc.ProductoID=p.ProductoID AND tc.FechaVigenciaDesde=@Fecha);

    INSERT INTO Producto.CondicionesComerciales (ProductoID,SegmentoClienteID,TipoCondicion,
        TAEOfertado,TINOfertado,ComisionApertura,BonificacionAplicable,FechaVigenciaDesde)
    SELECT p.ProductoID,s.SegmentoID,'Condición estándar',
        CASE WHEN p.TAE IS NOT NULL THEN CAST(p.TAE*(1.0-s.NivelRiesgo*0.05) AS DECIMAL(5,3)) ELSE NULL END,
        CASE WHEN p.TIN IS NOT NULL THEN CAST(p.TIN*(1.0-s.NivelRiesgo*0.05) AS DECIMAL(5,3)) ELSE NULL END,
        CASE WHEN p.Comision IS NOT NULL THEN CAST(p.Comision*(1.0-s.NivelRiesgo*0.1) AS DECIMAL(18,2)) ELSE 0 END,
        CAST(s.NivelRiesgo*2 AS DECIMAL(5,2)),@Fecha
    FROM Producto.CatalogoProductos p CROSS JOIN Cliente.Segmentos s WHERE p.EsComercializable=1
      AND NOT EXISTS (SELECT 1 FROM Producto.CondicionesComerciales cc
                      WHERE cc.ProductoID=p.ProductoID AND cc.SegmentoClienteID=s.SegmentoID AND cc.FechaVigenciaDesde=@Fecha);
END;
GO

-- SP 9: DailyProcessToCreateHistory - bucle día a día (idéntico a WWI)
CREATE PROCEDURE Banca.DailyProcessToCreateHistory
    @StartDate       DATE,
    @EndDate         DATE,
    @IsSilentMode    BIT,
    @AreDatesPrinted BIT,
    @PctDQ           INT = 15
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDateTime DATETIME2(7) = @StartDate;
    DECLARE @Weekday  INT;
    DECLARE @IsWeekday BIT;

    SET DATEFIRST 7;

    WHILE @CurrentDateTime <= @EndDate
    BEGIN
        IF @AreDatesPrinted<>0 OR @IsSilentMode=0
            PRINT SUBSTRING(DATENAME(weekday,@CurrentDateTime),1,3)
                  +' '+CONVERT(NVARCHAR(20),@CurrentDateTime,107);

        SET @Weekday   = DATEPART(weekday,@CurrentDateTime);
        SET @IsWeekday = CASE WHEN @Weekday IN (1,7) THEN 0 ELSE 1 END;

        IF @IsWeekday<>0
        BEGIN
            EXEC Banca.AddClientes      @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode,@PctDQ=@PctDQ;
            EXEC Banca.AddCuentas       @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode;
            EXEC Banca.AddMovimientos   @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode;
            EXEC Banca.AddTransferenciasCompleto @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode;
        END

        EXEC Banca.AddOperacionesCredito @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode,@PctDQ=@PctDQ;
        EXEC Banca.AddProductoCatalogo   @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode;
        EXEC Banca.AddRiesgoAmpliado     @CurrentDateTime=@CurrentDateTime,@IsSilentMode=@IsSilentMode;

        IF @IsSilentMode=0 PRINT N' ';
        SET @CurrentDateTime = DATEADD(day,1,@CurrentDateTime);
    END
END;
GO

-- SP 10: PopulateDataToCurrentDate - PUNTO DE ENTRADA (idéntico a WWI)
-- COALESCE(MAX(FechaMovimiento), '20121231') -> incremental automático
CREATE PROCEDURE Banca.PopulateDataToCurrentDate
    @IsSilentMode    BIT = 1,
    @AreDatesPrinted BIT = 1,
    @PctDQ           INT = 15
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentMaximumDate DATE =
        COALESCE((SELECT MAX(FechaMovimiento) FROM Cuenta.MovimientosCuenta),'20121231');
    DECLARE @StartingDate DATE = DATEADD(day,1,@CurrentMaximumDate);
    DECLARE @EndingDate   DATE = CAST(DATEADD(day,-1,SYSDATETIME()) AS DATE);

    IF @StartingDate>@EndingDate
    BEGIN
        PRINT 'Datos al día. Última fecha: '+CAST(@CurrentMaximumDate AS NVARCHAR(20));
        RETURN;
    END

    PRINT 'Banca.PopulateDataToCurrentDate ';
    PRINT 'Última fecha  : '+CAST(@CurrentMaximumDate AS NVARCHAR(20));
    PRINT 'Desde         : '+CAST(@StartingDate AS NVARCHAR(20));
    PRINT 'Hasta         : '+CAST(@EndingDate   AS NVARCHAR(20));
    PRINT 'Días          : '+CAST(DATEDIFF(day,@StartingDate,@EndingDate)+1 AS NVARCHAR(10));
    PRINT '% DQ          : '+CAST(@PctDQ AS NVARCHAR(10));

    EXEC Banca.CargarCatalogosSiVacio;

    EXEC Banca.DailyProcessToCreateHistory
        @StartDate=@StartingDate,@EndDate=@EndingDate,
        @IsSilentMode=@IsSilentMode,@AreDatesPrinted=@AreDatesPrinted,@PctDQ=@PctDQ;

    PRINT '';
    PRINT '================================================================================';
    PRINT 'RESUMEN FINAL';
    PRINT '================================================================================';
    SELECT Tabla,Filas FROM (
        SELECT 'Cliente.Personas'                 AS Tabla,COUNT(*) AS Filas FROM Cliente.Personas              UNION ALL
        SELECT 'Cliente.PersonasJuridicas',                  COUNT(*) FROM Cliente.PersonasJuridicas             UNION ALL
        SELECT 'Cliente.DatosDemograficos',                  COUNT(*) FROM Cliente.DatosDemograficos             UNION ALL
        SELECT 'Cliente.PreferenciasPrivacidad',             COUNT(*) FROM Cliente.PreferenciasPrivacidad         UNION ALL
        SELECT 'Cliente.PerfilTransaccional',                COUNT(*) FROM Cliente.PerfilTransaccional            UNION ALL
        SELECT 'Cuenta.CuentasCorrientes',                   COUNT(*) FROM Cuenta.CuentasCorrientes              UNION ALL
        SELECT 'Cuenta.CuentasAhorro',                       COUNT(*) FROM Cuenta.CuentasAhorro                  UNION ALL
        SELECT 'Cuenta.CuentasNomina',                       COUNT(*) FROM Cuenta.CuentasNomina                  UNION ALL
        SELECT 'Cuenta.MovimientosCuenta',                   COUNT(*) FROM Cuenta.MovimientosCuenta              UNION ALL
        SELECT 'Credito.Prestamos',                          COUNT(*) FROM Credito.Prestamos                     UNION ALL
        SELECT 'Credito.PrestamosHipotecarios',              COUNT(*) FROM Credito.PrestamosHipotecarios         UNION ALL
        SELECT 'Credito.PrestamosConsumo',                   COUNT(*) FROM Credito.PrestamosConsumo              UNION ALL
        SELECT 'Credito.LineaCredito',                       COUNT(*) FROM Credito.LineaCredito                  UNION ALL
        SELECT 'Credito.CuotasPrestamo',                     COUNT(*) FROM Credito.CuotasPrestamo                UNION ALL
        SELECT 'Credito.Garantias',                          COUNT(*) FROM Credito.Garantias                     UNION ALL
        SELECT 'Transferencia.TransferenciasInternas',       COUNT(*) FROM Transferencia.TransferenciasInternas   UNION ALL
        SELECT 'Transferencia.TransferenciasExternas',       COUNT(*) FROM Transferencia.TransferenciasExternas   UNION ALL
        SELECT 'Transferencia.TransferenciasSEPA',           COUNT(*) FROM Transferencia.TransferenciasSEPA       UNION ALL
        SELECT 'Transferencia.OrdenesRechazadas',            COUNT(*) FROM Transferencia.OrdenesRechazadas        UNION ALL
        SELECT 'Riesgo.AlertasBlanqueoCapitales',            COUNT(*) FROM Riesgo.AlertasBlanqueoCapitales        UNION ALL
        SELECT 'Riesgo.DeclaracionesCIRBE',                  COUNT(*) FROM Riesgo.DeclaracionesCIRBE              UNION ALL
        SELECT 'Riesgo.OperacionesCIRBE',                    COUNT(*) FROM Riesgo.OperacionesCIRBE                UNION ALL
        SELECT 'Riesgo.ProvisionesContables',                COUNT(*) FROM Riesgo.ProvisionesContables            UNION ALL
        SELECT 'Riesgo.OperacionesDudosas',                  COUNT(*) FROM Riesgo.OperacionesDudosas              UNION ALL
        SELECT 'Producto.TarifasComisiones',                 COUNT(*) FROM Producto.TarifasComisiones             UNION ALL
        SELECT 'Producto.CondicionesComerciales',            COUNT(*) FROM Producto.CondicionesComerciales
    ) r ORDER BY Filas DESC;

    PRINT ' Completado hasta '+CAST(@EndingDate AS NVARCHAR(20));
    PRINT '================================================================================';
END;
GO

PRINT '';
PRINT 'Ejecutar:';
PRINT '  EXEC Banca.PopulateDataToCurrentDate;';
GO
