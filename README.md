# Framework de Gobierno del Dato con trazabilidad y control de calidad en arquitecturas analíticas

Scripts del TFM.

Implementan, sobre WideWorldImporters / WideWorldImportersDW y una
base de gobierno (DTGOB), una extensión bancaria con las tres capas de la arquitectura
medallón (Bronze, Silver, Gold) y los tres componentes del framework: diccionario de
datos, módulo de linaje y motor de calidad.

## Orden de ejecución

Las carpetas y los ficheros están numerados según el orden en que deben ejecutarse.

### 01_modelo
1. `01_ModeloDatos_BANCA.sql` — crea la estructura de las tres capas.
2. `02_drop_ModeloDatos_BANCA.sql` — depuración posterior: elimina las tablas
   declaradas pero no alimentadas por ningún flujo.
3. `03_ms_description.sql` — carga las descripciones extendidas (MS_Description) de
   tablas y campos, que alimentan el diccionario.

### 02_generador
- `GeneradorBronze_BANCA.sql` — genera los datos sintéticos de la capa Bronze
  (incremental, relanzable).
- `fn_ValidaIBAN.sql` — función de validación de IBAN español (mod-97).

### 03_etl
0. `00_ETL_infraestructura.sql` — schema ETL, control de carga incremental y log.
1. `01_ETL_banca_bronze-silver.sql`
2. `02_ETL_banca_silver-gold.sql`
3. `03_ETL_WWI_bronze-silver.sql`
4. `04_ETL_WWI_silver-gold.sql`

### 04_diccionario_linaje
1. `01_MapeadorCamposTablas.sql` — tabla central del linaje (mantenimiento manual).
2. `02_poblar_MapeadorCamposTablas.sql` — apoyo al poblado inicial del Mapeador.
3. `03_vs_metadataTable.sql` — catálogo unificado de tablas (incluye row_count).
4. `04_vs_metadataColumns.sql` — catálogo unificado de columnas.
5. `05_vs_mapeos_enriquecidos.sql` — cruza el Mapeador con los metadatos y detecta
   correspondencias hacia objetos inexistentes.

### 05_calidad
1. `01_LOG_DQ_LOG.sql` — log de errores del proceso de calidad.
2. `02_LOG_RegistroCargas.sql` — bitácora de ejecuciones del motor de calidad.
3. `03_DQ_Resultados.sql` — tabla de resultados (una fila por columna y día).
4. `04_sp_CargaDQ_Resultados.sql` — procedimiento que analiza la calidad columna a
   columna e infiere el tipo lógico por patrones.

## Bases de datos

- **WideWorldImporters** — operacional (Bronze): datos originales + extensión bancaria.
- **WideWorldImportersDW** — Silver (Integration) y Gold (Dimension / Fact).
- **DTGOB** — gobierno del dato: Mapeador, vistas de metadatos y motor de calidad.

## Cuadro de mando (06_powerbi)

`06_powerbi/diccionarioDatos.pbix` es el cuadro de mando del framework e integra las
tres dimensiones: diccionario, linaje y calidad del dato.

Se conecta a la base de datos **`DTGOB`** y consume principalmente estos objetos del
esquema `dev`:

- `vs_metadataTable`, `vs_metadataColumns` — diccionario
- `vs_mapeos_enriquecidos` — linaje
- `DQ_Resultados` — métricas de calidad

### Abrirlo en otra máquina

El `.pbix` guarda la conexión al servidor en el que se creó, por lo que en otro equipo
hay que reapuntar el origen de datos:

1. Abrir `diccionarioDatos.pbix` en Power BI Desktop.
2. **Transformar datos → Configuración del origen de datos** (o **Archivo → Opciones y
   configuración → Configuración del origen de datos**).
3. En **Cambiar origen**, poner el **Servidor** de la instancia SQL Server local
   (p. ej. `localhost`, `.\SQLEXPRESS` o el nombre del equipo) y dejar la **Base de
   datos** como **`DTGOB`** (es el nombre con el que los scripts crean los objetos de
   gobierno; conviene no cambiarlo porque algunas vistas referencian `DTGOB`
   explícitamente).
4. **Aplicar cambios** para refrescar.

> Requisito previo: haber ejecutado antes los scripts de `01_modelo` a `05_calidad` para
> que existan las vistas y tablas en `DTGOB`.
