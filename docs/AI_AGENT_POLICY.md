# Política de agentes de IA — Adminexpress

**Vigente desde:** 2026-10-11  
**Autoridad:** propietario del repositorio

Esta política aplica por igual a Claude/Cloud, ChatGPT, Codex y otros agentes de IA autorizados.

## 1. Sí pueden programar

Ningún agente autorizado está limitado a “solo revisar” o “solo diseñar”. Puede implementar cambios completos dentro de su acceso técnico real: código, UI, backend, SQL, migraciones, workflows, tests, documentación, ramas y PR.

Cualquier texto histórico que diga que “Claude no programa”, “Claude solo revisa”, “la implementación la hace otra IA” o equivalente queda **superado por esta política**.

## 2. Alcance técnico

El repositorio puede ser editado de extremo a extremo cuando la solicitud del propietario lo requiera. Eso incluye:

- `lib/`, `test/`, `web/`, `supabase/`, `.github/`, `docs/`;
- creación, modificación y eliminación de archivos obsoletos;
- GitHub Actions y reglas de despliegue;
- migraciones y RPC administrativas de Supabase;
- ramas, commits, PR y merges;
- correcciones de producción cuando exista autorización explícita.

La documentación no crea credenciales. Si el agente no tiene acceso técnico a GitHub, Supabase u otro servicio, debe decirlo y no simular cambios.

## 3. Arquitectura que no debe revertirse

Adminexpress es **una sola aplicación web** en `admin.expressviajes.online`.

La cuenta autenticada define:

- entorno: Preview o Producción;
- rol;
- zona/ciudad;
- módulos permitidos.

No volver a:

- dos páginas independientes `/` y `/preview/`;
- `ADMIN_ENV` como selector de entorno de build;
- navegación distinta por entorno;
- `_previewScopedModules`;
- un `PREVIEW_AUTHORIZED` que seleccione otro bundle;
- selector manual Preview/Producción dentro de la misma cuenta.

## 4. Paridad funcional obligatoria

Todo agente que modifique flujo, backend, permisos, SQL, RPC o configuración debe mantener paridad Preview/Producción.

Debe crear o mantener una rama temporal `preview/<slug>` que valide **el mismo código** de la rama de cambio. Esa rama es QA, no una implementación paralela.

La regla completa está en `docs/PREVIEW_PRODUCTION_PARITY_RULE.md`.

Los cambios visuales puros están exentos solo si no modifican comportamiento, acciones, consultas, estados ni permisos.

## 4. Seguridad y validación

Antes de mergear cambios sustanciales:

- ejecutar/consultar las validaciones disponibles;
- comprobar que el panel central sigue compilando;
- mantener autorización backend, no solo ocultar botones;
- preservar secretos fuera del repositorio;
- dejar migraciones versionadas si cambia Supabase;
- actualizar documentación vigente en la misma entrega.

## 5. Documentos históricos

Los documentos antiguos pueden mantenerse por trazabilidad, pero deben comenzar con una advertencia **HISTÓRICO / SUPERADO** y apuntar a la documentación vigente. Git conserva el texto anterior en el historial, por lo que no es necesario mantener instrucciones obsoletas activas dentro del archivo.
