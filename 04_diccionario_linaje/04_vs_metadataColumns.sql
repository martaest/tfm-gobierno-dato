-- Vista que unifica el catalogo de columnas de las tres capas (Bronze sobre
-- WideWorldImporters, Silver y Gold sobre WideWorldImportersDW). Por cada columna
-- da su tipo, longitud, si es clave primaria o ajena y su descripcion (MS_Description).

USE DTGOB;
GO

ALTER VIEW [dev].[vs_metadataColumns] AS

-- BRONZE
SELECT 
    'Bronze' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImporters' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    c.name COLLATE Modern_Spanish_CI_AS AS column_name,
    ty.name COLLATE Modern_Spanish_CI_AS AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_pk,
    CASE WHEN fk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_fk,
    CAST(ep.value AS NVARCHAR(500)) COLLATE Modern_Spanish_CI_AS AS DescripcionCampo,
    c.column_id AS OrdenCampo
FROM WideWorldImporters.sys.tables t
JOIN WideWorldImporters.sys.schemas s ON t.schema_id = s.schema_id
JOIN WideWorldImporters.sys.columns c ON t.object_id = c.object_id
JOIN WideWorldImporters.sys.types ty ON c.user_type_id = ty.user_type_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM WideWorldImporters.sys.indexes i
    JOIN WideWorldImporters.sys.index_columns ic 
        ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
LEFT JOIN (
    SELECT parent_object_id AS object_id, parent_column_id AS column_id
    FROM WideWorldImporters.sys.foreign_key_columns
) fk ON c.object_id = fk.object_id AND c.column_id = fk.column_id
LEFT JOIN WideWorldImporters.sys.extended_properties ep
    ON ep.major_id = c.object_id 
    AND ep.minor_id = c.column_id 
    AND ep.name = 'MS_Description'
WHERE t.name NOT LIKE '%Archive%'
  AND s.name NOT IN ('sys', 'INFORMATION_SCHEMA')

UNION ALL

-- SILVER
SELECT 
    'Silver' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImportersDW' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    c.name COLLATE Modern_Spanish_CI_AS AS column_name,
    ty.name COLLATE Modern_Spanish_CI_AS AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_pk,
    CASE WHEN fk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_fk,
    CAST(ep.value AS NVARCHAR(500)) COLLATE Modern_Spanish_CI_AS AS DescripcionCampo,
    c.column_id AS OrdenCampo
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
JOIN WideWorldImportersDW.sys.columns c ON t.object_id = c.object_id
JOIN WideWorldImportersDW.sys.types ty ON c.user_type_id = ty.user_type_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM WideWorldImportersDW.sys.indexes i
    JOIN WideWorldImportersDW.sys.index_columns ic 
        ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
LEFT JOIN (
    SELECT parent_object_id AS object_id, parent_column_id AS column_id
    FROM WideWorldImportersDW.sys.foreign_key_columns
) fk ON c.object_id = fk.object_id AND c.column_id = fk.column_id
LEFT JOIN WideWorldImportersDW.sys.extended_properties ep
    ON ep.major_id = c.object_id 
    AND ep.minor_id = c.column_id 
    AND ep.name = 'MS_Description'
WHERE s.name = 'Integration'
  AND t.name LIKE '%[_]Staging'
  AND t.name NOT LIKE '%Archive%'

UNION ALL

-- GOLD
SELECT 
    'Gold' COLLATE Modern_Spanish_CI_AS AS capa,
    'WideWorldImportersDW' COLLATE Modern_Spanish_CI_AS AS base_datos,
    s.name COLLATE Modern_Spanish_CI_AS AS schema_name,
    t.name COLLATE Modern_Spanish_CI_AS AS table_name,
    c.name COLLATE Modern_Spanish_CI_AS AS column_name,
    ty.name COLLATE Modern_Spanish_CI_AS AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_pk,
    CASE WHEN fk.column_id IS NOT NULL THEN 1 ELSE 0 END AS es_fk,
    CAST(ep.value AS NVARCHAR(500)) COLLATE Modern_Spanish_CI_AS AS DescripcionCampo,
    c.column_id AS OrdenCampo
FROM WideWorldImportersDW.sys.tables t
JOIN WideWorldImportersDW.sys.schemas s ON t.schema_id = s.schema_id
JOIN WideWorldImportersDW.sys.columns c ON t.object_id = c.object_id
JOIN WideWorldImportersDW.sys.types ty ON c.user_type_id = ty.user_type_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM WideWorldImportersDW.sys.indexes i
    JOIN WideWorldImportersDW.sys.index_columns ic 
        ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
LEFT JOIN (
    SELECT parent_object_id AS object_id, parent_column_id AS column_id
    FROM WideWorldImportersDW.sys.foreign_key_columns
) fk ON c.object_id = fk.object_id AND c.column_id = fk.column_id
LEFT JOIN WideWorldImportersDW.sys.extended_properties ep
    ON ep.major_id = c.object_id 
    AND ep.minor_id = c.column_id 
    AND ep.name = 'MS_Description'
WHERE s.name IN ('Dimension', 'Fact')
  AND t.name NOT LIKE '%Archive%';
GO