-- Poblado inicial del Mapeador de campos (DTGOB.dev.MapeadorCamposTablas).
-- Es un apoyo puntual para no tener que rellenar la tabla entera a mano la primera
-- vez: propone las correspondencias Bronze->Silver y Silver->Gold a partir de los
-- nombres de tabla y campo. El mantenimiento real del Mapeador es manual; esto solo
-- deja una primera version que despues se revisa y se completa.
-- Cubre la mayor parte de los campos. Se incluyen ademas a proposito unas pocas
-- correspondencias hacia campos que no existen en el catalogo, para comprobar que la
-- vista de diagnostico las detecta como inexistentes.

USE DTGOB;
GO

-- Vaciar la tabla para repoblarla desde cero
DELETE FROM dev.MapeadorCamposTablas;
GO

-- Tabla de mapeo Staging -> (BDOrigen, EsquemaOrigen) para SILVER
IF OBJECT_ID('tempdb..#MapSchema') IS NOT NULL DROP TABLE #MapSchema;
CREATE TABLE #MapSchema (
    StagingTable VARCHAR(100) COLLATE DATABASE_DEFAULT,
    BDOrigen VARCHAR(50),
    EsquemaOrigen VARCHAR(50),
    TablaBronzePrincipal VARCHAR(50)
);
INSERT INTO #MapSchema VALUES
-- BANCA
('Cliente_Staging','WideWorldImporters','Cliente','Personas'),
('PerfilRiesgo_Staging','WideWorldImporters','Cliente','ScoreCrediticio'),
('DireccionCliente_Staging','WideWorldImporters','Cliente','DireccionesFiscales'),
('DocumentoIdentidad_Staging','WideWorldImporters','Cliente','DocumentosIdentidad'),
('SegmentacionCliente_Staging','WideWorldImporters','Cliente','SegmentacionComercial'),
('Producto_Staging','WideWorldImporters','Producto','CatalogoProductos'),
('Comision_Staging','WideWorldImporters','Producto','TarifasComisiones'),
('CondicionesProducto_Staging','WideWorldImporters','Producto','CondicionesComerciales'),
('TarifaVigente_Staging','WideWorldImporters','Producto','TarifasComisiones'),
('Cuenta_Staging','WideWorldImporters','Cuenta','CuentasCorrientes'),
('Movimiento_Staging','WideWorldImporters','Cuenta','MovimientosCuenta'),
('SaldoDiario_Staging','WideWorldImporters','Cuenta','MovimientosCuenta'),
('TitularidadCuenta_Staging','WideWorldImporters','Cuenta','TitularesCuenta'),
('Credito_Staging','WideWorldImporters','Credito','Prestamos'),
('Cuota_Staging','WideWorldImporters','Credito','CuotasPrestamo'),
('Amortizacion_Staging','WideWorldImporters','Credito','AmortizacionesPagadas'),
('Garantia_Staging','WideWorldImporters','Credito','Garantias'),
('Aval_Staging','WideWorldImporters','Credito','Avales'),
('PosicionCredito_Staging','WideWorldImporters','Credito','Prestamos'),
('Transferencia_Staging','WideWorldImporters','Transferencia','TransferenciasInternas'),
('TransferenciaAgregada_Staging','WideWorldImporters','Transferencia','TransferenciasInternas'),
('ComisionTransferencia_Staging','WideWorldImporters','Transferencia','TransferenciasExternas'),
('CIRBE_Staging','WideWorldImporters','Riesgo','OperacionesCIRBE'),
('Provision_Staging','WideWorldImporters','Riesgo','ProvisionesContables'),
('ClasificacionRiesgo_Staging','WideWorldImporters','Riesgo','ClasificacionesRiesgo'),
('RiesgoConsolidado_Staging','WideWorldImporters','Riesgo','DeclaracionesCIRBE'),
('ExposicionTotal_Staging','WideWorldImporters','Riesgo','DeclaracionesCIRBE'),
('EntidadFinanciera_Staging','WideWorldImporters','Riesgo','EntidadesFinancieras'),
('Centro_Staging','WideWorldImporters','Organizacion','Sucursales'),
('Empleado_Staging','WideWorldImporters','Organizacion','Empleados'),
('JerarquiaOrganizativa_Staging','WideWorldImporters','Organizacion','Sucursales'),
-- WWI
('City_Staging','WideWorldImporters','Application','Cities'),
('Customer_Staging','WideWorldImporters','Sales','Customers'),
('Employee_Staging','WideWorldImporters','Application','People'),
('PaymentMethod_Staging','WideWorldImporters','Application','PaymentMethods'),
('StockItem_Staging','WideWorldImporters','Warehouse','StockItems'),
('Supplier_Staging','WideWorldImporters','Purchasing','Suppliers'),
('TransactionType_Staging','WideWorldImporters','Application','TransactionTypes'),
('Movement_Staging','WideWorldImporters','Warehouse','StockItemTransactions'),
('Order_Staging','WideWorldImporters','Sales','Orders'),
('Purchase_Staging','WideWorldImporters','Purchasing','PurchaseOrders'),
('Sale_Staging','WideWorldImporters','Sales','Invoices'),
('Transaction_Staging','WideWorldImporters','Sales','CustomerTransactions'),
('StockHolding_Staging','WideWorldImporters','Warehouse','StockItemHoldings');
GO

-- BLOQUE 1: SILVER <- BRONZE
INSERT INTO dev.MapeadorCamposTablas
    (BDOrigen, EsquemaOrigen, NombreObjetoOrigen, NombreCampoOrigen,
     NombreCampoOrigenEnVentanaOB, Transformacion,
     BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino, TipoCampoDestino, OrdenCamposTablaDestino)
SELECT
    ms.BDOrigen,
    ms.EsquemaOrigen,
    ms.TablaBronzePrincipal,
    c.name,
    CASE
        WHEN c.name LIKE '%Importe%' OR c.name LIKE '%Saldo%' THEN 'Importe en euros mostrado en terminal'
        WHEN c.name LIKE '%Fecha%' THEN 'Fecha operación (dd/mm/aaaa)'
        WHEN c.name LIKE '%Nombre%' OR c.name LIKE '%Cliente%' THEN 'Denominación cliente en pantalla'
        WHEN c.name LIKE '%Cuenta%' THEN 'Código IBAN cuenta'
        WHEN c.name LIKE '%Estado%' THEN 'Situación del contrato'
        ELSE 'Campo ' + c.name + ' del terminal'
    END,
    CASE
        WHEN c.name = 'Edad' THEN 'Campo calculado: DATEDIFF(YEAR, Fecha Nacimiento, hoy)'
        WHEN c.name LIKE '%Email%' THEN 'Normalización: LOWER(TRIM(origen))'
        WHEN ty.name IN ('varchar','nvarchar','char','nchar') THEN 'Estandarización: UPPER(TRIM(origen)) + desnormalización vía JOIN'
        WHEN ty.name IN ('decimal','numeric','money') THEN 'Redondeo a 2 decimales: ROUND(origen,2)'
        WHEN ty.name = 'bit' THEN 'Conversión a indicador binario (0/1)'
        WHEN ty.name LIKE '%date%' THEN 'Copia directa de fecha'
        ELSE 'Copia directa desde origen'
    END,
    'WideWorldImportersDW','Integration', t.name, c.name,
    ty.name + CASE WHEN ty.name LIKE '%char%' THEN '('+CAST(c.max_length AS VARCHAR)+')' ELSE '' END,
    c.column_id
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
JOIN WideWorldImportersDW.sys.columns c ON t.object_id = c.object_id
JOIN WideWorldImportersDW.sys.types ty ON c.user_type_id = ty.user_type_id
JOIN #MapSchema ms ON ms.StagingTable COLLATE DATABASE_DEFAULT = t.name COLLATE DATABASE_DEFAULT
WHERE s.name = 'Integration'
  AND c.name NOT LIKE '%Staging Key'
  AND c.name NOT IN ('Valid From','Valid To','Lineage Key')
  -- INCONSISTENCIA: omitir algunos campos
  AND NOT (t.name='Cliente_Staging' AND c.name IN ('Subsegmento','Clasificacion Comercial'))
  AND NOT (t.name='Producto_Staging' AND c.name IN ('Edad Minima','Edad Maxima','Plazo Minimo Dias','Plazo Maximo Dias'))
  AND NOT (t.name='Movimiento_Staging' AND c.name IN ('Sucursal Operacion'))
  AND NOT (t.name='StockItem_Staging' AND c.name IN ('Barcode','Photo','Typical Weight Per Unit'));
GO
PRINT 'Silver <- Bronze mapeado';
GO

-- BLOQUE 1b: Segunda tabla origen para Staging que combinan varias Bronze
-- (refleja desnormalización: Cliente_Staging tambien viene de PersonasJuridicas, etc.)
INSERT INTO dev.MapeadorCamposTablas
    (BDOrigen, EsquemaOrigen, NombreObjetoOrigen, NombreCampoOrigen,
     NombreCampoOrigenEnVentanaOB, Transformacion,
     BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino, TipoCampoDestino, OrdenCamposTablaDestino)
VALUES
-- Cliente_Staging tambien de PersonasJuridicas (campos de empresa)
('WideWorldImporters','Cliente','PersonasJuridicas','CIF','NIF empresa en terminal','UNION con Personas: combina físicas y jurídicas','WideWorldImportersDW','Integration','Cliente_Staging','Numero Documento','nvarchar(20)',4),
('WideWorldImporters','Cliente','PersonasJuridicas','RazonSocial','Razón social en terminal','UNION con Personas','WideWorldImportersDW','Integration','Cliente_Staging','Nombre Completo','nvarchar(300)',5),
('WideWorldImporters','Cliente','PersonasJuridicas','CNAE','Código CNAE actividad','Copia directa para jurídicas','WideWorldImportersDW','Integration','Cliente_Staging','CNAE','nvarchar(10)',11),
-- Cuenta_Staging tambien de CuentasAhorro y CuentasNomina
('WideWorldImporters','Cuenta','CuentasAhorro','NumeroCuenta','IBAN cuenta ahorro','UNION con Corrientes y Nomina (offset ID)','WideWorldImportersDW','Integration','Cuenta_Staging','Numero Cuenta','nvarchar(24)',3),
('WideWorldImporters','Cuenta','CuentasNomina','NumeroCuenta','IBAN cuenta nómina','UNION con Corrientes y Ahorro (offset ID)','WideWorldImportersDW','Integration','Cuenta_Staging','Numero Cuenta','nvarchar(24)',3),
-- Credito_Staging tambien de PrestamosHipotecarios
('WideWorldImporters','Credito','PrestamosHipotecarios','NumeroContrato','Nº contrato hipoteca','UNION con Prestamos (offset ID)','WideWorldImportersDW','Integration','Credito_Staging','Numero Contrato','nvarchar(50)',3),
('WideWorldImporters','Credito','PrestamosHipotecarios','LTVPorcentaje','% LTV hipoteca','Copia directa para hipotecas','WideWorldImportersDW','Integration','Credito_Staging','LTV Porcentaje','decimal',20),
-- Transferencia_Staging tambien de Externas y SEPA
('WideWorldImporters','Transferencia','TransferenciasExternas','IBANDestino','IBAN destino externa','UNION con Internas y SEPA (offset ID)','WideWorldImportersDW','Integration','Transferencia_Staging','Cuenta Destino','nvarchar(34)',6),
('WideWorldImporters','Transferencia','TransferenciasSEPA','BICDestino','BIC destino SEPA','UNION con Internas y Externas','WideWorldImportersDW','Integration','Transferencia_Staging','Cuenta Destino','nvarchar(34)',6),
-- Sale_Staging tambien de InvoiceLines (WWI)
('WideWorldImporters','Sales','InvoiceLines','Quantity','Cantidad facturada','JOIN Invoices + InvoiceLines','WideWorldImportersDW','Integration','Sale_Staging','Quantity','int',12),
('WideWorldImporters','Sales','InvoiceLines','UnitPrice','Precio unitario','JOIN Invoices + InvoiceLines','WideWorldImportersDW','Integration','Sale_Staging','Unit Price','decimal',13),
-- Order_Staging tambien de OrderLines (WWI)
('WideWorldImporters','Sales','OrderLines','Quantity','Cantidad pedida','JOIN Orders + OrderLines','WideWorldImportersDW','Integration','Order_Staging','Quantity','int',13);
GO
PRINT 'Silver <- Bronze (multiples origenes) mapeado';
GO

-- BLOQUE 2: GOLD <- SILVER (Integration)
INSERT INTO dev.MapeadorCamposTablas
    (BDOrigen, EsquemaOrigen, NombreObjetoOrigen, NombreCampoOrigen,
     NombreCampoOrigenEnVentanaOB, Transformacion,
     BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino, TipoCampoDestino, OrdenCamposTablaDestino)
SELECT
    'WideWorldImportersDW','Integration',
    t.name + '_Staging',
    c.name,
    CASE
        WHEN c.name LIKE '%Key' THEN 'Identificador interno (no visible en terminal)'
        WHEN c.name LIKE '%Importe%' OR c.name LIKE '%Saldo%' THEN 'Importe en euros'
        WHEN c.name LIKE '%Fecha%' THEN 'Fecha (dd/mm/aaaa)'
        ELSE 'Campo ' + c.name
    END,
    CASE
        WHEN c.name LIKE '%Key' AND c.name NOT LIKE '%Date%' AND c.name NOT LIKE '%Fecha%' AND c.name NOT LIKE '%Lineage%'
            THEN 'Lookup clave surrogada en dimensión (0 si no encuentra)'
        WHEN c.name LIKE '%Fecha%Key%'
            THEN 'Conversión Date Key entero YYYYMMDD'
        WHEN c.name IN ('Valid From','Valid To') THEN 'SCD Tipo 2: vigencia histórica'
        WHEN c.name = 'Cuotas Pendientes' THEN 'Calculado: COUNT cuotas PENDIENTE'
        WHEN c.name = 'Cuotas Impagadas' THEN 'Calculado: COUNT cuotas IMPAGADA'
        WHEN c.name = 'Dias Retraso Maximo' THEN 'Calculado: MAX días retraso'
        ELSE 'Copia directa desde Silver'
    END,
    'WideWorldImportersDW', s.name, t.name, c.name,
    ty.name + CASE WHEN ty.name LIKE '%char%' THEN '('+CAST(c.max_length AS VARCHAR)+')' ELSE '' END,
    c.column_id
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
JOIN WideWorldImportersDW.sys.columns c ON t.object_id = c.object_id
JOIN WideWorldImportersDW.sys.types ty ON c.user_type_id = ty.user_type_id
WHERE s.name IN ('Dimension','Fact')
  AND t.name NOT LIKE '%Archive%'
  AND c.name NOT IN ('Lineage Key')
  AND NOT (c.name LIKE '%[_]Key' AND c.column_id = 1)
  -- INCONSISTENCIA en Gold
  AND NOT (t.name='Cliente' AND c.name IN ('CNAE','Subsegmento'))
  AND NOT (t.name='Sale' AND c.name IN ('Total Dry Items','Total Chiller Items'))
  AND NOT (t.name='Stock Item' AND c.name IN ('Barcode','Photo'))
  AND NOT (t.name='Credito' AND c.name IN ('Intereses Devengados','Provision Dotada'));
GO
PRINT 'Gold <- Silver mapeado';
GO

-- BLOQUE 3: 4 CAMPOS INVENTADOS (no existen en metadata)
INSERT INTO dev.MapeadorCamposTablas
    (BDOrigen, EsquemaOrigen, NombreObjetoOrigen, NombreCampoOrigen,
     NombreCampoOrigenEnVentanaOB, Transformacion,
     BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino, TipoCampoDestino, OrdenCamposTablaDestino)
VALUES
('WideWorldImportersDW','Integration','Cliente_Staging','Indicador VIP','Marca cliente preferente','Campo heredado versión anterior, pendiente revisión','WideWorldImportersDW','Dimension','Cliente','Es Cliente VIP','bit',99),
('WideWorldImportersDW','Integration','Cuenta_Staging','Codigo Oficina Antigua','Código oficina legado','Mapeo manual no actualizado tras migración','WideWorldImportersDW','Dimension','Cuenta','Oficina Legacy','varchar(20)',98),
('WideWorldImportersDW','Integration','Credito_Staging','Scoring Externo','Puntuación buró externo','Campo previsto no implementado en carga','WideWorldImportersDW','Fact','Credito','Score Buro Externo','int',97),
('WideWorldImporters','Sales','Customers','Loyalty Points','Puntos fidelización','Campo planificado fase 2, no en origen','WideWorldImportersDW','Dimension','Customer','Loyalty Points','int',96);
GO
PRINT 'Inventados añadidos';
GO
/*
  BLOQUE 4: DEDUPLICACIÓN POR CAMPO DESTINO  (para permitir relación 1:1 en Power BI)
  --------------------------------------------------------------------------------
			conservar UN solo mapeo por campo destino (el "canónico").
            Prioridad: primero el mapeo que viene de la tabla Bronze PRINCIPAL
            (BLOQUE 1, OrdenCamposTablaDestino más bajo / orden de inserción),
            descartando los orígenes secundarios que COLISIONAN.
*/
USE DTGOB;
GO

;WITH dups AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino
            ORDER BY
                OrdenCamposTablaDestino ASC,   -- el orden de campo más bajo suele ser el canónico
                NombreObjetoOrigen ASC          -- desempate estable
        ) AS rn
    FROM dev.MapeadorCamposTablas
)
DELETE FROM dups
WHERE rn > 1;
GO

PRINT 'Deduplicado: un único mapeo por campo destino (relación 1:1 lista)';
GO

-- Comprobación: no debe quedar ningún destino con más de un mapeo
SELECT BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino, COUNT(*) AS veces
FROM dev.MapeadorCamposTablas
GROUP BY BDDestino, EsquemaDestino, TablaDestino, NombreCampoDestino
HAVING COUNT(*) > 1;
GO
-- VERIFICACIÓN
SELECT COUNT(*) AS total_mapeos FROM dev.MapeadorCamposTablas;
SELECT EsquemaDestino, COUNT(*) AS campos FROM dev.MapeadorCamposTablas GROUP BY EsquemaDestino;
SELECT COUNT(*) AS campos_no_existentes FROM dev.vs_mapeos_enriquecidos WHERE campo_destino_inexistente=1;
GO
