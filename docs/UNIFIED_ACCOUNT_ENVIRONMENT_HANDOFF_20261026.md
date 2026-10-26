# Handoff: Admin único y contexto por cuenta

Fecha 2026-10-26. Lee este documento junto con `AGENTS.md` antes de cambiar el modelo.

- Existe un solo Admin Express y una sola configuración canónica de ciudad, zona, cobertura, tarifas y servicios compartida con los demás clientes.
- Los usuarios y conductores tienen contexto `preview` o `production` determinado por el backend. Las operaciones conservan ese contexto; Prueba nunca se asigna a Producción ni al revés.
- En secciones operativas se puede filtrar qué contexto se muestra, de acuerdo con `admin_environment_allowed` y el rol actual. El filtro no cambia la sesión de autenticación, no modifica configuración global y no amplía permisos.
- Los módulos operativos deben consultar el contexto en sus RPC/Edge Functions y respetar RLS. No resolver aislamiento únicamente ocultando filas en frontend.
- Configuración compartida no implica mezclar usuarios, conductores, pedidos, viajes, billeteras, liquidaciones ni pagos. Mantener sus identificadores/contexto y trazabilidad.
- No recrear Admin Preview, árboles paralelos, `ADMIN_ENV`, `_previewScopedModules` ni otra copia del catálogo/ciudades. Las notas antiguas que afirman que no existe filtro por sección quedan superadas por la directiva 2026-10-26; los límites de rol, zona, módulos y seguridad siguen vigentes.
- No activar o apagar flags comerciales por un despliegue técnico. La cobertura/servicio por zona es configuración de negocio compartida y requiere un cambio específico.
- El estado y protocolo Android oficial están descritos en el mismo documento de handoff de Express. El próximo candidato autorizado para prueba es 1.6.4+148 en Google Play Internal; nunca promover a Play Production sin una orden separada.

## Al modificar

1. Trazar la pantalla hasta RPC/SQL/RLS y confirmar que se filtra el contexto en backend.
2. Mantener intacta la configuración común al cambiar el filtro de operaciones.
3. Añadir migración nueva si hace falta; no reescribir migraciones aplicadas ni borrar historial.
4. Evitar worktrees con cambios locales del propietario. Probar Preview y Producción con cuentas autorizadas sin generar operaciones reales desde QA.
