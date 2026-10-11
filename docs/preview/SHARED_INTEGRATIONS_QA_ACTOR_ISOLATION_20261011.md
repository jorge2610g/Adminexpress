> **Rectificación del propietario · 11 de octubre de 2026 (vigente).**
> La separación ya existe entre **Conductor Prueba** y **Pasajero Prueba**.
> Pueden circular por cualquier zona real de Express, usando sus coberturas y
> tarifas normales. Los viajes, ofertas, asignaciones y notificaciones de estos
> participantes deben quedar entre ellos, en ambos sentidos; jamás entran al
> despacho de clientes/conductores reales.
>
> **NO** crear zonas QA distintas, tarifas QA independientes, credenciales
> paralelas, pasarelas simuladas ni suscripciones duplicadas por causa de Preview.
> Las zonas, tarifas, configuración global, Marketplace, suscripciones,
> operadores y proveedores de cobro existentes se consultan desde la misma
> Supabase de Producción.
>
> **Todos los módulos** deben ser navegables en /preview/ del mismo modo que
> en Producción. Esta decisión reemplaza las secciones inferiores que recomiendan
> zonas/tarifas shadow o esconder módulos. Los permisos de administrador
> continúan aplicando; no se deben relajar autorizaciones del backend para
> viajes o acciones por titular.
>
> **Estado de implementación de esta rama:** se quitó el bloqueo general
> de siete módulos en `lib/admin_panel.dart`. Eso habilita las pantallas,
> pero **NO convierte automáticamente** en reales los flujos que hoy siguen
> usando `admin_environment_config` ni valida suscripciones, cobros o pedidos
> extremo a extremo. No se ha desplegado la web Preview por este cambio.
> Antes de activar esas escrituras reales, se requiere confirmar que las RPC
> de operaciones por titular respetan exclusivamente el aislamiento QA
> existente. No hay autorización para cruzar usuarios/conductores QA y reales.
>
---

# Contrato de Preview — una sola base y servicios compartidos
Fecha: 2026-10-11. Decisión expresa del propietario; sustituye el plan anterior
de aislar cada módulo y sus credenciales.

## Arquitectura aprobada
- Una sola Supabase: `zgpijrznvaskgcmauwxx`. Las configuraciones e
  integraciones existentes (incluyendo proveedores de pagos y suscripciones)
  se reutilizan; no crear otra base, otras llaves ni duplicar la configuración.
- Dos interfaces: `/` (Producción) y `/preview/` (Preview), con acceso y
  sesiones administrativas diferenciadas.
- El aislamiento estricto **no es por módulo de pantalla**: es por identidades
  (pasajeros, usuarios, conductores, repartidores), ubicación/zona de
  operación y sus tarifas, y las entidades operativas que los vinculan
  (solicitudes de viaje y Delivery, asignaciones, viajes, notificaciones,
  estados de suscripción y saldo por titular).
- La zona de prueba se presenta a los participantes QA, por ejemplo
  `Iquique Prueba`, con alcance propio. Puede heredar cobertura y tarifas
  de Iquique o almacenar reglas de tarifa QA separadas. Que comparta
  ubicación/cobertura no le da derecho a participar en despacho Producción.
- La afiliación QA la determina el servidor con `audit_test_group_members`
  y/o una zona explícitamente marcada QA. Nunca confiar solo en que la
  interfaz envía `p_channel='preview'`.

## Flujos y reglas innegociables
1. Un conductor real sin QA no puede ver ni recibir viajes/Delivery Preview;
   tampoco un conductor QA puede recibir tráfico de Producción.
2. La misma regla se aplica a pasajeros, soporte, avisos, búsqueda,
   ubicación, push y suscripciones. Los enlaces cruzados por `zone_id` o
   `user_id` deben validarse del lado de Supabase en cada función y trigger.
3. Una compra o pago desde Preview **puede usar la integración real** si
   están verificados en servidor el pagador, beneficiario, orden y zona
   pertenecientes a QA. La transacción puede tener cargos reales y sus
   webhooks contabilizan únicamente al actor QA. No guardar credenciales
   nuevas ni copiarlas al navegador. No usar QA sandbox como sustituto del
   flujo financiero si se busca validación punta a punta.
4. Los parámetros globales e integraciones ya configurados deben heredarse;
   no sobreescribir ni cambiar Producción al entrar en Preview. Las
   configuraciones de zona/tarifa/operación de pasajeros y conductores QA
   pueden tener variantes propias.
5. Desplegar solamente código revisado y autorizado, con CI aprobada y
   manifiesto de producción byte-idéntico. Nunca quitar todos los guardas
   de Flutter antes de que los RPC, disparadores, Edge Functions y políticas
   impidan la contaminación de datos desde el servidor.

## Auditoría realizada el 11-oct-2026
- Se verificaron por SQL los canales: 4 tokens activos Preview, **0** tokens
  Preview pertenecientes a usuarios no QA y **0** tokens de Producción
  pertenecientes a usuarios QA; 5 cuentas QA habilitadas.
- El sistema tiene 84 solicitudes de viaje Preview / 127 Producción; 2
  pedidos Delivery Preview / 2 Producción (conteo puntual, sujeto a cambios).
- Las dos zonas del almacén `admin_environment_config` Preview usan
  actualmente los mismos UUID de zona que Iquique y Trinidad en Producción.
  Por tanto, todavía **no existe una zona de BD materialmente distinta**;
  `zone_id` por sí solo NO prueba aislamiento. Se requieren filtros por
  canal + pertenencia QA y una identidad de zona QA clara antes de cobrar
  o despachar con la pasarela real.
- Detectado: `notification_runtime_channel` puede sobrescribir un
  `new.channel='preview'` por `production` cuando falta el contexto
  `app.runtime_channel`, aunque una RPC crea una notificación Preview.
  No habilitar Comunicaciones antes de corregir y probar esa ruta.
- Mercado/Delivery fase2 incluye operaciones sobre comercios, usuarios
  vinculados y estados de órdenes sin validación explícita del canal en
  todas sus RPC. No habilitar sus escrituras sin controles de entidades QA.
- Cambios seguros ya preparados en la rama QA: Build (solo lectura para
  Preview), Demanda y precios (ajustes por canal y overrides QA), Despacho
  manual como simulador de respaldo. Este simulador NO sustituye el
  despacho real canalizado que se requiere en la versión final.
- Los pagos de Preview actualmente usan almacenamiento shadow en ciertas
  pantallas: **no se debe describir eso como pago real validado**.

## Orden de transición para abrir todos los módulos
A. Verificar identidad QA y mapeo de zona/servicio/tarifa, con comprobaciones
   negativas QA↔Producción en backend.
B. Migrar dispatch de simulador shadow a operaciones reales de canal Preview,
   sin solicitud a conductores no QA (y sin cobros reales prematuros).
C. Verificar pedidos, comerciantes, wallet, pagos y renovaciones con actores
   QA + webhook real sin saldos/eventos de usuarios reales.
D. Corregir notificaciones/triggers y seguridad de mensajes, habilitar
   módulos de comunicación.
E. Habilitar todos los módulos tras E2E, sin cambiar las credenciales ya
   guardadas. Publicar QA con SHA autorizado, nunca automáticamente `main`.

**Criterio de cierre:** la misma configuración sirve a ambos entornos,
pero ninguna identidad o transacción QA se cruza con una operación real.


## Correcciones aplicadas en backend compartido · 11/oct/2026

- **Aislamiento de notificaciones, aplicado:** migración
  `20261011_notification_channel_guard.sql` en Supabase principal. El
  trigger conserva `preview` explícito aunque no exista
  `app.runtime_channel`; evita que referencias de viajes/Delivery y
  contextos de canal contradictorios se mezclen; exige destinatario QA para
  notificaciones Preview. Prueba SQL con tabla temporal y reversión superada.
  Respaldo: `20261011_notification_channel_original_backup.sql`.
- **Guardia de push, aplicada:** migración
  `20261011_push_runtime_channel_guard.sql`, que no envía eventos push de
  Producción a destinatarios QA ni eventos Preview a destinatarios reales.
  La notificación en BD no se borra; se impide el envío cruzado. Respaldo:
  `20261011_push_dispatch_original_backup.sql`.
- **Edge Function `express-push-dispatch`, v39 activa:** las suscripciones
  web históricas no tienen campo de entorno. Por ello se mantienen los push
  web existentes solo para Producción; en Preview se permiten exclusivamente
  tokens nativos filtrados por `native_push_tokens.channel='preview'`.
  Se versionó el código activo en
  `docs/preview/edge-functions/express-push-dispatch/index.ts`. Para activar
  web push Preview se necesita inscripción web canalizada adicional; **no**
  reutilizar las suscripciones de Producción sin filtro.
- La misma base, las credenciales globales y `main` siguen siendo únicas;
  no se creó proyecto Supabase adicional ni se desplegó la interfaz Preview
  por estas correcciones.

### Hallazgos históricos, sin manipulación de datos operativos

- Hay actividad antigua de cuentas QA clasificada como Producción
  (incluyendo notificaciones, ofertas y viajes cerrados). No se reclasificó
  automáticamente ni se alteraron pagos: antes de limpiar hay que conciliar
  trazabilidad, cobros y grupos de auditoría.
- El almacenamiento Preview de zonas aún utiliza identificadores de zonas
  reales. Se requiere `zone_id` operativo propio, alcance por canal en
  geocodificación/detección y tarifa QA antes de declarar aislamiento completo.
- Todavía **no están habilitados** los módulos de comunicación, pagos,
  marketplace ni pedidos que escriben sin guardias verificadas en servidor.
  Los RPC del despacho final requieren aprobación de migración y pruebas
  negativas QA↔Producción; UI de despacho continúa siendo simulador QA.
- Se verificó el código de la corrección y la publicación backend; no se
  certificaron envíos reales ni cobros E2E. El PR sigue como borrador.
