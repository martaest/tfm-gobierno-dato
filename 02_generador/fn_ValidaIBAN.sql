-- Funcion que valida un IBAN espanol por el algoritmo mod-97.
-- Comprueba longitud (24) y formato, reordena segun la norma (mueve ES y los dos
-- digitos de control al final, con E=14 y S=28) y calcula el modulo 97 en bloques
-- para no desbordar el BIGINT. Devuelve 1 si es valido y 0 si no.
USE DTGOB;
GO

-- Crear schema dev si no existe
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dev')
BEGIN
    EXEC('CREATE SCHEMA dev');
END
GO

CREATE OR ALTER FUNCTION [dev].[fn_ValidaIBAN] (@iban VARCHAR(34))
RETURNS BIT
AS
BEGIN
    -- Validación básica
    IF LEN(@iban) <> 24 RETURN 0;
    IF @iban NOT LIKE 'ES[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' RETURN 0;

    -- Paso 1: reordenar
    -- Original:    ES + 2ctrl + 20 dígitos cuenta
    -- Reordenado:  20 dígitos cuenta + 1428 (E=14,S=28) + 2ctrl
    DECLARE @reordenado VARCHAR(40);
    SET @reordenado = SUBSTRING(@iban, 5, 20)   -- 20 dígitos de cuenta
                    + '1428'                      -- E=14, S=28
                    + SUBSTRING(@iban, 3, 2);     -- 2 dígitos control

    -- Paso 2: MOD 97 en bloques para evitar overflow
    DECLARE @resto   BIGINT = 0;
    DECLARE @pos     INT    = 1;
    DECLARE @len     INT    = LEN(@reordenado);
    DECLARE @bloque  VARCHAR(18);
    DECLARE @digitos_resto INT;

    WHILE @pos <= @len
    BEGIN
        SET @digitos_resto = LEN(CAST(@resto AS VARCHAR));
        SET @bloque = CAST(@resto AS VARCHAR) 
                    + SUBSTRING(@reordenado, @pos, 9 - @digitos_resto);
        SET @pos    = @pos + (9 - @digitos_resto);
        SET @resto  = CAST(@bloque AS BIGINT) % 97;
    END

    RETURN CASE WHEN @resto = 1 THEN 1 ELSE 0 END;
END
GO
