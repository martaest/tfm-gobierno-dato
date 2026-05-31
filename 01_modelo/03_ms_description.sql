-- Carga las descripciones extendidas (MS_Description) de tablas y campos, que es
-- lo que luego alimenta el diccionario de datos.
-- Las descripciones de tabla se escriben a mano (una por tabla, explicando la capa)
-- y las de campo se generan recorriendo las columnas con un cursor.
-- Alcance: banca en Bronze/Silver/Gold y WWI en Silver/Gold; el Bronze de WWI no se
-- toca porque ya trae las descripciones originales de Microsoft.
-- Funciona como add-or-update: actualiza si ya existe y crea si no, sin borrar nada.
-- (El helper castea la descripcion a NVARCHAR(4000) porque sp_addextendedproperty
-- recibe el valor como sql_variant y este no admite nvarchar(max).)

-- HELPER: procedimiento add-or-update de MS_Description (se crea en cada BD)

-- BRONZE BANCA
USE WideWorldImporters;
GO
IF OBJECT_ID('dbo.sp_SetDesc','P') IS NOT NULL DROP PROCEDURE dbo.sp_SetDesc;
GO
CREATE PROCEDURE dbo.sp_SetDesc
    @schema SYSNAME, @table SYSNAME, @column SYSNAME = NULL, @desc NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @oid INT = OBJECT_ID(QUOTENAME(@schema)+'.'+QUOTENAME(@table));
    IF @oid IS NULL RETURN;  -- tabla no existe, ignora
    DECLARE @minor INT = 0;
    IF @column IS NOT NULL
        SELECT @minor = column_id FROM sys.columns WHERE object_id=@oid AND name=@column;
    IF @column IS NOT NULL AND @minor IS NULL RETURN;  -- columna no existe, ignora

    -- sql_variant no admite nvarchar(max): casteamos a 4000 (máx. Unicode)
    DECLARE @v NVARCHAR(4000) = CAST(@desc AS NVARCHAR(4000));

    IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id=@oid AND minor_id=ISNULL(@minor,0) AND name='MS_Description')
    BEGIN
        IF @column IS NULL
            EXEC sys.sp_updateextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table;
        ELSE
            EXEC sys.sp_updateextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table,@level2type=N'COLUMN',@level2name=@column;
    END
    ELSE
    BEGIN
        IF @column IS NULL
            EXEC sys.sp_addextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table;
        ELSE
            EXEC sys.sp_addextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table,@level2type=N'COLUMN',@level2name=@column;
    END
END;
GO

-- Descripciones de TABLA (Bronze Banca, capa = datos en bruto)
EXEC dbo.sp_SetDesc 'Cliente','Personas',NULL,N'BRONZE: datos operativos en bruto de clientes particulares (personas físicas). Origen transaccional sin transformar.';
EXEC dbo.sp_SetDesc 'Cliente','PersonasJuridicas',NULL,N'BRONZE: datos operativos en bruto de clientes empresa (personas jurídicas).';
EXEC dbo.sp_SetDesc 'Cliente','ScoreCrediticio',NULL,N'BRONZE: puntuación crediticia y nivel de riesgo en origen. Una fila por cálculo de score.';
EXEC dbo.sp_SetDesc 'Cliente','DireccionesFiscales',NULL,N'BRONZE: direcciones fiscales de clientes en bruto.';
EXEC dbo.sp_SetDesc 'Cliente','DocumentosIdentidad',NULL,N'BRONZE: documentos de identidad de clientes en bruto.';
EXEC dbo.sp_SetDesc 'Cliente','SegmentacionComercial',NULL,N'BRONZE: segmentación comercial del cliente en origen.';
EXEC dbo.sp_SetDesc 'Cliente','PerfilTransaccional',NULL,N'BRONZE: perfil de operativa transaccional del cliente.';
EXEC dbo.sp_SetDesc 'Cuenta','CuentasCorrientes',NULL,N'BRONZE: cuentas corrientes en bruto con saldos operativos, actualizado en tiempo real.';
EXEC dbo.sp_SetDesc 'Cuenta','CuentasAhorro',NULL,N'BRONZE: cuentas de ahorro en bruto con TAE e intereses devengados.';
EXEC dbo.sp_SetDesc 'Cuenta','CuentasNomina',NULL,N'BRONZE: cuentas nómina en bruto con domiciliación de salario.';
EXEC dbo.sp_SetDesc 'Cuenta','MovimientosCuenta',NULL,N'BRONZE: movimientos bancarios en bruto. Cada fila es una operación individual sobre una cuenta.';
EXEC dbo.sp_SetDesc 'Cuenta','TitularesCuenta',NULL,N'BRONZE: relación de titulares y cotitulares de cada cuenta.';
EXEC dbo.sp_SetDesc 'Cuenta','TiposCuenta',NULL,N'BRONZE: catálogo de tipos de cuenta.';
EXEC dbo.sp_SetDesc 'Credito','Prestamos',NULL,N'BRONZE: préstamos personales en bruto del sistema de crédito.';
EXEC dbo.sp_SetDesc 'Credito','PrestamosHipotecarios',NULL,N'BRONZE: préstamos hipotecarios en bruto con tasación y garantía inmobiliaria.';
EXEC dbo.sp_SetDesc 'Credito','CuotasPrestamo',NULL,N'BRONZE: cuadro de amortización (cuotas) de cada préstamo.';
EXEC dbo.sp_SetDesc 'Credito','Garantias',NULL,N'BRONZE: garantías asociadas a operaciones de crédito.';
EXEC dbo.sp_SetDesc 'Credito','Avales',NULL,N'BRONZE: avales de operaciones de crédito con avalista integrado.';
EXEC dbo.sp_SetDesc 'Credito','AmortizacionesPagadas',NULL,N'BRONZE: amortizaciones anticipadas pagadas sobre préstamos.';
EXEC dbo.sp_SetDesc 'Credito','TiposGarantia',NULL,N'BRONZE: catálogo de tipos de garantía.';
EXEC dbo.sp_SetDesc 'Transferencia','TransferenciasInternas',NULL,N'BRONZE: transferencias entre cuentas del propio banco.';
EXEC dbo.sp_SetDesc 'Transferencia','TransferenciasExternas',NULL,N'BRONZE: transferencias a otras entidades nacionales.';
EXEC dbo.sp_SetDesc 'Transferencia','TransferenciasSEPA',NULL,N'BRONZE: transferencias SEPA al espacio único europeo de pagos.';
EXEC dbo.sp_SetDesc 'Riesgo','OperacionesCIRBE',NULL,N'BRONZE: operaciones declaradas a la CIRBE del Banco de España.';
EXEC dbo.sp_SetDesc 'Riesgo','DeclaracionesCIRBE',NULL,N'BRONZE: cabeceras de declaración CIRBE por cliente y periodo.';
EXEC dbo.sp_SetDesc 'Riesgo','ProvisionesContables',NULL,N'BRONZE: provisiones contables dotadas por riesgo de crédito.';
EXEC dbo.sp_SetDesc 'Riesgo','ClasificacionesRiesgo',NULL,N'BRONZE: catálogo de clasificaciones de riesgo regulatorias.';
EXEC dbo.sp_SetDesc 'Riesgo','EntidadesFinancieras',NULL,N'BRONZE: catálogo de entidades financieras declarantes.';
EXEC dbo.sp_SetDesc 'Organizacion','Sucursales',NULL,N'BRONZE: red de oficinas y sucursales. Datos maestros organizativos.';
EXEC dbo.sp_SetDesc 'Organizacion','Empleados',NULL,N'BRONZE: plantilla de empleados con asignación a centros y departamentos.';
EXEC dbo.sp_SetDesc 'Organizacion','Departamentos',NULL,N'BRONZE: estructura de departamentos del banco.';
EXEC dbo.sp_SetDesc 'Organizacion','ZonasGeograficas',NULL,N'BRONZE: jerarquía de zonas geográficas comerciales.';
EXEC dbo.sp_SetDesc 'Producto','CatalogoProductos',NULL,N'BRONZE: catálogo maestro de productos financieros con condiciones.';
EXEC dbo.sp_SetDesc 'Producto','TiposProducto',NULL,N'BRONZE: catálogo de tipos de producto.';
EXEC dbo.sp_SetDesc 'Producto','CategoriasProducto',NULL,N'BRONZE: jerarquía de categorías de producto.';
EXEC dbo.sp_SetDesc 'Producto','TarifasComisiones',NULL,N'BRONZE: tarifas y comisiones por producto.';

-- CAMPOS Bronze Banca por patrón (cursor sobre tablas mapeadas)
DECLARE @s SYSNAME,@t SYSNAME,@c SYSNAME,@ty SYSNAME,@d NVARCHAR(500);
DECLARE cur CURSOR FOR
    SELECT sc.name, t.name, c.name, ty.name
    FROM sys.tables t
    JOIN sys.schemas sc ON t.schema_id=sc.schema_id
    JOIN sys.columns c ON t.object_id=c.object_id
    JOIN sys.types ty ON c.user_type_id=ty.user_type_id
    WHERE sc.name IN ('Cliente','Cuenta','Credito','Transferencia','Riesgo','Organizacion','Producto')
      AND t.name IN ('Personas','PersonasJuridicas','ScoreCrediticio','DireccionesFiscales','DocumentosIdentidad',
        'SegmentacionComercial','PerfilTransaccional','CuentasCorrientes','CuentasAhorro','CuentasNomina',
        'MovimientosCuenta','TitularesCuenta','TiposCuenta','Prestamos','PrestamosHipotecarios','CuotasPrestamo',
        'Garantias','Avales','AmortizacionesPagadas','TiposGarantia','TransferenciasInternas','TransferenciasExternas',
        'TransferenciasSEPA','OperacionesCIRBE','DeclaracionesCIRBE','ProvisionesContables','ClasificacionesRiesgo',
        'EntidadesFinancieras','Sucursales','Empleados','Departamentos','ZonasGeograficas','CatalogoProductos',
        'TiposProducto','CategoriasProducto','TarifasComisiones');
OPEN cur;
FETCH NEXT FROM cur INTO @s,@t,@c,@ty;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @d = CASE
        WHEN @c LIKE '%ID' AND @c NOT LIKE '%Tipo%' THEN 'Identificador único de '+@t+' (clave de negocio).'
        WHEN @c LIKE 'Fecha%' THEN 'Fecha de '+LOWER(REPLACE(@c,'Fecha',''))+'.'
        WHEN @c LIKE '%Importe%' OR @c LIKE '%Saldo%' THEN 'Importe monetario en euros.'
        WHEN @c LIKE '%Email%' THEN 'Correo electrónico de contacto.'
        WHEN @c LIKE '%Telefono%' THEN 'Número de teléfono de contacto.'
        WHEN @c LIKE '%Nombre%' OR @c LIKE '%RazonSocial%' THEN 'Denominación o nombre.'
        WHEN @c LIKE '%Estado%' THEN 'Estado o situación actual.'
        WHEN @ty='bit' THEN 'Indicador booleano (Sí/No).'
        ELSE 'Campo '+@c+' del sistema origen.'
    END;
    EXEC dbo.sp_SetDesc @s,@t,@c,@d;
    FETCH NEXT FROM cur INTO @s,@t,@c,@ty;
END;
CLOSE cur; DEALLOCATE cur;
PRINT 'Bronze Banca: tablas + campos OK';
GO

-- SILVER y GOLD (WideWorldImportersDW)
USE WideWorldImportersDW;
GO
IF OBJECT_ID('dbo.sp_SetDesc','P') IS NOT NULL DROP PROCEDURE dbo.sp_SetDesc;
GO
CREATE PROCEDURE dbo.sp_SetDesc
    @schema SYSNAME, @table SYSNAME, @column SYSNAME = NULL, @desc NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @oid INT = OBJECT_ID(QUOTENAME(@schema)+'.'+QUOTENAME(@table));
    IF @oid IS NULL RETURN;
    -- Saltar tablas memory-optimized: no admiten cambios de propiedades extendidas (msg 12320)
    IF EXISTS (SELECT 1 FROM sys.tables WHERE object_id=@oid AND is_memory_optimized=1) RETURN;
    DECLARE @minor INT = 0;
    IF @column IS NOT NULL
        SELECT @minor = column_id FROM sys.columns WHERE object_id=@oid AND name=@column;
    IF @column IS NOT NULL AND @minor IS NULL RETURN;

    -- sql_variant no admite nvarchar(max): casteamos a 4000 (máx. Unicode)
    DECLARE @v NVARCHAR(4000) = CAST(@desc AS NVARCHAR(4000));

    IF EXISTS (SELECT 1 FROM sys.extended_properties WHERE major_id=@oid AND minor_id=ISNULL(@minor,0) AND name='MS_Description')
    BEGIN
        IF @column IS NULL
            EXEC sys.sp_updateextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table;
        ELSE
            EXEC sys.sp_updateextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table,@level2type=N'COLUMN',@level2name=@column;
    END
    ELSE
    BEGIN
        IF @column IS NULL
            EXEC sys.sp_addextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table;
        ELSE
            EXEC sys.sp_addextendedproperty @name=N'MS_Description',@value=@v,@level0type=N'SCHEMA',@level0name=@schema,@level1type=N'TABLE',@level1name=@table,@level2type=N'COLUMN',@level2name=@column;
    END
END;
GO

-- ---------- TABLAS SILVER (Staging = datos limpios y desnormalizados) ----------
-- Banca
EXEC dbo.sp_SetDesc 'Integration','Cliente_Staging',NULL,N'SILVER: clientes limpios y unificados (físicas + jurídicas). UPPER/TRIM aplicado, edad calculada, desnormalizado.';
EXEC dbo.sp_SetDesc 'Integration','PerfilRiesgo_Staging',NULL,N'SILVER: perfil de riesgo del cliente consolidado y estandarizado.';
EXEC dbo.sp_SetDesc 'Integration','Cuenta_Staging',NULL,N'SILVER: cuentas unificadas (corriente + ahorro + nómina) con producto desnormalizado.';
EXEC dbo.sp_SetDesc 'Integration','Movimiento_Staging',NULL,N'SILVER: movimientos limpios y estandarizados, listos para carga incremental a Gold.';
EXEC dbo.sp_SetDesc 'Integration','SaldoDiario_Staging',NULL,N'SILVER: saldos diarios agregados por cuenta y fecha (GROUP BY de movimientos).';
EXEC dbo.sp_SetDesc 'Integration','Credito_Staging',NULL,N'SILVER: créditos unificados (préstamos + hipotecas) con cliente y producto desnormalizados.';
EXEC dbo.sp_SetDesc 'Integration','Cuota_Staging',NULL,N'SILVER: cuotas de préstamo limpias.';
EXEC dbo.sp_SetDesc 'Integration','Garantia_Staging',NULL,N'SILVER: garantías estandarizadas.';
EXEC dbo.sp_SetDesc 'Integration','Aval_Staging',NULL,N'SILVER: avales estandarizados.';
EXEC dbo.sp_SetDesc 'Integration','Transferencia_Staging',NULL,N'SILVER: transferencias unificadas (interna + externa + SEPA) con flags Es SEPA / Es Recurrente.';
EXEC dbo.sp_SetDesc 'Integration','CIRBE_Staging',NULL,N'SILVER: operaciones CIRBE estandarizadas con entidad y clasificación desnormalizadas.';
EXEC dbo.sp_SetDesc 'Integration','Provision_Staging',NULL,N'SILVER: provisiones contables limpias.';
EXEC dbo.sp_SetDesc 'Integration','ClasificacionRiesgo_Staging',NULL,N'SILVER: catálogo de clasificaciones de riesgo.';
EXEC dbo.sp_SetDesc 'Integration','EntidadFinanciera_Staging',NULL,N'SILVER: catálogo de entidades financieras.';
EXEC dbo.sp_SetDesc 'Integration','Centro_Staging',NULL,N'SILVER: centros/sucursales estandarizados.';
EXEC dbo.sp_SetDesc 'Integration','Empleado_Staging',NULL,N'SILVER: empleados estandarizados con centro y supervisor desnormalizados.';
EXEC dbo.sp_SetDesc 'Integration','Producto_Staging',NULL,N'SILVER: productos con tipo y categoría desnormalizados.';
-- WWI
EXEC dbo.sp_SetDesc 'Integration','City_Staging',NULL,N'SILVER: ciudades estandarizadas con provincia y país desnormalizados.';
EXEC dbo.sp_SetDesc 'Integration','Customer_Staging',NULL,N'SILVER: clientes WWI limpios con categoría y grupo de compra.';
EXEC dbo.sp_SetDesc 'Integration','StockItem_Staging',NULL,N'SILVER: artículos de stock estandarizados.';
EXEC dbo.sp_SetDesc 'Integration','Supplier_Staging',NULL,N'SILVER: proveedores estandarizados.';
EXEC dbo.sp_SetDesc 'Integration','Employee_Staging',NULL,N'SILVER: empleados WWI estandarizados.';
EXEC dbo.sp_SetDesc 'Integration','Movement_Staging',NULL,N'SILVER: movimientos de stock limpios.';
EXEC dbo.sp_SetDesc 'Integration','Order_Staging',NULL,N'SILVER: pedidos WWI con líneas desnormalizadas (JOIN Orders + OrderLines).';
EXEC dbo.sp_SetDesc 'Integration','Sale_Staging',NULL,N'SILVER: ventas WWI con facturas y líneas (JOIN Invoices + InvoiceLines).';
EXEC dbo.sp_SetDesc 'Integration','Purchase_Staging',NULL,N'SILVER: compras WWI desnormalizadas.';
EXEC dbo.sp_SetDesc 'Integration','Transaction_Staging',NULL,N'SILVER: transacciones financieras WWI.';
EXEC dbo.sp_SetDesc 'Integration','StockHolding_Staging',NULL,N'SILVER: existencias actuales de stock (snapshot).';
EXEC dbo.sp_SetDesc 'Integration','PaymentMethod_Staging',NULL,N'SILVER: métodos de pago.';
EXEC dbo.sp_SetDesc 'Integration','TransactionType_Staging',NULL,N'SILVER: tipos de transacción.';

-- ---------- TABLAS GOLD (Dimension = SCD2 / Fact = hechos) ----------
-- Dimensiones Banca
EXEC dbo.sp_SetDesc 'Dimension','Cliente',NULL,N'GOLD: dimensión de clientes con historial SCD Tipo 2. Cada cambio de segmento o datos crea una versión nueva conservando la anterior (foto histórica).';
EXEC dbo.sp_SetDesc 'Dimension','Cuenta',NULL,N'GOLD: dimensión de cuentas con SCD Tipo 2 sobre el estado. Vinculada a cliente por clave surrogada.';
EXEC dbo.sp_SetDesc 'Dimension','Producto',NULL,N'GOLD: dimensión de productos con SCD Tipo 2 sobre TAE/TIN. Conserva condiciones históricas.';
EXEC dbo.sp_SetDesc 'Dimension','PerfilRiesgo',NULL,N'GOLD: dimensión de perfil de riesgo con SCD Tipo 2 sobre score y nivel de riesgo.';
EXEC dbo.sp_SetDesc 'Dimension','Empleado',NULL,N'GOLD: dimensión de empleados con SCD Tipo 2 sobre puesto y estado.';
EXEC dbo.sp_SetDesc 'Dimension','Centro',NULL,N'GOLD: dimensión de centros con SCD Tipo 2.';
EXEC dbo.sp_SetDesc 'Dimension','EntidadFinanciera',NULL,N'GOLD: dimensión de entidades financieras (catálogo estable, sin SCD2).';
EXEC dbo.sp_SetDesc 'Dimension','ClasificacionRiesgo',NULL,N'GOLD: dimensión de clasificaciones de riesgo (catálogo estable).';
EXEC dbo.sp_SetDesc 'Dimension','Garantia',NULL,N'GOLD: dimensión de garantías (catálogo).';
-- Hechos Banca
EXEC dbo.sp_SetDesc 'Fact','Movimiento',NULL,N'GOLD: hecho de movimientos bancarios. Grano: una operación. Claves surrogadas a cuenta y cliente, Date Key entero.';
EXEC dbo.sp_SetDesc 'Fact','SaldoCuenta',NULL,N'GOLD: hecho de saldos diarios agregados por cuenta y día.';
EXEC dbo.sp_SetDesc 'Fact','Credito',NULL,N'GOLD: hecho de créditos con métricas calculadas (cuotas pendientes/impagadas, días de retraso) agregadas desde cuotas.';
EXEC dbo.sp_SetDesc 'Fact','CuotaPrestamo',NULL,N'GOLD: hecho de cuotas de préstamo. Grano: una cuota.';
EXEC dbo.sp_SetDesc 'Fact','Transferencia',NULL,N'GOLD: hecho de transferencias con clasificación interna/externa/SEPA.';
EXEC dbo.sp_SetDesc 'Fact','Provision',NULL,N'GOLD: hecho de provisiones contables por riesgo.';
EXEC dbo.sp_SetDesc 'Fact','CIRBE',NULL,N'GOLD: hecho de declaraciones CIRBE al Banco de España.';
EXEC dbo.sp_SetDesc 'Fact','Aval',NULL,N'GOLD: hecho de avales (vacío: sin datos en origen por decisión de calidad).';
-- Dimensiones WWI
EXEC dbo.sp_SetDesc 'Dimension','City',NULL,N'GOLD: dimensión de ciudades con SCD Tipo 2 sobre población.';
EXEC dbo.sp_SetDesc 'Dimension','Customer',NULL,N'GOLD: dimensión de clientes WWI con SCD Tipo 2 sobre categoría y grupo de compra.';
EXEC dbo.sp_SetDesc 'Dimension','Stock Item',NULL,N'GOLD: dimensión de artículos con SCD Tipo 2 sobre precios.';
EXEC dbo.sp_SetDesc 'Dimension','Supplier',NULL,N'GOLD: dimensión de proveedores con SCD Tipo 2 sobre categoría.';
EXEC dbo.sp_SetDesc 'Dimension','Employee',NULL,N'GOLD: dimensión de empleados WWI.';
EXEC dbo.sp_SetDesc 'Dimension','Payment Method',NULL,N'GOLD: dimensión de métodos de pago (catálogo).';
EXEC dbo.sp_SetDesc 'Dimension','Transaction Type',NULL,N'GOLD: dimensión de tipos de transacción (catálogo).';
-- Hechos WWI
EXEC dbo.sp_SetDesc 'Fact','Sale',NULL,N'GOLD: hecho de ventas WWI. Grano: línea de factura. Claves surrogadas a cliente, artículo, ciudad.';
EXEC dbo.sp_SetDesc 'Fact','Order',NULL,N'GOLD: hecho de pedidos WWI. Grano: línea de pedido.';
EXEC dbo.sp_SetDesc 'Fact','Purchase',NULL,N'GOLD: hecho de compras WWI a proveedores.';
EXEC dbo.sp_SetDesc 'Fact','Movement',NULL,N'GOLD: hecho de movimientos de stock WWI.';
EXEC dbo.sp_SetDesc 'Fact','Stock Holding',NULL,N'GOLD: hecho de existencias actuales (snapshot, recarga completa).';
EXEC dbo.sp_SetDesc 'Fact','Transaction',NULL,N'GOLD: hecho de transacciones financieras WWI.';

PRINT 'Silver + Gold: tablas OK';
GO

-- ---------- CAMPOS Silver y Gold por patrón ----------
DECLARE @s SYSNAME,@t SYSNAME,@c SYSNAME,@ty SYSNAME,@sch SYSNAME,@d NVARCHAR(500);
DECLARE cur CURSOR FOR
    SELECT sc.name, t.name, c.name, ty.name
    FROM sys.tables t
    JOIN sys.schemas sc ON t.schema_id=sc.schema_id
    JOIN sys.columns c ON t.object_id=c.object_id
    JOIN sys.types ty ON c.user_type_id=ty.user_type_id
    WHERE sc.name IN ('Integration','Dimension','Fact')
      AND t.name NOT LIKE '%Archive%'
      AND t.is_memory_optimized = 0;  -- saltar tablas memory-optimized (msg 12320)
OPEN cur;
FETCH NEXT FROM cur INTO @sch,@t,@c,@ty;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @d = CASE
        WHEN @c LIKE '%[_]Key' AND @c LIKE '%Date%' THEN 'Clave de fecha (Date Key).'
        WHEN @c LIKE '%[_]Key' AND @c LIKE '%Fecha%' THEN 'Clave de fecha entera (YYYYMMDD).'
        WHEN @c='Lineage Key' THEN 'Clave de linaje: identifica el proceso ETL que cargó el registro.'
        WHEN @c LIKE '%[_]Key' THEN 'Clave surrogada (identificador interno del almacén). Lookup a dimensión; 0 = miembro desconocido.'
        WHEN @c='Valid From' THEN 'SCD2: inicio de vigencia de esta versión del registro.'
        WHEN @c='Valid To' THEN 'SCD2: fin de vigencia (9999-12-31 = versión actual).'
        WHEN @c LIKE 'WWI%ID' THEN 'Identificador de negocio heredado del sistema origen.'
        WHEN @c LIKE 'Fecha%' THEN 'Fecha de '+LOWER(LTRIM(REPLACE(@c,'Fecha','')))+'.'
        WHEN @c LIKE '%Importe%' OR @c LIKE '%Saldo%' THEN 'Importe monetario en euros.'
        WHEN @c='Edad' THEN 'Edad calculada del cliente (campo derivado).'
        WHEN @c LIKE '%Email%' THEN 'Correo electrónico.'
        WHEN @c LIKE '%Nombre%' THEN 'Denominación o nombre.'
        WHEN @c LIKE '%Estado%' THEN 'Estado o situación.'
        WHEN @ty='bit' THEN 'Indicador booleano (Sí/No).'
        ELSE 'Atributo '+@c+'.'
    END;
    EXEC dbo.sp_SetDesc @sch,@t,@c,@d;
    FETCH NEXT FROM cur INTO @sch,@t,@c,@ty;
END;
CLOSE cur; DEALLOCATE cur;
PRINT 'Silver + Gold: campos OK';
GO

-- Limpieza del helper
USE WideWorldImporters;
GO
IF OBJECT_ID('dbo.sp_SetDesc','P') IS NOT NULL DROP PROCEDURE dbo.sp_SetDesc;
GO
USE WideWorldImportersDW;
GO
IF OBJECT_ID('dbo.sp_SetDesc','P') IS NOT NULL DROP PROCEDURE dbo.sp_SetDesc;
GO

PRINT '';
PRINT 'MS_Description completado: Bronze Banca + Silver/Gold (Banca+WWI), tablas y campos';
GO