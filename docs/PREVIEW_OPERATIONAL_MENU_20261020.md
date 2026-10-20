# Navegación operativa de Preview — 2026-10-20

La cuenta autenticada determina Preview o Producción mediante el contexto existente.
Ambos usan la misma web y la misma base Supabase. No crear zonas, aplicaciones ni
configuraciones duplicadas para Preview.

## Visible en Preview

- Dashboard
- Operación en vivo
- Viajes
- Delivery (listado de entregas de prueba)
- Conductores
- Usuarios
- Seguridad / SOS
- Despacho manual
- Entornos de prueba
- Prueba de carga
- Prioridad conductores
- Campeonato Express

## Solo administración central / Producción

Se ocultan de **la navegación Preview** Builds, Operadores, Pagos,
Tarifas, Suscripciones, Reportes generales, Auditoría, Notificaciones/Avisos,
Configuración, Configuración avanzada, Zonas y cobertura,
Servicios, Demanda y precios, Cobertura y seguridad, y los módulos
comerciales y financieros no incluidos arriba.

Los ajustes de zonas, servicios, tarifas, pagos y suscripciones son compartidos
o centrales; administrarlos desde una cuenta Producción sin duplicarlos para QA.
Preview reutiliza las zonas geográficas, no los registros operativos reales.
Las estadísticas y los flujos de prueba deben seguir respetando el entorno.

## Alcance y seguridad

Este cambio afecta solamente la visibilidad y navegación de la web.
No modifica RPC, RLS, permisos almacenados, flags de negocio, tarifas,
pagos, suscripciones, datos ni bindings de las cuentas. La seguridad sigue
dependiendo de las validaciones del servidor; antes de considerar aislado un
flujo se debe probar contra registros de ambos contextos.

## Validación necesaria antes de publicar

- Cuenta Preview: 12 módulos visibles, ninguno de administración global.
- En móvil y escritorio: no se puede navegar a un módulo oculto.
- Cuenta Producción: menú y módulos existentes sin regresiones.
- Pruebas de carga y de entorno disponibles en Preview.
- Operación en vivo, viajes, Delivery y despacho operan con datos Preview.
- Sin escrituras cruzadas hacia Producción.
