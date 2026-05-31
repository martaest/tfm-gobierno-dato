-- Tabla central del modulo de linaje. Cada fila describe la correspondencia de un
-- campo entre dos capas: de donde viene (BD, esquema, objeto y campo de origen, mas
-- su nombre en el terminal financiero / Ventana OB), la transformacion aplicada y a
-- donde va (BD, esquema, tabla y campo de destino, con su tipo y orden).
-- Se mantiene manualmente conforme se crean nuevos objetos.
CREATE TABLE [dev].[MapeadorCamposTablas](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[BDOrigen] [varchar](50) NULL,
	[EsquemaOrigen] [varchar](50) NULL,
	[NombreObjetoOrigen] [varchar](50) NULL,
	[NombreCampoOrigen] [varchar](50) NULL,
	[NombreCampoOrigenEnVentanaOB] [varchar](100) NULL,
	[Transformacion] [varchar](5000) NULL,
	[BDDestino] [varchar](50) NULL,
	[EsquemaDestino] [varchar](50) NULL,
	[TablaDestino] [varchar](50) NULL,
	[NombreCampoDestino] [varchar](50) NULL,
	[TipoCampoDestino] [varchar](100) NULL,
	[OrdenCamposTablaDestino] [int] NULL,
 CONSTRAINT [PK_MapeadorCamposTablas] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
