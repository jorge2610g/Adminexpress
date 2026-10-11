# Claude / Cloud — reglas de trabajo en Adminexpress

Claude, Cloud, ChatGPT, Codex y cualquier otra IA **autorizada por el propietario** pueden programar en este repositorio. No existe una regla vigente que limite a Claude/Cloud a arquitectura, lectura o revisión.

## Alcance autorizado del repositorio

Un agente de IA con credenciales/conector válidos puede, cuando la tarea del propietario lo requiera:

- leer todo el repositorio;
- crear, editar, mover o borrar código y documentación;
- modificar Flutter/Dart, SQL, migraciones, tests y GitHub Actions;
- crear ramas, commits y pull requests;
- actualizar esquemas o RPC de Supabase cuando el cambio esté autorizado;
- preparar y ejecutar despliegues cuando el propietario haya autorizado ese alcance;
- corregir documentación obsoleta.

La autorización documental **no sustituye** los permisos técnicos del proveedor: el agente solo puede usar las credenciales, conectores y permisos que realmente tenga disponibles. Nunca debe inventar acceso ni exponer secretos.

## Fuente de verdad

Leer en este orden antes de cambiar arquitectura:

1. `AGENTS.md`
2. `docs/START_HERE_ADMINEXPRESS.md`
3. `docs/AI_HANDOFF_2026-10-11.md`
4. `docs/admin-central-access.md`
5. `docs/CHANGELOG_ACTIVE.md`

Los documentos marcados **HISTÓRICO / SUPERADO** no son instrucciones vigentes.

## Arquitectura vigente

- Una sola web: `https://admin.expressviajes.online/`.
- `/preview/` es solo una ruta heredada que redirige al panel central.
- Un solo Supabase principal: `zgpijrznvaskgcmauwxx`.
- Preview/Producción se determina por la cuenta autenticada, no por build, URL ni selector.
- Rol, zona y módulos se resuelven con `admin_access_context()`.
- `account_runtime_bindings.environment` fija `preview` o `production`.
- La verificación de identidad está integrada en la ficha del conductor; no debe recrearse un menú duplicado.

## Reglas de seguridad

- No guardar service-role keys, passwords, tokens, keystores ni secretos en Git.
- No reintroducir `ADMIN_ENV`, un segundo bundle web ni `_previewScopedModules`.
- No crear una segunda página administrativa por entorno.
- No publicar Producción o Google Play sin autorización explícita del propietario y validaciones verdes.
- Mantener trazabilidad con ramas/commits/migraciones y actualizar documentación cuando cambie una regla operativa.
