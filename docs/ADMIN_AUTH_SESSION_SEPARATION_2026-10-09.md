# Credenciales y sesiones independientes — Admin Express

Fecha: **9 de octubre de 2026**. Esta implementación conserva una sola
aplicación administrativa, un mismo Supabase principal y dos publicaciones
web (`/` y `/preview/`). NO cambia el proyecto Supabase, ninguna clave
publishable, contraseñas ni los permisos existentes del administrador.

## Fase 1 — Protección de sesión y login (implementada en este PR)

El navegador almacena las sesiones Supabase en LocalStorage por **origen**,
no por ruta. Hasta ahora `/` y `/preview/` usaban la clave predeterminada
del mismo proyecto Supabase: cerrar sesión en uno podía cerrar el otro;
entrar a uno podía restaurar la sesión del otro.

- **Producción:** mantiene la clave de sesión original de Supabase.
  No se invalida su sesión existente.
- **Preview:** utiliza una clave específica:
  `express-admin-preview-zgpijrznvaskgcmauwxx-session-v1`.
  Tras el primer despliegue se pedirá iniciar sesión nuevamente en Preview.
- Al iniciar sesión con correo/contraseña, antes de entrar, el panel consulta
  `public.admin_environment_allowed(adminRuntimeChannel)`.
  Si la identidad es administradora de otro entorno, rechaza el acceso y
  cierra esa sesión.
- Para OAuth Google o sesiones restauradas, el `_AdminAuthGate` hace la
  misma comprobación de canal antes de presentar el panel administrativo.
- El selector `Ir a Prueba / Ir a Producción` cambia de página; no copia
  una sesión a la otra.

Esto **no crea un usuario nuevo**. La cuenta original conserva temporalmente
ambos permisos hasta disponer de una segunda cuenta de prueba ya verificada.

## Fase 2 — Aprovisionar la nueva identidad de Preview (pendiente)

Situación del Supabase principal al realizar la auditoría: había **1**
administrador activo con permisos para **ambos** canales, **0**
administradores exclusivamente Preview y **0** exclusivamente Producción.

1. Escoger **un correo distinto** para la identidad administrativa QA.
   No enviar ni registrar contraseñas ni tokens en ChatGPT, Git o logs.
2. Invitar ese correo desde **Supabase Dashboard → Authentication → Users**
   del **proyecto principal de Express** (no desde el proyecto QA antiguo).
   El usuario debe completar la invitación, verificar su correo y definir
   una contraseña exclusiva; también puede usar una identidad Google
   distinta si la política de Auth lo permite.
3. Confirmar que el perfil `public.users` existe, está `active`,
   y que `auth.users` corresponde a esa identidad verificada.
4. Asignarle en `public.admin_users` un registro **nuevo** con
   `access_role='super_admin'`, `active=true`,
   `allow_preview=true`, `allow_production=false`.
   No reutilizar el ID del administrador existente.
   Asegurar que no está vinculado a cuentas reales de conductores/clientes.
5. Probar **login en /preview/** con el correo nuevo: debería entrar.
   Intentar el mismo correo en **/**: debe rechazar acceso admin.
6. **Solo después** de verificar la cuenta nueva, cambiar el administrador
   actual a **Production-only** (`allow_production=true`,
   `allow_preview=false`), dejando todos sus datos y contraseña intactos.
7. Confirmar que la cuenta original entra a **/** y no a **/preview/**,
   y que QA entra a Preview y no a Producción. Evaluar sesiones activas
   de otros dispositivos, refresh token y MFA de cada administrador.

**Nunca invertir el orden 4–6:** desactivar Preview en la única cuenta
administrativa antes de crear y verificar otra bloquearía acceso QA.

## Límite de seguridad: sesiones separadas ≠ backend segregado

Un usuario Preview-only **puede todavía** invocar directamente RPC
`SECURITY DEFINER` históricas sin `p_channel` si esos RPC solo
comprueban `is_admin()` y no `admin_environment_allowed`.
Cambiar las credenciales de usuario o el nombre del almacenamiento de
sesiones NO lo impide; las credenciales de un usuario de Supabase son
válidas en el mismo proyecto compartido.

Antes de permitir pruebas financieras, publicación, KYC real o viajes
reales en Preview, se requiere además una barrera server-side en todos
los escritores administrativos sin canal, o completar y validar el
proyecto físico QA independiente. Issue Expressdelivery #141 recoge
esa tarea.

No rotar las claves publishable ni la service-role key para conseguir
dos sesiones: no separan privilegios de Auth y podrían afectar la app
móvil en Producción. Nunca guardar claves privadas en Flutter Web.

## Regresión y rollback

- CI: verificar fuente de la clave, `authOptions` condicional, prueba
  de canales con RPC y compilar **web Preview + web Producción**.
- Publicar exclusivamente `/preview/` mediante
  `[deploy-preview-only]`. La ruta raíz de Producción debe conservar
  sus bytes idénticos y `version.json` anterior.
- El rollback seguro es recompilar y republicar **solo** el artefacto
  Preview previo con el mismo deployment guard, sin modificar la raíz.
  Si se vuelve a la clave compartida de Auth, las sesiones podrían
  volver a colisionar: hacerlo solo tras una incidencia documentada.
- La fase 2 requiere plan propio de recuperación de credenciales y
  acceso en el panel de Supabase antes de modificar `admin_users`.

**Estado al crear este documento:** Fase 1 en rama de revisión, Fase 2
pendiente de un correo específico nuevo e invitación verificada.
