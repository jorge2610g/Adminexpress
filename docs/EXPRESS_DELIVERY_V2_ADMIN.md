# AdminExpress — Express Delivery V2

Fecha candidata: 2026-10-03 / 2026-10-04.

## Respaldo

Antes de V2:

- main base: `5443da47f4d046898009344ffb040376cbc5685a`
- backup: `backup/pre-express-delivery-v2-2026-10-03`

Rama de trabajo:

`feature/express-delivery-v2-complete`

## Panel

Archivo principal:

`lib/admin_delivery_v2.dart`

Entrada de menú:

**Express Delivery · Experiencia V2**

El panel V2 complementa:

- Express Delivery · Catálogo
- Express Delivery · Operación / Plus

## Capacidades

### Filtro por zona

Permite trabajar con Iquique, Trinidad y futuras zonas sin mezclar catálogo
ni configuración.

### Home

Administra:

- título/subtítulo;
- tipo: comercios/productos/promociones;
- regla: popular, confianza, preferencias, descuentos, buen precio,
  patrocinados o manual;
- JSON de selección/configuración;
- orden;
- fecha/hora inicio/fin;
- visible Preview;
- visible Producción.

### Cupones

- código;
- zona/país;
- porcentaje o monto fijo;
- compra mínima;
- descuento máximo;
- financiado por Express/comercio;
- usos totales;
- usos por usuario;
- vigencia;
- Preview/Producción.

### Menú

- secciones internas por comercio;
- orden;
- Preview/Producción.

### Modificadores

- grupo por producto;
- mínimo/máximo;
- obligatorio/opcional;
- opciones;
- costo adicional;
- orden.

### Productos

- sección interna;
- precio anterior;
- precio promocional;
- etiqueta promocional;
- vigencia;
- tags;
- destacado;
- patrocinado;
- productos relacionados/venta cruzada.

### Comercios

- horario JSON;
- apertura manual;
- pedido mínimo;
- tags;
- patrocinado.

## Backend

Depende de las migraciones candidatas de la App:

- 085 Express Delivery V2 schema
- 086 customer functions
- 087 admin functions
- 088 country activity/personalization

No publicar el panel V2 contra un backend donde esas migraciones no estén
aplicadas.

## Seguridad

Los RPC admin verifican `public.is_admin()`.
No se concede execute a `anon`.

## Preview / Producción

Este panel **no debe publicarse sobre el main público** como sustituto de
Preview.

Si AdminExpress no cuenta con URL Preview independiente:

1. mantener el candidato en su rama;
2. aplicar backend V2 únicamente cuando se autorice Preview de la App;
3. validar el panel mediante build de la rama;
4. no tocar el panel público hasta aprobación explícita.

## Rollback

Restaurar:

`backup/pre-express-delivery-v2-2026-10-03`

y conservar Producción Marketplace OFF.
