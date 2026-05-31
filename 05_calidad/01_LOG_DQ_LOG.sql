-- Tabla de log de errores del proceso de calidad.
-- Si al evaluar una columna salta una excepcion, se guarda aqui 

CREATE TABLE LOG.DQ_LOG (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Paquete VARCHAR(200),
    Procedimiento VARCHAR(200),
    BaseDatos VARCHAR(200),
    SchemaName VARCHAR(200),
    Tabla VARCHAR(200),
    Columna VARCHAR(200),
    MensajeError NVARCHAR(MAX),
    SQLCompleto NVARCHAR(MAX) NULL
);

