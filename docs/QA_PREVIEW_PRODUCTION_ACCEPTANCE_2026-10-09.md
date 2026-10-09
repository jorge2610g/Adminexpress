# Express Admin — protocolo de aceptación de Preview (2026-10-09)

**Finalidad:** probar cambios de la misma UI con datos de QA sin tocar
información operativa de Producción. No certifica aislamiento total:
mientras la misma cuenta `super_admin` tenga ambos permisos y existan
RPC `SECURITY DEFINER` sin canal, hay riesgo de escritura cruzada desde
una llamada directa. Mantener operaciones financieras y módulos no
auditados bloqueados en Preview; no usar la cuenta de prueba para
llamadas RPC manuales.

## Despliegue que preserva Producción

El proyecto Pages `github-pages` se protege para su rama principal.
Un build desde la rama QA (Actions run 37990890621) sí produjo artefacto,
pero no pudo desplegar debido a la restricción del entorno; el job final
no ejecutó acciones y la web siguió en su versión anterior.

La vía habilitada por el workflow EXISTENTE es incorporar el código
revisado a main con mensaje de commit que contenga
`[deploy-preview-only]`. Esto hace que:

1. Se omita el build de Producción.
2. Se recupere el artefacto oficial que mantiene la web de Producción,
   del último run exitoso validado `37969274447`.
3. Se compare **byte a byte** ese artefacto con la web pública real.
   Si no es idéntico, se aborta sin publicar.
4. Se compile la misma rama aprobada para `ADMIN_ENV=preview`.
5. Se reemplace únicamente el directorio `/preview/`.
6. Se compare el SHA256 de cada archivo **fuera de** `/preview/`
   antes y después. Ante diferencia, se aborta.
7. Se publique desde `main`, el origen permitido por GitHub Pages.
8. Se verifiquen vía HTTPS dos `version.json`: Preview debe tener
   el SHA del merge y Producción debe conservar
   `30e60582a337be3911671742d780b240793497df`.

**Si la versión publicada de Producción ha cambiado desde el
artefacto de referencia, NO actualizar automáticamente el pin a ciegas**:
comparar el artefacto contra el sitio actual, revisar los changes
y repetir pruebas de regresión y marcado de versión.

## Pruebas manuales en el navegador

1. Abrir `https://admin.expressviajes.online/preview/`.
   Comprobar la insignia Preview y `version.json` de Preview con el
   SHA aprobado. No usar el sitio raíz para simular estas pruebas.
2. Verificar que se inicia sesión con un administrador autorizado,
   se entra al país/zona del canal Preview y no se cambia el canal a
   Producción desde el menú.
3. Ir a **Zonas y cobertura → Países**. El botón **Preparar países QA**
   solo debe aparecer en Preview. Antes de usarlo, se puede revisar
   el modal y pulsar **Cancelar** sin escribir nada.
4. Si se autoriza la carga de referencias QA, pulsar **Preparar QA**,
   confirmar que aparecen países CL/BO (según catálogo existente),
   inicialmente con **País OFF** y **Registro OFF**. Esto SOLO escribe
   filas nuevas en `admin_environment_config`, módulo
   `service_countries`; nunca en `service_countries` real.
5. En Zonas QA verificar listado, crear un registro sintético
   desactivado y probar **radio O polígono**, no ambos. Confirmar
   que la interfaz vuelva a mostrar el modo y sus puntos guardados.
6. Revisar Tarifas, Servicios y Configuración QA. Cambiar valores
   **solo de prueba** y volver a entrar para comprobar persistencia
   en shadow. Verificar que Producción sigue igual.
7. Entrar a los módulos peligrosos (Pagos/Billetera,
   suscripciones/publicación) y confirmar que Preview **no**
   permite operar con fondos reales.
8. Hacer un recorrido QA con usuarios y conductores marcados
   `preview`, sin pagos: viaje completo, estado, cancelación,
   historial y verificación manual de documentos. Si falta cobertura
   QA física o cuenta de prueba, marcar **NO PROBADO** y no simular
   resultados. Probar cambio de pestañas sin recargar toda la web.
9. Comprobar visualmente `/` (Producción) con **solo lecturas**:
   Dashboard, zonas reales, tarifas reales y módulos operativos
   existentes, sin hacer ediciones ni cobros de prueba.

## Lecturas SQL comparativas (solo consulta)

En Supabase principal utilizar exclusivamente `SELECT` y registrar
resultados antes/después; no insertar/actualizar/borrar registros.

```sql
select module, count(*) as total
from public.admin_environment_config
where environment='preview'
group by module order by module;

select environment, count(*) as total
from public.account_runtime_bindings
group by environment order by environment;

select count(*) as qa_countries
from public.admin_environment_config
where environment='preview' and module='service_countries';
```

Para producción, comparar registros existentes por identificadores
y fechas de actualización de zonas, tarifas y países, **sin divulgar
datos personales**. Guardar nombres de consultas y hashes/contadores.

## Condiciones de aprobación

**Aprobación UI Preview**: último deploy OK; referencias en QA
persisten y no hay escrituras en registros reales; UI y roles
correctos; el sitio raíz permanece byte por byte igual.

**Aprobación aislamiento backend**: además de lo anterior, prueba
de denegación sobre TODAS las RPC administrativas no canalizadas
con roles Preview-only y pruebas de clientes anteriores, y esquema
físico o mecanismo del lado servidor verificable. Esto no está
certificado en esta etapa. Issue Expressdelivery #141.

**Aprobación para actualizar clientes**: flujo de viaje/conductor,
permisos Android, KYC manual, mapa/ubicación y APK/AAB reales firmados
certificados por hashes, integración y rollback. No se logra con
pruebas de compilación Web únicamente.

## Recuperación

- Respaldo código Admin previo:
  `backup/2026-10-09-before-preview-production-safety`.
- SHA Producción Admin previo:
  `30e60582a337be3911671742d780b240793497df`.
- Web: restaurar Pages artefacto conocido de Producción y Preview
  anterior si falla una prueba; la reversión de Web NO deshace
  transacciones de Supabase.
- Backend/SQL: mantener reversión versionada y backup consistente;
  no ejecutar `DROP` ni restaurar base global para corregir un
  registro QA. No ejecutar despliegue Android ni Play Store aquí.
