-- Tabla donde el motor de calidad deja una fila por columna analizada y dia.
-- Guarda los conteos (filas, nulos, duplicados), los porcentajes derivados
-- (completitud, scoring, conformidad) y el resultado de la inferencia de tipo
-- logico: cuantos valores encajan con cada patron (DNI, IBAN, email...), el
-- tipo finalmente asignado y su porcentaje de coincidencia.


CREATE TABLE [dev].[DQ_Resultados](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[base_datos] [nvarchar](400) NOT NULL,
	[schema_name] [nvarchar](400) NOT NULL,
	[tabla] [nvarchar](400) NOT NULL,
	[columna] [nvarchar](400) NOT NULL,
	[filas] [bigint] NOT NULL,
	[nulos] [bigint] NOT NULL,
	[duplicados] [bigint] NOT NULL,
	[porc_nulos] [decimal](5, 2) NOT NULL,
	[porc_duplicados] [decimal](5, 2) NOT NULL,
	[completitud] [decimal](5, 2) NOT NULL,
	[scoring] [decimal](5, 2) NOT NULL,
	[posibles_numerico] [int] NULL,
	[posibles_fecha] [int] NULL,
	[posibles_email] [int] NULL,
	[posibles_dni] [int] NULL,
	[posibles_cp] [int] NULL,
	[posibles_telefono] [int] NULL,
	[posibles_iban] [int] NULL,
	[porc_numerico] [decimal](5, 2) NULL,
	[porc_fecha] [decimal](5, 2) NULL,
	[porc_email] [decimal](5, 2) NULL,
	[porc_dni] [decimal](5, 2) NULL,
	[porc_cp] [decimal](5, 2) NULL,
	[porc_telefono] [decimal](5, 2) NULL,
	[porc_iban] [decimal](5, 2) NULL,
	[tipo_logico] [varchar](50) NULL,
	[porc_coincidencia] [decimal](5, 2) NULL,
	[fecha_ejecucion] [date] NOT NULL,
	[posibles_booleano] [int] NULL,
	[num_distintos] [int] NULL,
	[es_categorica] [bit] NULL,
	[porc_booleano] [decimal](5, 2) NULL,
	[porc_conformidad] [decimal](5, 2) NULL
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

