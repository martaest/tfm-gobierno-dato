USE [DTGOB]
GO

IF OBJECT_ID('[dev].[sp_CargaDQ_Resultados]', 'P') IS NOT NULL
    DROP PROCEDURE [dev].[sp_CargaDQ_Resultados];
GO

CREATE PROCEDURE [dev].[sp_CargaDQ_Resultados]
@NombrePaquete NVARCHAR(100) = 'DQ_Analisis'
  ,@NombreSP NVARCHAR(255) = ''
  ,@NombreFichero NVARCHAR(MAX) = ''
  ,@NomTablaDestino NVARCHAR(255) = 'DTGOB.dev.DQ_Resultados'
AS

-- Procedimiento que analiza la calidad de los datos columna a columna.
-- Recorre las tablas/vistas en alcance y, por cada columna, calcula conteos
-- (filas, nulos, duplicados), porcentajes (completitud, scoring) e infiere el
-- tipo logico probando patrones (numerico, fecha, email, DNI, codigo postal,
-- telefono, IBAN, booleano) y detectando si es categorica. El resultado va a
-- DTGOB.dev.DQ_Resultados, una fila por columna y dia. Registra inicio/fin de
-- cada ejecucion en LOG.RegistroCargas y los errores por columna en LOG.DQ_LOG,
-- de modo que un fallo puntual no detiene el barrido completo.


-- Bloque 1: control de dependencias
BEGIN TRY
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;
    SET XACT_ABORT OFF;  -- OFF para que errores de columna no aborte todo

    DECLARE @MensajeError NVARCHAR(4000);
    DECLARE @SeveridadError INT;
    DECLARE @EstadoError INT;
    DECLARE @NumeroError INT;
    DECLARE @ResultadoDependencias BIT = 1;
    DECLARE @RegistrosInsertados INT = 0;

    DECLARE @maxdop_config INT = 4;
    DECLARE @i INT;

    PRINT '========================================';
    PRINT 'INICIO: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT 'Usuario: ' + SUSER_SNAME();
    PRINT 'MAXDOP configurado: ' + CAST(@maxdop_config AS VARCHAR);
    PRINT '========================================';

    IF @NombreSP = ''
        SET @NombreSP = OBJECT_NAME(@@PROCID)

    INSERT INTO [LOG].[RegistroCargas] ([FechaEjecucion],[Paquete],Procedimiento,[NomFichero],[NomTablaDestino])
    VALUES (GETDATE(),@NombrePaquete,@NombreSP,@NombreFichero,@NomTablaDestino);

    ------------------------------------------------------------
    -- CACHEAR METADATOS
    ------------------------------------------------------------
    PRINT 'Precargando metadatos de columnas...';

    IF OBJECT_ID('tempdb..##cache_columnas') IS NOT NULL
        DROP TABLE ##cache_columnas;

    CREATE TABLE ##cache_columnas (
        base_datos  NVARCHAR(200),
        schema_name NVARCHAR(200),
        table_name  NVARCHAR(200),
        columna     NVARCHAR(200),
        tipo_sql    NVARCHAR(200),
        max_length  INT,
        PRIMARY KEY (base_datos, schema_name, table_name, columna)
    );

    DECLARE @bd_unica   NVARCHAR(200);
    DECLARE @sql_cache  NVARCHAR(MAX);

    DECLARE bd_cursor CURSOR FOR
    SELECT DISTINCT base_datos
    FROM DTGOB.dev.vs_metadataTable
    WHERE row_count > 0;

    OPEN bd_cursor;
    FETCH NEXT FROM bd_cursor INTO @bd_unica;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '  Cacheando columnas de BD: ' + @bd_unica;
        SET @sql_cache = '
            INSERT INTO ##cache_columnas
            SELECT ''' + @bd_unica + ''',s.name,t.name,c.name,ty.name,c.max_length
            FROM ' + QUOTENAME(@bd_unica) + '.sys.columns c
            JOIN ' + QUOTENAME(@bd_unica) + '.sys.tables t  ON c.object_id = t.object_id
            JOIN ' + QUOTENAME(@bd_unica) + '.sys.schemas s ON t.schema_id = s.schema_id
            JOIN ' + QUOTENAME(@bd_unica) + '.sys.types ty  ON c.user_type_id = ty.user_type_id';
        BEGIN TRY
            EXEC sp_executesql @sql_cache;
        END TRY
        BEGIN CATCH
            PRINT '    Error cacheando BD ' + @bd_unica + ': ' + ERROR_MESSAGE();
        END CATCH
        FETCH NEXT FROM bd_cursor INTO @bd_unica;
    END
    CLOSE bd_cursor;
    DEALLOCATE bd_cursor;
    PRINT '   Cache de columnas completado';


    /********************************************************************************/
    -- Carga Script de Calidad de Datos
    /********************************************************************************/
    DECLARE @tabla       NVARCHAR(200);
    DECLARE @schema      NVARCHAR(200);
    DECLARE @rowcount    BIGINT;
    DECLARE @base_datos  NVARCHAR(200);
    DECLARE @columna     NVARCHAR(200);
    DECLARE @sql         NVARCHAR(MAX);
    DECLARE @limite_muestreo BIGINT = 100000;
    DECLARE @muestra     BIGINT;
    DECLARE @case_tipo_logico  NVARCHAR(MAX) = '';
    DECLARE @cross_apply_maxporc NVARCHAR(MAX) = '';
    DECLARE @lista_valores NVARCHAR(MAX) = '';

    DECLARE @inicio_tabla   DATETIME;
    DECLARE @inicio_columna DATETIME;
    DECLARE @duracion_seg   INT;
    DECLARE @total_tablas   INT = 0;
    DECLARE @tabla_actual   INT = 0;

    DECLARE @usar_tablesample BIT = 0;
    DECLARE @clausula_select  NVARCHAR(500) = '';
    DECLARE @clausula_from    NVARCHAR(500) = '';

    SELECT @total_tablas = COUNT(*)
    FROM DTGOB.dev.vs_metadataTable
    WHERE row_count > 0;

    PRINT 'Total de tablas a procesar: ' + CAST(@total_tablas AS VARCHAR);
    PRINT '========================================';

    DECLARE tabla_cursor CURSOR FOR
    SELECT table_name, schema_name, row_count, base_datos
    FROM DTGOB.dev.vs_metadataTable
    WHERE row_count > 0
    ORDER BY base_datos DESC;

    OPEN tabla_cursor;
    FETCH NEXT FROM tabla_cursor INTO @tabla, @schema, @rowcount, @base_datos;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @tabla_actual  = @tabla_actual + 1;
        SET @inicio_tabla  = GETDATE();

        PRINT '';
        PRINT '[' + CAST(@tabla_actual AS VARCHAR) + '/' + CAST(@total_tablas AS VARCHAR)
              + '] Analizando tabla: ' + @base_datos + '.' + @schema + '.' + @tabla
              + ' (Filas: ' + CAST(@rowcount AS VARCHAR) + ')';

        -- *** TRANSACCIÓN POR TABLA  ***
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1 FROM DTGOB.dev.DQ_Resultados
            WHERE base_datos = @base_datos AND schema_name = @schema
              AND tabla = @tabla AND fecha_ejecucion = CAST(GETDATE() AS DATE)
        )
        BEGIN
            PRINT '   Ya procesada hoy - saltando';
            IF @@TRANCOUNT > 0 COMMIT TRANSACTION;
            GOTO siguiente_tabla;
        END

        IF OBJECT_ID('tempdb..#tmp_columnas') IS NOT NULL DROP TABLE #tmp_columnas;
        CREATE TABLE #tmp_columnas (columna NVARCHAR(200), tipo_sql NVARCHAR(200), max_length INT);

        BEGIN TRY
            INSERT INTO #tmp_columnas
            SELECT columna, tipo_sql, max_length
            FROM ##cache_columnas
            WHERE base_datos = @base_datos AND schema_name = @schema AND table_name = @tabla;

            DECLARE @num_columnas INT = @@ROWCOUNT;
            IF @num_columnas = 0
            BEGIN
                PRINT '  No se encontraron columnas en cache - saltando tabla';
                IF @@TRANCOUNT > 0 COMMIT TRANSACTION;
                GOTO siguiente_tabla;
            END
            PRINT '  Columnas detectadas: ' + CAST(@num_columnas AS VARCHAR);
        END TRY
        BEGIN CATCH
            PRINT '  ERROR obteniendo columnas desde cache: ' + ERROR_MESSAGE();
            IF @@TRANCOUNT > 0 COMMIT TRANSACTION;
            GOTO siguiente_tabla;
        END CATCH

        DECLARE @tipo_sql   NVARCHAR(200);
        DECLARE @max_length INT;
        DECLARE @col_actual INT = 0;

        DECLARE columna_cursor CURSOR FOR
        SELECT columna, tipo_sql, max_length FROM #tmp_columnas;

        OPEN columna_cursor;
        FETCH NEXT FROM columna_cursor INTO @columna, @tipo_sql, @max_length;

        DECLARE @semilla INT = ABS(CHECKSUM(@base_datos + '.' + @schema + '.' + @tabla));
        DECLARE @porcentaje_muestra DECIMAL(5,2);

        IF @rowcount < 10000
        BEGIN
            SET @muestra           = @rowcount;
            SET @clausula_select   = '';
            SET @clausula_from     = 'WITH (NOLOCK)';
            SET @usar_tablesample  = 0;
            SET @porcentaje_muestra = 100;
        END
        ELSE
        BEGIN
            SET @muestra = @rowcount / 2;
            IF @muestra > @limite_muestreo SET @muestra = @limite_muestreo;
            SET @porcentaje_muestra = (CAST(@muestra AS DECIMAL) / @rowcount) * 100 * 1.2;
            IF @porcentaje_muestra < 0.01 SET @porcentaje_muestra = 0.01;
            IF @porcentaje_muestra > 50   SET @porcentaje_muestra = 50;
            SET @clausula_select  = 'TOP ' + CAST(@muestra AS NVARCHAR(20)) + ' ';
            SET @clausula_from    = 'TABLESAMPLE (' + CAST(@porcentaje_muestra AS NVARCHAR(10))
                                  + ' PERCENT) REPEATABLE (' + CAST(@semilla AS NVARCHAR(20)) + ') WITH (NOLOCK)';
            SET @usar_tablesample = 1;
        END

        PRINT '   Muestreo: '
              + CASE WHEN @usar_tablesample=1
                     THEN 'TABLESAMPLE (' + CAST(@porcentaje_muestra AS VARCHAR) + '%) + TOP ' + CAST(@muestra AS VARCHAR)
                     ELSE 'COMPLETA' END
              + ' (semilla: ' + CAST(@semilla AS VARCHAR) + ')';

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @col_actual     = @col_actual + 1;
            SET @inicio_columna = GETDATE();

            PRINT '    [' + CAST(@col_actual AS VARCHAR) + '/' + CAST(@num_columnas AS VARCHAR) + '] '
                  + @columna + ' (' + @tipo_sql + ')';

            DECLARE @patrones       NVARCHAR(MAX) = '';
            DECLARE @porcentajes    NVARCHAR(MAX) = '';
            DECLARE @select_patrones   NVARCHAR(MAX) = '';
            DECLARE @select_porcentajes NVARCHAR(MAX) = '';
            DECLARE @columna_no_evaluable  BIT = 0;
            DECLARE @select_conformidadDNI BIT = 0;
            DECLARE @select_conformidadIBAN BIT = 0;

            SET @case_tipo_logico = '';
            SET @lista_valores    = '';

            IF @tipo_sql IN ('varbinary','binary','image','timestamp','sql_variant','xml','geography','geometry','hierarchyid','time')
               OR @max_length = -1
            BEGIN
                SET @columna_no_evaluable = 1;
                PRINT '       Tipo no evaluable - saltando patrones';
            END

            ELSE IF @tipo_sql IN ('bit','int','bigint','smallint','tinyint','decimal','numeric','float','real','money','smallmoney')
            BEGIN
                SET @patrones = @patrones + '
                    ,SUM(CASE WHEN TRY_CONVERT(decimal(18,4),[' + @columna + ']) IS NOT NULL THEN 1 END) AS posibles_numerico
                ';
                SET @porcentajes = @porcentajes + '
                    ,CAST(100.0*SUM(CASE WHEN TRY_CONVERT(decimal(18,4),[' + @columna + ']) IS NOT NULL THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_numerico
                ';
                SET @select_patrones    += ',posibles_numerico';
                SET @select_porcentajes += ',porc_numerico';

                SET @patrones = @patrones + '
                    ,CASE WHEN COUNT(DISTINCT [' + @columna + ']) IN (2,3)
                          THEN SUM(CASE WHEN LTRIM(RTRIM(CAST([' + @columna + '] AS VARCHAR(50)))) IN (''0'',''1'') THEN 1 END)
                          ELSE NULL END AS posibles_booleano
                ';
                SET @porcentajes = @porcentajes + '
                    ,CASE WHEN COUNT(DISTINCT [' + @columna + ']) IN (2,3)
                          THEN CAST(100.0*SUM(CASE WHEN LTRIM(RTRIM(CAST([' + @columna + '] AS VARCHAR(50)))) IN (''0'',''1'') THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2))
                          ELSE NULL END AS porc_booleano
                ';
                SET @select_patrones    += ',posibles_booleano';
                SET @select_porcentajes += ',porc_booleano';
            END

            ELSE IF @tipo_sql IN ('date','datetime','datetime2','smalldatetime')
            BEGIN
                SET @patrones = @patrones + '
                    ,SUM(CASE WHEN TRY_CONVERT(date,[' + @columna + ']) BETWEEN ''1900-01-01'' AND ''2100-12-31'' THEN 1 END) AS posibles_fecha
                ';
                SET @porcentajes = @porcentajes + '
                    ,CAST(100.0*SUM(CASE WHEN TRY_CONVERT(date,[' + @columna + ']) BETWEEN ''1900-01-01'' AND ''2100-12-31'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_fecha
                ';
                SET @select_patrones    += ',posibles_fecha';
                SET @select_porcentajes += ',porc_fecha';
            END

            ELSE
            BEGIN
                SET @patrones += '
                    ,SUM(CASE WHEN TRY_CONVERT(decimal(18,4),[' + @columna + ']) IS NOT NULL THEN 1 END) AS posibles_numerico
                ';
                SET @porcentajes += '
                    ,CAST(100.0*SUM(CASE WHEN TRY_CONVERT(decimal(18,4),[' + @columna + ']) IS NOT NULL THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_numerico
                ';
                SET @select_patrones    += ',posibles_numerico';
                SET @select_porcentajes += ',porc_numerico';

                SET @patrones += '
                    ,SUM(CASE WHEN TRY_CONVERT(date,[' + @columna + ']) BETWEEN ''1900-01-01'' AND ''2100-12-31'' THEN 1 END) AS posibles_fecha
                ';
                SET @porcentajes += '
                    ,CAST(100.0*SUM(CASE WHEN TRY_CONVERT(date,[' + @columna + ']) BETWEEN ''1900-01-01'' AND ''2100-12-31'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_fecha
                ';
                SET @select_patrones    += ',posibles_fecha';
                SET @select_porcentajes += ',porc_fecha';

                SET @patrones += '
                    ,CASE
                        WHEN COUNT(DISTINCT [' + @columna + '])=1 THEN
                            CASE WHEN UPPER(LTRIM(RTRIM(CAST(MAX([' + @columna + ']) AS VARCHAR(50))))) IN (''SI'',''NO'',''S'',''N'',''Y'',''TRUE'',''FALSE'') THEN 1 ELSE 0 END
                        WHEN COUNT(DISTINCT [' + @columna + ']) BETWEEN 2 AND 3 THEN
                            CASE WHEN SUM(CASE WHEN UPPER(LTRIM(RTRIM(CAST([' + @columna + '] AS VARCHAR(50))))) IN (''0'',''1'',''SI'',''NO'',''S'',''N'',''Y'',''TRUE'',''FALSE'') THEN 1 END)=COUNT([' + @columna + ']) THEN 1 ELSE 0 END
                        ELSE 0 END AS posibles_booleano
                ';
                SET @porcentajes += '
                    ,CASE
                        WHEN COUNT(DISTINCT [' + @columna + '])=1 THEN
                            CASE WHEN UPPER(LTRIM(RTRIM(CAST(MAX([' + @columna + ']) AS VARCHAR(50))))) IN (''SI'',''NO'',''S'',''N'',''Y'',''TRUE'',''FALSE'') THEN 100.00 ELSE NULL END
                        WHEN COUNT(DISTINCT [' + @columna + ']) BETWEEN 2 AND 3 THEN
                            CAST(100.0*SUM(CASE WHEN UPPER(LTRIM(RTRIM(CAST([' + @columna + '] AS VARCHAR(50))))) IN (''0'',''1'',''SI'',''NO'',''S'',''N'',''Y'',''TRUE'',''FALSE'') THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2))
                        ELSE NULL END AS porc_booleano
                ';
                SET @select_patrones    += ',posibles_booleano';
                SET @select_porcentajes += ',porc_booleano';

                SET @patrones += '
                    ,COUNT(DISTINCT [' + @columna + ']) AS num_distintos
                    ,CASE WHEN ISNULL(SUM(CASE WHEN UPPER(LTRIM(RTRIM(CAST([' + @columna + '] AS VARCHAR(50))))) IN (''0'',''1'',''S'',''N'',''Y'',''TRUE'',''FALSE'') THEN 1 END),0) = 0
                               AND COUNT(DISTINCT [' + @columna + ']) BETWEEN 2 AND 15
                               AND COUNT([' + @columna + '])>COUNT(DISTINCT [' + @columna + '])
                          THEN 1 ELSE 0 END AS es_categorica
                ';
                SET @select_patrones += ',num_distintos,es_categorica';

                IF @max_length >= 6
                BEGIN
                    SET @patrones += '
                        ,SUM(CASE WHEN LEN([' + @columna + ']) BETWEEN 6 AND 254 AND [' + @columna + '] LIKE ''%@%'' AND [' + @columna + '] LIKE ''%.%'' THEN 1 END) AS posibles_email
                    ';
                    SET @porcentajes += '
                        ,CAST(100.0*SUM(CASE WHEN LEN([' + @columna + ']) BETWEEN 6 AND 254 AND [' + @columna + '] LIKE ''%@%'' AND [' + @columna + '] LIKE ''%.%'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_email
                    ';
                    SET @select_patrones    += ',posibles_email';
                    SET @select_porcentajes += ',porc_email';
                END

                IF @max_length >= 9
                BEGIN
                    SET @patrones += '
                        ,SUM(CASE WHEN LEN([' + @columna + '])=9 AND [' + @columna + '] LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]'' THEN 1 END) AS posibles_dni
                    ';
                    SET @porcentajes += '
                        ,CAST(100.0*SUM(CASE WHEN LEN([' + @columna + '])=9 AND [' + @columna + '] LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_dni
                    ';
                    SET @select_patrones    += ',posibles_dni';
                    SET @select_porcentajes += ',porc_dni';

                    SET @patrones += '
                        ,CAST(100.0*ISNULL(SUM(CASE
                            WHEN LEN(LTRIM(RTRIM([' + @columna + '])))=9
                             AND LTRIM(RTRIM([' + @columna + '])) COLLATE Latin1_General_BIN LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]''
                             AND SUBSTRING(''TRWAGMYFPDXBNJZSQVHLCKE'',(TRY_CAST(LEFT(LTRIM(RTRIM([' + @columna + '])),8) AS BIGINT)%23)+1,1)=RIGHT(LTRIM(RTRIM([' + @columna + '])),1)
                            THEN 1 ELSE 0 END),0)
                        /NULLIF(SUM(CASE WHEN LEN(LTRIM(RTRIM([' + @columna + '])))=9 AND LTRIM(RTRIM([' + @columna + '])) COLLATE Latin1_General_BIN LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][A-Z]'' THEN 1 ELSE 0 END),0)
                        AS DECIMAL(5,2)) AS porc_conformidadDni
                    ';
                    SET @select_conformidadDNI = 1;
                END

                IF @max_length >= 5
                BEGIN
                    SET @patrones += '
                        ,SUM(CASE WHEN LEN([' + @columna + '])=5 AND [' + @columna + '] LIKE ''[0-5][0-9][0-9][0-9][0-9]'' THEN 1 END) AS posibles_cp
                    ';
                    SET @porcentajes += '
                        ,CAST(100.0*SUM(CASE WHEN LEN([' + @columna + '])=5 AND [' + @columna + '] LIKE ''[0-5][0-9][0-9][0-9][0-9]'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_cp
                    ';
                    SET @select_patrones    += ',posibles_cp';
                    SET @select_porcentajes += ',porc_cp';
                END

                IF @max_length >= 9
                BEGIN
                    SET @patrones += '
                        ,SUM(CASE WHEN LEN([' + @columna + '])=9 AND [' + @columna + '] LIKE ''[6-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'' THEN 1 END) AS posibles_telefono
                    ';
                    SET @porcentajes += '
                        ,CAST(100.0*SUM(CASE WHEN LEN([' + @columna + '])=9 AND [' + @columna + '] LIKE ''[6-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_telefono
                    ';
                    SET @select_patrones    += ',posibles_telefono';
                    SET @select_porcentajes += ',porc_telefono';
                END

                IF @max_length >= 24
                BEGIN
                    SET @patrones += '
                        ,SUM(CASE WHEN LEN([' + @columna + '])=24 AND [' + @columna + '] LIKE ''ES[0-9][0-9]%'' THEN 1 END) AS posibles_iban
                    ';
                    SET @porcentajes += '
                        ,CAST(100.0*SUM(CASE WHEN LEN([' + @columna + '])=24 AND [' + @columna + '] LIKE ''ES[0-9][0-9]%'' THEN 1 END)/NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS porc_iban
                    ';
                    SET @select_patrones    += ',posibles_iban';
                    SET @select_porcentajes += ',porc_iban';

                    SET @patrones += '
                        ,CAST(100.0*ISNULL(SUM(CASE WHEN LEN([' + @columna + '])=24 AND [' + @columna + '] LIKE ''ES[0-9][0-9]%'' AND DTGOB.dev.fn_ValidaIBAN([' + @columna + '])=1 THEN 1 END),0)
                        /NULLIF(SUM(CASE WHEN LEN([' + @columna + '])=24 AND [' + @columna + '] LIKE ''ES[0-9][0-9]%'' THEN 1 END),0)
                        AS DECIMAL(5,2)) AS porc_conformidadIban
                    ';
                    SET @select_conformidadIBAN = 1;
                END
            END

            DECLARE @sql1 NVARCHAR(MAX);

            IF @columna_no_evaluable = 1
            BEGIN
                SET @sql1 = '
                    SELECT COUNT(*) AS filas,0 AS nulos,0 AS duplicados,
                           0 AS porc_nulos,0 AS porc_duplicados,0 AS completitud,0 AS scoring,
                           0 AS posibles_numerico,0 AS posibles_booleano,
                           0 AS porc_numerico,0 AS porc_booleano
                    FROM (SELECT ' + @clausula_select + ' [' + @columna + ']
                          FROM ' + QUOTENAME(@base_datos) + '.' + QUOTENAME(@schema) + '.' + QUOTENAME(@tabla) + ' ' + @clausula_from + '
                ';
            END
            ELSE
            BEGIN
                SET @sql1 = '
                SELECT
                    COUNT(*) AS filas,
                    SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END) AS nulos,
                    COUNT(*)-COUNT(DISTINCT CASE WHEN [' + @columna + '] IS NOT NULL THEN [' + @columna + '] END)-SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END) AS duplicados,
                    CAST(100.0*SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END)/COUNT(*) AS DECIMAL(5,2)) AS porc_nulos,
                    CAST(100.0*(COUNT(*)-COUNT(DISTINCT CASE WHEN [' + @columna + '] IS NOT NULL THEN [' + @columna + '] END)-SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END))/COUNT(*) AS DECIMAL(5,2)) AS porc_duplicados,
                    CAST(100.0*(1-(SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END)*1.0/COUNT(*))) AS DECIMAL(5,2)) AS completitud,
                    CAST(100-((100.0*SUM(CASE WHEN [' + @columna + '] IS NULL THEN 1 ELSE 0 END)/COUNT(*))*0.6+(100.0*(COUNT(*)-COUNT(DISTINCT [' + @columna + ']))/COUNT(*))*0.4) AS DECIMAL(5,2)) AS scoring
                    ' + @patrones + '
                    ' + @porcentajes + '
                FROM (
                    SELECT ' + @clausula_select + ' [' + @columna + ']
                    FROM ' + QUOTENAME(@base_datos) + '.' + QUOTENAME(@schema) + '.' + QUOTENAME(@tabla) + ' ' + @clausula_from + '
                ';
            END

            IF CHARINDEX('posibles_email',   @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_email >= max_porc*0.95 THEN ''EMAIL'' WHEN porc_email=max_porc THEN ''EMAIL'' ';    SET @lista_valores += ',(t2.porc_email)';    END
            IF CHARINDEX('posibles_dni',     @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_dni >= max_porc*0.95 THEN ''DNI'' WHEN porc_dni=max_porc THEN ''DNI'' ';            SET @lista_valores += ',(t2.porc_dni)';      END
            IF CHARINDEX('posibles_cp',      @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_cp >= max_porc*0.95 THEN ''CP'' WHEN porc_cp=max_porc THEN ''CP'' ';               SET @lista_valores += ',(t2.porc_cp)';       END
            IF CHARINDEX('posibles_telefono',@patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_telefono >= max_porc*0.95 THEN ''TELEFONO'' WHEN porc_telefono=max_porc THEN ''TELEFONO'' '; SET @lista_valores += ',(t2.porc_telefono)'; END
            IF CHARINDEX('posibles_iban',    @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_iban >= max_porc*0.95 THEN ''IBAN'' WHEN porc_iban=max_porc THEN ''IBAN'' ';        SET @lista_valores += ',(t2.porc_iban)';     END
            IF CHARINDEX('posibles_booleano',@patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_booleano=max_porc THEN ''BOOLEANO'' ';                                              SET @lista_valores += ',(t2.porc_booleano)'; END
            IF CHARINDEX('posibles_fecha',   @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_fecha=max_porc THEN ''FECHA'' ';                                                   SET @lista_valores += ',(t2.porc_fecha)';    END
            IF CHARINDEX('es_categorica',    @patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN es_categorica=1 THEN ''CATEGORICA'' ';                                                  SET @lista_valores += ',(CASE WHEN t2.es_categorica=1 THEN 100 ELSE 0 END)'; END
            IF CHARINDEX('posibles_numerico',@patrones)>0 BEGIN SET @case_tipo_logico += ' WHEN porc_numerico=max_porc THEN ''NUMERICO'' ';                                             SET @lista_valores += ',(t2.porc_numerico)'; END

            DECLARE @sql2_header  NVARCHAR(MAX);
            DECLARE @sql2_body    NVARCHAR(MAX);
            DECLARE @sql2_from    NVARCHAR(MAX);
            DECLARE @sql2_maxporc NVARCHAR(MAX);
            DECLARE @tabla_objid  NVARCHAR(200) = REPLACE(@tabla,'''','''''');

            SET @sql2_header = '
            INSERT INTO DTGOB.dev.DQ_Resultados (
                base_datos,schema_name,tabla,columna,
                filas,nulos,duplicados,porc_nulos,porc_duplicados,completitud,scoring
                ' + @select_patrones + '
                ' + @select_porcentajes + ',
                tipo_logico,porc_coincidencia,porc_conformidad,fecha_ejecucion
            )
            SELECT
                ''' + @base_datos + ''',''' + @schema + ''',''' + @tabla_objid + ''',''' + @columna + ''',
                filas,nulos,duplicados,porc_nulos,porc_duplicados,completitud,scoring
                ' + @select_patrones + '
                ' + @select_porcentajes + '
            ';

            IF LTRIM(RTRIM(@lista_valores))='' OR @columna_no_evaluable=1
            BEGIN
                IF @columna_no_evaluable=1 SET @case_tipo_logico = ' WHEN 1=1 THEN ''NO EVALUABLE'' ';
                SET @sql2_maxporc = ' CROSS APPLY (SELECT CAST(0.00 AS DECIMAL(5,2)) AS max_porc) m ';
            END
            ELSE
            BEGIN
                IF LEFT(@lista_valores,1)=',' SET @lista_valores = STUFF(@lista_valores,1,1,'');
                SET @sql2_maxporc = ' CROSS APPLY (SELECT ISNULL(MAX(v),0.00) AS max_porc FROM (VALUES ' + @lista_valores + ') AS x(v)) m ';
            END

            SET @sql2_body = '
                ,CASE ' + @case_tipo_logico + '
                    WHEN max_porc IS NULL OR max_porc<=0 THEN ''SIN INFORMAR''
                    ELSE ''SIN_INFORMAR''
                END AS tipo_logico,
                CASE WHEN max_porc IS NULL OR max_porc<=0 THEN 0.00 ELSE max_porc END AS porc_coincidencia,
                ' + CASE
                    WHEN @select_conformidadIBAN=1 AND @select_conformidadDNI=1
                        THEN 'CASE WHEN ISNULL(t2.porc_iban,0)>=ISNULL(t2.porc_dni,0) AND t2.porc_iban>=80 THEN t2.porc_conformidadIban WHEN t2.porc_dni>=80 THEN t2.porc_conformidadDni ELSE NULL END AS porc_conformidad'
                    WHEN @select_conformidadIBAN=1
                        THEN 'CASE WHEN t2.porc_iban>=80 THEN t2.porc_conformidadIban ELSE NULL END AS porc_conformidad'
                    WHEN @select_conformidadDNI=1
                        THEN 'CASE WHEN t2.porc_dni>=80 THEN t2.porc_conformidadDni ELSE NULL END AS porc_conformidad'
                    ELSE 'CAST(NULL AS DECIMAL(5,2)) AS porc_conformidad'
                END + ',
                CAST(GETDATE() AS DATE)
            ';

            SET @sql2_from = ' FROM (' + @sql1 + ') t ) t2';
            SET @sql = @sql2_header + @sql2_body + @sql2_from + @sql2_maxporc
                     + ' OPTION (MAXDOP ' + CAST(@maxdop_config AS NVARCHAR(2)) + ')';

            BEGIN TRY
                DECLARE @es_inmemory BIT = 0;
                BEGIN TRY
                    DECLARE @sql_check NVARCHAR(1000) = '
                        SELECT @o=ISNULL(is_memory_optimized,0)
                        FROM ' + QUOTENAME(@base_datos) + '.sys.tables t
                        JOIN ' + QUOTENAME(@base_datos) + '.sys.schemas s ON t.schema_id=s.schema_id
                        WHERE s.name=@s AND t.name=@t';
                    EXEC sp_executesql @sql_check,N'@s NVARCHAR(200),@t NVARCHAR(200),@o BIT OUTPUT',
                         @s=@schema,@t=@tabla,@o=@es_inmemory OUTPUT;
                END TRY
                BEGIN CATCH SET @es_inmemory=0; END CATCH

                IF @es_inmemory=1 AND @base_datos<>'DTGOB'
                BEGIN
                    PRINT '       Tabla In-Memory - ejecutando en 2 pasos';
                    IF OBJECT_ID('tempdb..#dq_temp') IS NOT NULL DROP TABLE #dq_temp;
                    SELECT TOP 0 * INTO #dq_temp FROM DTGOB.dev.DQ_Resultados;
                    DECLARE @sql_temp    NVARCHAR(MAX) = REPLACE(@sql,'INSERT INTO DTGOB.dev.DQ_Resultados','INSERT INTO #dq_temp');
                    DECLARE @sql_con_use NVARCHAR(MAX) = 'USE ' + QUOTENAME(@base_datos) + '; ' + @sql_temp;
                    EXEC sp_executesql @sql_con_use;
                    INSERT INTO DTGOB.dev.DQ_Resultados SELECT * FROM #dq_temp;
                    DROP TABLE #dq_temp;
                END
                ELSE
                    EXEC sp_executesql @sql;

                SET @RegistrosInsertados += @@ROWCOUNT;
                SET @duracion_seg = DATEDIFF(SECOND,@inicio_columna,GETDATE());
                PRINT '       OK (' + CAST(@duracion_seg AS VARCHAR) + 's)';
            END TRY
            BEGIN CATCH
                DECLARE @msg NVARCHAR(MAX) = ERROR_MESSAGE();
                INSERT INTO LOG.DQ_LOG (Paquete,Procedimiento,BaseDatos,SchemaName,Tabla,Columna,MensajeError,SQLCompleto)
                VALUES (@NombrePaquete,@NombreSP,@base_datos,@schema,@tabla,@columna,@msg,@sql);
                PRINT '       ERROR columna ' + @columna + ': ' + @msg;
                -- No abortamos por error de columna - continuamos
            END CATCH;

            FETCH NEXT FROM columna_cursor INTO @columna, @tipo_sql, @max_length;
        END

        CLOSE columna_cursor;
        DEALLOCATE columna_cursor;
        DROP TABLE #tmp_columnas;

siguiente_tabla:
        -- *** COMMIT POR TABLA  ***
        IF @@TRANCOUNT > 0 COMMIT TRANSACTION;

        SET @duracion_seg = DATEDIFF(SECOND,@inicio_tabla,GETDATE());
        PRINT '   Tabla completada en ' + CAST(@duracion_seg AS VARCHAR) + ' segundos';
        PRINT '========================================';

        FETCH NEXT FROM tabla_cursor INTO @tabla, @schema, @rowcount, @base_datos;
    END

    CLOSE tabla_cursor;
    DEALLOCATE tabla_cursor;

    IF OBJECT_ID('tempdb..##cache_columnas') IS NOT NULL DROP TABLE ##cache_columnas;

    /********************************************************************************/
    -- Bloque 2: Finalizar / Registro
    /********************************************************************************/
    UPDATE [LOG].[RegistroCargas]
    SET Nuevos=@RegistrosInsertados, Actualizados=0, Eliminados=0,
        FechaFinEjecucion=GETDATE(),
        DuracionSeg=DATEDIFF(ss,FechaEjecucion,GETDATE()),
        DuracionMin=DATEDIFF(mi,FechaEjecucion,GETDATE()),
        Correcto=1
    WHERE Paquete=@NombrePaquete AND Procedimiento=@NombreSP AND FechaFinEjecucion IS NULL;

    SET @MensajeError=NULL; SET @SeveridadError=NULL; SET @EstadoError=NULL; SET @NumeroError=NULL;

    PRINT 'Limpiando histórico (manteniendo últimas 3 ejecuciones)...';
    WITH ultimas AS (SELECT DISTINCT fecha_ejecucion FROM DTGOB.dev.DQ_Resultados),
    ordenadas AS (SELECT fecha_ejecucion, ROW_NUMBER() OVER (ORDER BY fecha_ejecucion DESC) AS rn FROM ultimas)
    DELETE R FROM DTGOB.dev.DQ_Resultados R JOIN ordenadas O ON R.fecha_ejecucion=O.fecha_ejecucion WHERE O.rn>3;
    PRINT '   Histórico limpiado';

    PRINT '========================================';
    PRINT 'FIN OK: ' + CONVERT(VARCHAR,GETDATE(),120);
    PRINT 'Registros insertados: ' + CAST(@RegistrosInsertados AS VARCHAR(10));
    PRINT '========================================';

END TRY

BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

    -- *** LIMPIEZA CURSORES EN CATCH ***
    IF CURSOR_STATUS('global','tabla_cursor')   >= -1 BEGIN CLOSE tabla_cursor;   DEALLOCATE tabla_cursor;   END
    IF CURSOR_STATUS('global','columna_cursor') >= -1 BEGIN CLOSE columna_cursor; DEALLOCATE columna_cursor; END
    IF CURSOR_STATUS('global','bd_cursor')      >= -1 BEGIN CLOSE bd_cursor;      DEALLOCATE bd_cursor;      END
    IF OBJECT_ID('tempdb..##cache_columnas') IS NOT NULL DROP TABLE ##cache_columnas;

    SET @MensajeError  = ERROR_MESSAGE();
    SET @SeveridadError= ERROR_SEVERITY();
    SET @EstadoError   = ERROR_STATE();
    SET @NumeroError   = ERROR_NUMBER();

    PRINT '========================================';
    PRINT 'ERROR - ROLLBACK';
    PRINT 'Error: '      + @MensajeError;
    PRINT 'Número: '     + CAST(@NumeroError   AS VARCHAR(10));
    PRINT 'Severidad: '  + CAST(@SeveridadError AS VARCHAR(10));
    PRINT 'Estado: '     + CAST(@EstadoError    AS VARCHAR(10));
    PRINT 'Línea: '      + CAST(ERROR_LINE()    AS VARCHAR(10));
    PRINT 'Tabla actual: '  + ISNULL(@base_datos+'.'+@schema+'.'+@tabla,'N/A');
    PRINT 'Columna actual: '+ ISNULL(@columna,'N/A');
    PRINT '========================================';

    UPDATE [LOG].[RegistroCargas]
    SET FechaFinEjecucion=GETDATE(),
        DuracionSeg=DATEDIFF(ss,FechaEjecucion,GETDATE()),
        DuracionMin=DATEDIFF(mi,FechaEjecucion,GETDATE()),
        Correcto=0
    WHERE Paquete=@NombrePaquete AND Procedimiento=@NombreSP AND FechaFinEjecucion IS NULL;

    INSERT INTO LOG.DQ_LOG (Fecha,Paquete,Procedimiento,BaseDatos,SchemaName,Tabla,Columna,MensajeError,SQLCompleto)
    VALUES (GETDATE(),@NombrePaquete,@NombreSP,@base_datos,@schema,@tabla,@columna,@MensajeError,@sql);
END CATCH;
GO