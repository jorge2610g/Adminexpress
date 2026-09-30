# Adminexpress

Panel administrativo web separado de Express Delivery.

## Responsabilidad

Este repositorio contiene únicamente el panel de administración web de Express:
- operación en vivo
- viajes y delivery
- conductores y usuarios
- seguridad / SOS
- zonas y tarifas
- pagos / billetera
- reportes y configuración
- builds y releases Android
- despacho manual y auditoría

La aplicación de pasajero/conductor permanece en `jorge2610g/Expressdelivery` y será la única que genere APK/AAB.

## Backend

Adminexpress usa el mismo proyecto Supabase de Express, pero el acceso al panel está protegido por la RPC `is_admin`.

## Deploy

GitHub Pages se despliega desde GitHub Actions con el workflow `.github/workflows/deploy-web.yml`.
