# OAuth Google de Admin Preview: retorno al sitio equivocado

Fecha: 2026-10-10 UTC. Evidencia: grabación de 15 s de una prueba de acceso.
Al seleccionar la identidad Google para Express Preview, el navegador
termina mostrando la web pública `https://expressviajes.online/`
(en lugar de regresar al panel `https://admin.expressviajes.online/preview/`).
La selección de identidad sí se abre; el regreso no entra al panel.

## Diagnóstico

En el momento de la incidencia, Flutter llamaba a
`signInWithOAuth(OAuthProvider.google, redirectTo: Uri.base.toString())`.
Aunque en la página Preview se espera la URL correcta, Supabase Auth
puede usar su **Site URL predeterminada** cuando la URL
`redirectTo` no coincide con la allow-list del proyecto. El vídeo
es compatible con ese caso, **pero no demuestra por sí solo** cuál
URL figura en Authentication > URL Configuration. No cambiar
`Site URL`: es global y la usan otras rutas de Express.

## Cambio de código limitado a Preview

`lib/core/supabase_client.dart` define una URL de retorno exacta:
`https://admin.expressviajes.online/preview/`.

`lib/main.dart` usa explícitamente esa constante en
`signInWithOAuth`; ya no depende de `Uri.base` para ese flujo.
El cambio no altera la web de Producción ni el Supabase de la app
móvil, ni el proveedor Google, ni las credenciales.

## Paso OBLIGATORIO en el proyecto principal de Supabase

El conector disponible permite inspeccionar SQL, pero no incluye
**edición de Auth URL Configuration**. Se debe revisar desde:

`https://supabase.com/dashboard/project/zgpijrznvaskgcmauwxx/auth/url-configuration`

En **Redirect URLs**, agregar la URL **exacta**:

`https://admin.expressviajes.online/preview/`

También comprobar si Supabase tiene ya una entrada para ella.
No usar comodines para todo el dominio; no sustituir ni borrar las
URLs de retorno de pasajeros, Android, producción, ni la Site URL.

Fuente: Supabase `https://supabase.com/docs/guides/auth/redirect-urls`.
La documentación oficial indica que el parámetro `redirectTo`
debe coincidir con la lista de Redirect URLs y la Site URL sirve como
retorno predeterminado.

## Prueba de aceptación

1. Esperar deploy exclusivamente en `/preview/`, con workflow
   GitHub que conserva todos los bytes de la página de Producción.
2. Ingresar a `https://admin.expressviajes.online/preview/`.
3. Pulsar «Acceder con Google · Preview».
4. Elegir el Gmail administrador de Preview confirmado en Supabase
   (el mismo que tiene `allow_preview=true`,
   `allow_production=false`).
5. El navegador debe volver a
   `https://admin.expressviajes.online/preview/` y mostrar
   Adminexpress, no la página de pasajeros.
6. Confirmar que la sesión en `/preview/` es independiente de `/`
   y que **no** se permite el panel administrador de Producción con
   esa identidad.
7. **Solo después de este paso aprobado:** convertir el administrador
   original en Production-only, preservando rollback y acceso.
   Nunca retirarle Preview primero sin confirmar el retorno Google.

## Límite

El redirect seguro y la separación de sesiones evitan choques del
navegador, **no** sustituyen los guards del servidor. Persisten RPC
administrativas sin `p_channel` que se auditan aparte (#141).

## Verificación de release

`Validate Admin Preview Production Split` compila ambos targets y
comprueba por CI que Google usa la constante exacta. El workflow de
GitHub Pages con `[deploy-preview-only]` debe conservar el artefacto
y SHA de Producción, compilando únicamente Preview.
