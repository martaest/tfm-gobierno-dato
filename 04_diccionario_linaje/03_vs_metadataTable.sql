-- Vista que unifica el catalogo de tablas de las tres capas. Por cada tabla da su
-- capa, fechas de creacion/modificacion, descripcion, numero de filas (row_count,
-- tomado de las estadisticas de particion sin duplicar) y numero de columnas.

USE DTGOB;
GO

ALTER VIEW [dev].[vs_metadataTable] AS
-- ============================================================================
-- BRONZE (WideWorldImporters - OLTP)
-- ============================================================================
SELECT 
    'Bronze' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImporters' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    t.create_date, t.modify_date,
    ep.value AS table_description,
    -- Conteo de filas: subconsulta que SOLO usa index 0 o 1 (heap/clustered)
    ISNULL((
        SELECT SUM(p.row_count)
        FROM WideWorldImporters.sys.dm_db_partition_stats p
        WHERE p.object_id = t.object_id AND p.index_id IN (0,1)
    ),0) AS row_count,
    (SELECT COUNT(*) FROM WideWorldImporters.sys.columns c WHERE c.object_id = t.object_id) AS column_count
FROM WideWorldImporters.sys.tables t
JOIN WideWorldImporters.sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN WideWorldImporters.sys.extended_properties ep
    ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE t.name NOT LIKE '%Archive%'
  AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA')

UNION ALL

-- ============================================================================
-- SILVER (WideWorldImportersDW.Integration - Staging)
-- ============================================================================
SELECT 
    'Silver' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImportersDW' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    t.create_date, t.modify_date,
    ep.value AS table_description,
    ISNULL((
        SELECT SUM(p.row_count)
        FROM WideWorldImportersDW.sys.dm_db_partition_stats p
        WHERE p.object_id = t.object_id AND p.index_id IN (0,1)
    ),0) AS row_count,
    (SELECT COUNT(*) FROM WideWorldImportersDW.sys.columns c WHERE c.object_id = t.object_id) AS column_count
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN WideWorldImportersDW.sys.extended_properties ep
    ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE s.name = 'Integration'
  AND t.name LIKE '%[_]Staging'
  AND t.name NOT LIKE '%Archive%'

UNION ALL

-- ============================================================================
-- GOLD (WideWorldImportersDW - Dimension/Fact)
-- ============================================================================
SELECT 
    'Gold' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImportersDW' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    t.create_date, t.modify_date,
    ep.value AS table_description,
    ISNULL((
        SELECT SUM(p.row_count)
        FROM WideWorldImportersDW.sys.dm_db_partition_stats p
        WHERE p.object_id = t.object_id AND p.index_id IN (0,1)
    ),0) AS row_count,
    (SELECT COUNT(*) FROM WideWorldImportersDW.sys.columns c WHERE c.object_id = t.object_id) AS column_count
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN WideWorldImportersDW.sys.extended_properties ep
    ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = 'MS_Description'
WHERE s.name IN ('Dimension', 'Fact')
  AND t.name NOT LIKE '%Archive%';
GO

GO
