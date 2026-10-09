# Admin > Publicidad (Google AdMob)

Dentro de **Configuración → Admin** hay un interruptor general y dos interruptores por ubicación (Inicio / viaje activo).

## Dos paneles, un Supabase
- Producción: `/` usa canal `production`, flag `ads_passenger_enabled`. Los tres ID públicos de AdMob se editan **solo aquí**.
- Prueba: `/preview/` usa canal `preview`, flag `ads_passenger_preview_enabled` y unidades oficiales de prueba de Google. Nunca modifica los IDs reales.
- `admin_admob_settings_get` y `admin_admob_settings_update` verifican `is_admin()` y `admin_environment_allowed(p_channel)`; la separación NO depende del frontend.
- Los valores por defecto conservan Producción apagada.
- Para apagar todos los anuncios, usa el switch general del entorno y presiona **Guardar publicidad**. La app aplica la preferencia al actualizar los ajustes remotos.

## Tres identificadores públicos (no claves secretas)
En `admob.google.com`, registra la app Android y una unidad Banner:
1. **Publisher ID:** `pub-****************`.
2. **Android App ID:** `ca-app-pub-****************~**********`.
3. **Banner Ad Unit ID:** `ca-app-pub-****************/**********`.

Nunca pegar en el panel claves JSON de cuentas de servicio, tokens OAuth, API keys privadas ni credenciales bancarias.

## Limitación técnica importante
El **Android App ID** debe estar además compilado en `AndroidManifest.xml`. El workflow de Expressdelivery usa GitHub Actions `ADMOB_ANDROID_APP_ID` para ese fin. Guardarlo en Admin no modifica una APK ya instalada. Para anuncios reales hay que configurar ese secreto y generar un nuevo APK/AAB firmado con la misma identidad de Express; nunca prometer activación automática sin build.

`ADMOB_PASSENGER_BANNER_UNIT_ID` es el fallback de build. La app puede usar `admob_passenger_banner_unit_id` del runtime config cuando ejecute una versión que soporte actualización remota.

**Sin un ID de App válido compilado, mantener Producción OFF.** No publicar en Google Play solo por activar un switch; actualizar Data Safety y declarar anuncios al publicarlos.
