-- Log de ejecuciones del SP de calidad con el resultado: fin, registros, duracion y si fue correcta.
USE DTGOB;
GO

CREATE TABLE LOG.RegistroCargas (
    Id                  INT             IDENTITY(1,1) PRIMARY KEY,
    FechaEjecucion      DATETIME        NOT NULL DEFAULT GETDATE(),
    FechaFinEjecucion   DATETIME        NULL,
    Paquete             VARCHAR(200)    NULL,
    Procedimiento       VARCHAR(200)    NULL,
    NomFichero          NVARCHAR(MAX)   NULL,
    NomTablaDestino     NVARCHAR(255)   NULL,
    Nuevos              INT             NULL,
    Actualizados        INT             NULL,
    Eliminados          INT             NULL,
    DuracionSeg         INT             NULL,
    DuracionMin         INT             NULL,
    Correcto            BIT             NULL
);
GO