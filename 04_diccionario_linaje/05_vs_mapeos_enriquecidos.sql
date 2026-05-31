-- Vista que cruza el Mapeador con el catalogo real de metadatos para validarlo.

CREATE VIEW [dev].[vs_mapeos_enriquecidos] AS
SELECT
    m.*,
    -- ORIGEN
    co.data_type AS tipo_origen,
    co.max_length AS longitud_origen,
    tc.capa AS capa_origen,
    -- DESTINO
    cd.data_type AS tipo_destino,
    cd.max_length AS longitud_destino,
    td.capa AS capa_destino,
    -- DIAGNÓSTICOS
    CASE WHEN co.column_name IS NULL THEN 1 ELSE 0 END AS campo_origen_inexistente, -- campo origen no existe en el catalogo 
    CASE WHEN cd.column_name IS NULL THEN 1 ELSE 0 END AS campo_destino_inexistente, -- campo destino no existe en el catalogo 
    CASE WHEN tc.table_name IS NULL THEN 1 ELSE 0 END AS tabla_origen_inexistente, -- tabla origen no existe en el catalogo 
    CASE WHEN td.table_name IS NULL THEN 1 ELSE 0 END AS tabla_destino_inexistente, -- tabla destino no existe en el catalogo 

    CASE WHEN m.NombreCampoOrigen IS NULL OR m.NombreCampoOrigen = '' THEN 1 ELSE 0 END AS origen_vacio,
    CASE WHEN m.NombreCampoDestino IS NULL OR m.NombreCampoDestino = '' THEN 1 ELSE 0 END AS destino_vacio
FROM [DTGOB].[dev].[MapeadorCamposTablas] m
LEFT JOIN dev.vs_metadataColumns co
    ON co.base_datos COLLATE Modern_Spanish_CI_AS = m.BDOrigen COLLATE Modern_Spanish_CI_AS
    AND co.schema_name COLLATE Modern_Spanish_CI_AS = m.EsquemaOrigen COLLATE Modern_Spanish_CI_AS
    AND co.table_name COLLATE Modern_Spanish_CI_AS = m.NombreObjetoOrigen COLLATE Modern_Spanish_CI_AS
    AND co.column_name COLLATE Modern_Spanish_CI_AS = m.NombreCampoOrigen COLLATE Modern_Spanish_CI_AS
LEFT JOIN dev.vs_metadataTable tc
    ON tc.base_datos COLLATE Modern_Spanish_CI_AS = m.BDOrigen COLLATE Modern_Spanish_CI_AS
    AND tc.schema_name COLLATE Modern_Spanish_CI_AS = m.EsquemaOrigen COLLATE Modern_Spanish_CI_AS
    AND tc.table_name COLLATE Modern_Spanish_CI_AS = m.NombreObjetoOrigen COLLATE Modern_Spanish_CI_AS
LEFT JOIN dev.vs_metadataColumns cd
    ON cd.base_datos COLLATE Modern_Spanish_CI_AS = m.BDDestino COLLATE Modern_Spanish_CI_AS
    AND cd.schema_name COLLATE Modern_Spanish_CI_AS = m.EsquemaDestino COLLATE Modern_Spanish_CI_AS
    AND cd.table_name COLLATE Modern_Spanish_CI_AS = m.TablaDestino COLLATE Modern_Spanish_CI_AS
    AND cd.column_name COLLATE Modern_Spanish_CI_AS = m.NombreCampoDestino COLLATE Modern_Spanish_CI_AS
LEFT JOIN dev.vs_metadataTable td
    ON td.base_datos COLLATE Modern_Spanish_CI_AS = m.BDDestino COLLATE Modern_Spanish_CI_AS
    AND td.schema_name COLLATE Modern_Spanish_CI_AS = m.EsquemaDestino COLLATE Modern_Spanish_CI_AS
    AND td.table_name COLLATE Modern_Spanish_CI_AS = m.TablaDestino COLLATE Modern_Spanish_CI_AS;
GO
