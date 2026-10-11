# Regla obligatoria de paridad Preview / Producción

**Vigente desde:** 2026-10-11  
**Aplica a:** Adminexpress y a cualquier cambio de backend administrativo compartido.

## Principio

Preview y Producción usan **el mismo código**. Solo cambia el contexto de datos/permisos de la cuenta.

Por eso, cualquier cambio **no visual** debe quedar implementado y validado para ambos entornos antes de considerarse terminado.

## Cambios que obligan paridad

Esta regla aplica cuando se modifica cualquiera de estos puntos:

- flujo de negocio;
- navegación funcional;
- validaciones;
- permisos o roles;
- RPC;
- SQL o migraciones;
- tablas, vistas, triggers o funciones;
- configuración remota;
- suscripciones;
- pagos o billetera;
- tarifas;
- usuarios o conductores;
- viajes o delivery;
- identidad/KYC;
- App Builder/release gate;
- integración con Expressdelivery;
- caché, estados o reglas que dependan de datos;
- cualquier condición `preview` / `production`.

## Cambios visuales puros

No exigen rama de validación Preview cuando **solo** cambian apariencia y no modifican comportamiento ni datos, por ejemplo:

- color;
- tipografía;
- tamaño;
- espaciado;
- icono;
- borde;
- distribución visual sin cambiar acciones.

Si un cambio visual altera botones, permisos, navegación, estados, consultas o comportamiento, deja de ser “visual puro” y entra en la regla de paridad.

## Regla de implementación

No crear dos implementaciones.

El cambio se escribe una sola vez en el código compartido y debe resolver correctamente el entorno mediante la identidad autenticada.

Nunca duplicar lógica así:

- archivo Producción vs archivo Preview;
- RPC Producción vs copia manual Preview sin fuente común;
- dos widgets equivalentes que evolucionen por separado.

Cuando existan datos/configuraciones distintos, la separación debe estar en el backend o en el contexto de entorno, no en dos árboles de código.

## Rama Preview de validación

Para cambios funcionales/backend se debe crear una rama temporal de validación:

`preview/<slug-del-cambio>`

Reglas de esa rama:

1. nace del mismo commit/base que la rama del cambio;
2. contiene exactamente la misma implementación funcional;
3. no se convierte en una segunda versión del producto;
4. sirve para validar el cambio con una cuenta Preview y datos Preview;
5. si durante QA hay que corregir código, la corrección se hace en la rama principal del cambio y la rama Preview se actualiza al mismo commit;
6. antes del merge a `main`, la rama de cambio y la rama Preview de validación deben representar el mismo código funcional;
7. después del merge puede borrarse la rama Preview temporal.

No mantener una rama Preview permanente divergente.

## Backend

Cada cambio backend debe responder estas preguntas antes de merge:

- ¿la cuenta Preview puede ejecutar el flujo sin tocar datos reales?
- ¿la cuenta Producción ejecuta el mismo flujo contra datos reales?
- ¿`admin_environment_allowed(p_channel)` o el guard equivalente protege el canal?
- ¿la zona/rol/módulos siguen respetándose?
- ¿la migración deja el esquema consistente para ambos entornos?
- ¿hay valores/configuración necesarios para Preview además de Producción?
- ¿la reversión afectaría ambos entornos de forma segura?

## Definition of Done

Un cambio funcional/backend no está terminado hasta que:

- [ ] el código compartido está implementado;
- [ ] existe rama temporal `preview/<slug>`;
- [ ] Preview ejecuta el flujo correctamente;
- [ ] Producción conserva el flujo esperado;
- [ ] no hay escritura cruzada Preview -> Producción;
- [ ] permisos/rol/zona fueron revisados;
- [ ] migraciones/RPC están versionadas;
- [ ] documentación fue actualizada;
- [ ] CI disponible está en verde.

## Prohibiciones

No volver a:

- dos páginas administrativas;
- dos bundles web;
- dos implementaciones del mismo módulo;
- `ADMIN_ENV` como selector de build;
- `_previewScopedModules`;
- “arreglar Producción ahora y Preview después”;
- mergear un cambio backend sabiendo que Preview queda roto.

## Excepción

Solo el propietario puede autorizar explícitamente que un cambio funcional se fusione sin validación Preview.

Si ocurre, debe quedar documentado como excepción temporal con motivo, riesgo y tarea pendiente.
