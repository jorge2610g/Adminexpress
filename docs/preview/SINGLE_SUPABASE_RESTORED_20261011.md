# Admin Express Preview — retorno a una sola base Supabase

**Decisión del propietario: 11 de octubre de 2026.**
El proyecto separado Express Preview fue eliminado por el propietario y no
debe volver a utilizarse ni recrearse. Los dos sitios apuntan exclusivamente
al proyecto de Supabase principal `zgpijrznvaskgcmauwxx`.

| Sitio | Ruta | Base Supabase | Canal SQL | Sesión de navegador |
| --- | --- | --- | --- | --- |
| Producción | `/` | principal | `production` | original |
| Preview | `/preview/` | principal | `preview` | exclusiva de QA |

## Invariantes obligatorias

1. `ADMIN_ENV=preview` no concede acceso de producción. La autorización
   depende de `admin_users.allow_preview` y de las RPC protegidas
   `admin_environment_allowed('preview')`.
2. El usuario administrativo de Preview ya estaba registrado y autorizado en
   Supabase principal. No duplicar usuarios, contraseñas ni cuentas.
3. Preview usa `admin_environment_config` para configuraciones simuladas.
   Las tarifas escalonadas de Preview NO deben escribir en
   `zone_distance_fare_steps` usadas por pasajeros reales.
4. Solo los módulos con operación QA acotada están habilitados. Los módulos
   sin aislamiento comprobado deben fallar cerrados; no reactivar
   `_previewUnlockAllModules` mientras exista una sola base compartida.
5. No ejecutar SQL, funciones Edge ni migraciones bajo
   `docs/preview/migrations/` y `docs/preview/edge-functions/`: proceden
   del proyecto separado ya eliminado; son historial, NO parte de la
   arquitectura activa.
6. GitHub Pages puede publicar únicamente `/preview/` usando el artefacto
   probado de Producción y su manifest SHA. Está prohibido mutar `main`,
   redesplegar la raíz, cambiar flags de producción o copiar credenciales.
7. Publicación no certifica todavía que las operaciones de extremo a extremo
   estén aisladas. Probar con datos de QA y nunca con pasajeros/pagos reales.

## Verificación de publicación
Consultar `/version.json` y `/preview/version.json`: **ambos deben tener el
mismo `supabase_project_ref`**, los canales deben diferir y el SHA de
Producción debe conservarse. Verificar autenticación con la cuenta QA que
ya existía en el proyecto principal.

## Validación automatizada

El código con una sola base y los dos modos `ADMIN_ENV` ha superado las
comprobaciones en GitHub Actions `38107126690` y `38107129351`, incluyendo
compilaciones web de Producción y Preview, resguardo de los módulos no
verificados y tarifas simuladas.

Este commit solicita publicar exclusivamente la nueva versión `/preview/`.
