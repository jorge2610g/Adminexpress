# Consolidación del administrador Express · 2026-10-09

## Navegación sin opciones duplicadas
- **Zonas y cobertura** tiene dos pestañas: «Zonas y servicios» (configuración de ciudades) y «Cobertura y seguridad» (polígonos de cobertura / zonas de riesgo).
- **Verificación de identidad** tiene dos pestañas: «Revisión de documentos» (frente, reverso y selfie) y «Requisitos de identidad» (documentos exigidos por país y zona).
- «Cobertura y seguridad» y «Verificación manual» ya no aparecen como elementos laterales duplicados. Sus componentes y datos siguen intactos. Las revisiones se realizan manualmente, sin Didit ni SMS.

## Qué se comparte entre las dos webs Admin
Ambas páginas apuntan al **mismo Supabase principal**. Los datos administrativos de empresa usan una única fuente (tablas y RPCs reales) para:
- países, ciudades/zonas, cobertura y seguridad;
- catálogo de servicios, configuraciones de zonas;
- tarifas lineales y **nuevos escalones de distancia**;
- configuración general;
- requisitos de identidad y documentos.

Los cambios hechos en cualquiera de las dos webs se reflejan en la otra tras refrescar el contenido. **Esto afecta las reglas reales del negocio**: la página de Prueba ya no es un espacio para simular cambios de estos ajustes sin repercusión en clientes.

El aislamiento de los registros operativos **NO se elimina**: viajes QA, conductores QA, solicitudes documentales QA, usuarios, pagos, billeteras, suscripciones en curso y eventos se mantienen separados por canal. Las herramientas financieras y de operación que no validan `p_channel` continúan bloqueadas en Preview. Los controles de AdMob de pruebas siguen usando unidades de prueba y no activan monetización real.

Se conservan las filas antiguas de `admin_environment_config` como respaldo, sin borrarlas ni sobrescribir datos productivos al migrar. El administrador ya no las usa como fuente de verdad para las configuraciones empresariales mencionadas arriba.

## Tarifas escalonadas
En Tarifas, elegir una zona y un servicio. `Tarifa escalonada por distancia` permite añadir, modificar y borrar tramos. Cada distancia es un **límite superior inclusivo**:

| Distancia (hasta) | Ejemplo |
| --- | --- |
| 3 km | 5 BOB |
| 4 km | 6 BOB |
| 5 km | 7 BOB |

Reglas:
- El tramo seleccionado es el de menor `up_to_km` que cubra la distancia.
- Con más distancia que la última fila, se prolonga el último incremento por km sin regresar inesperadamente a la fórmula antigua.
- Las distancias se deben guardar en orden ascendente, con precios positivos que no decrezcan.
- Si no hay tramos, se mantiene el precio anterior de la zona. **No se han creado tramos predeterminados automáticamente**.
- El backend comparte la regla por zona y servicio, respeta moneda `currency_code` y la incluye antes del cálculo de multiplicadores por demanda.
- RPCs protegidos `admin_distance_fare_steps_get` y `admin_distance_fare_steps_replace` requieren administrador y autorización del canal de origen.

## Bloqueo de suscripción al conectar conductor
Cuando el backend rechaza pasar a «En línea» porque falta una suscripción, Android muestra un diálogo grande con el motivo y acción **Ver planes y suscribirme** / **Renovar suscripción**. Al pulsar abre directamente `DriverSubscriptionPage`. No cambia los bloqueos del servidor; solo mejora la navegación.

**Entrega móvil**: Android requiere compilar un APK de prueba nuevo para recibir esta pantalla; cambiar el panel web o la base de datos no actualiza una APK instalada.
