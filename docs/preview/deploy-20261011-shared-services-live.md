# Deploy controlado de Admin Express Preview — 11 octubre 2026

Fuente de interfaz y configuración compartida verificada: `8926d0a06be469119c1cfb2b0a093272872d1db1`.

Publicar exclusivamente `/preview/` mediante el workflow preview_only, conservando byte por byte Producción. Una sola Supabase, configuraciones y proveedores reales, sin duplicar credenciales. La separación existente de pasajeros/conductores QA y sus viajes sigue activa. No fusionar a main ni aplicar migraciones adicionales en este despliegue.

Esta publicación no certifica el despacho manual real ni cargos o renovaciones E2E. Las transacciones monetarias reales se efectuarán únicamente con autorización y validación de identidad/permisos del beneficiario. Si falla el control de archivos de Producción, abortar.
