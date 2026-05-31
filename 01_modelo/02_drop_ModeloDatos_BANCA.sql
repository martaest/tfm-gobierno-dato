/* 
   DEPURACIÓN DE TABLAS VACÍAS NO INTEGRADAS EN NINGÚN FLUJO ETL
   ----------------------------------------------------------------------------
   Objetivo: reducir el número de tablas vacías del catálogo eliminando
   objetos declarados en el esquema pero no alimentados por ningún proceso.

   Se ELIMINAN:
     - 14 stagings Silver de Banca (su información se consolidó en otros
       stagings: Cliente_Staging, Credito_Staging, Cuenta_Staging, etc.).
     - 13 tablas Bronze de relleno nunca pobladas con datos sintéticos.


/* ----------------------------------------------------------------------------
   BLOQUE 1 - 14 STAGINGS HUÉRFANOS DE BANCA  (BD: WideWorldImportersDW)
   ---------------------------------------------------------------------------- */
USE WideWorldImportersDW;
GO

DROP TABLE IF EXISTS Integration.Amortizacion_Staging;
DROP TABLE IF EXISTS Integration.DireccionCliente_Staging;
DROP TABLE IF EXISTS Integration.DocumentoIdentidad_Staging;
DROP TABLE IF EXISTS Integration.SegmentacionCliente_Staging;
DROP TABLE IF EXISTS Integration.TitularidadCuenta_Staging;
DROP TABLE IF EXISTS Integration.PosicionCredito_Staging;
DROP TABLE IF EXISTS Integration.RiesgoConsolidado_Staging;
DROP TABLE IF EXISTS Integration.ExposicionTotal_Staging;
DROP TABLE IF EXISTS Integration.JerarquiaOrganizativa_Staging;
DROP TABLE IF EXISTS Integration.TarifaVigente_Staging;
DROP TABLE IF EXISTS Integration.CondicionesProducto_Staging;
DROP TABLE IF EXISTS Integration.TransferenciaAgregada_Staging;
DROP TABLE IF EXISTS Integration.ComisionTransferencia_Staging;
DROP TABLE IF EXISTS Integration.Comision_Staging;
GO



/* ----------------------------------------------------------------------------
   BLOQUE 2 - 13 TABLAS BRONZE DE RELLENO  (BD: WideWorldImporters)
   ---------------------------------------------------------------------------- */
USE WideWorldImporters;
GO

DROP TABLE IF EXISTS Credito.AmortizacionesPagadas;
DROP TABLE IF EXISTS Credito.Avales;
DROP TABLE IF EXISTS Cuenta.BloqueosCuenta;
DROP TABLE IF EXISTS Organizacion.ConfiguracionHorarios;
DROP TABLE IF EXISTS Producto.ConfiguracionProducto;
DROP TABLE IF EXISTS Cliente.ContactosEmergencia;
DROP TABLE IF EXISTS Cliente.HistorialCambiosCliente;
DROP TABLE IF EXISTS Producto.HistorialPrecios;
DROP TABLE IF EXISTS Credito.NotificacionesMorosidad;
DROP TABLE IF EXISTS Transferencia.PagosRecurrentes;
DROP TABLE IF EXISTS Producto.PaquetesProductos;
DROP TABLE IF EXISTS Cliente.RelacionesFamiliares;
DROP TABLE IF EXISTS Riesgo.RevisionesNormativas;
GO



