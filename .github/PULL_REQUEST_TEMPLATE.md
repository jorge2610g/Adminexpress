## Resumen

Describe qué cambia y por qué.

## Tipo de cambio

- [ ] Visual puro (sin cambios de flujo, datos, permisos ni backend)
- [ ] Funcional / flujo
- [ ] Backend / RPC / SQL / migración
- [ ] Permisos / roles / zona
- [ ] Release / App Builder / integración

## Paridad Preview / Producción

Si NO es visual puro:

- [ ] Creé o actualicé la rama temporal `preview/<slug>`
- [ ] La rama Preview contiene el mismo código funcional que esta PR
- [ ] Probé el flujo con cuenta Preview
- [ ] Verifiqué que Preview no escribe datos reales
- [ ] Verifiqué el comportamiento esperado en Producción
- [ ] Revisé permisos, rol y zona
- [ ] Versioné migraciones/RPC si aplica
- [ ] Actualicé documentación

**Rama Preview de validación:**  
`preview/...`

**Resultado Preview:**  

**Resultado Producción / compatibilidad:**  

## Riesgo / rollback

Indica riesgos conocidos y cómo revertir el cambio.
