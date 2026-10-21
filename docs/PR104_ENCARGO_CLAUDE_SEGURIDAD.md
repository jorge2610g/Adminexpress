# Encargo vigente para Claude — PR #104 (Express Admin)

**20 octubre 2026. Autorizado por el propietario de EXPRESS.**

> IMPORTANTE: Este documento forma parte de la rama del **PR #104**, no de `main`.
> Es una orden de trabajo para preparar correcciones y entregarlas **en el mismo PR**,
> en estado **DRAFT**. No fusionar, desplegar, modificar Producción ni ejecutar
> migraciones sin autorización adicional y específica.

## Cómo comprobar las instrucciones

Repositorio: `jorge2610g/Adminexpress`  
PR: https://github.com/jorge2610g/Adminexpress/pull/104  
Rama: `redesign/admin-visual-operadores-20261020`  
Instrucciones anteriores: https://github.com/jorge2610g/Adminexpress/pull/104#issuecomment-6299986036  
Aclaraciones técnicas: https://github.com/jorge2610g/Adminexpress/pull/104#issuecomment-6300324990  
Autorización puntual de suspensión: https://github.com/jorge2610g/Adminexpress/pull/104#issuecomment-6300359191  
Resultado de suspensión: https://github.com/jorge2610g/Adminexpress/pull/104#issuecomment-6300451228

Si usas Claude Code con el clon local, **los comentarios de GitHub no son archivos locales**.
Para consultar el trabajo usa `gh pr view 104 --repo jorge2610g/Adminexpress --comments`
y para el archivo usa la rama indicada. No afirmes que no hay instrucciones sin
comprobar la descripción del PR y este archivo.

## Estado verificado — NO repetir acciones ya terminadas

- PR #104: abierto, en borrador, 54 archivos y cambios antiguos mezclados;
  divergente de `main`, con conflictos. No fusionar como está.
- PR #105 visual, #107 migraciones, #108 módulo operadores, #109 arranque y
  #111 delegación de permisos ya incorporaron trabajo a `main`.
  Primero comparar con `main` actual y evitar duplicados.
- `admin-create-operator` está ACTIVA en Supabase, verifica JWT y su código
  fue comparado exactamente con el de `main`. **No redeploy por inercia.**
- En Supabase se aplicaron fase 1, fase 2 y seis migraciones de operadores
  posteriores (capacidades, push, tarifas, pagos, suscripciones, activación).
  **No reaplicar** y no ampliar permisos sin pruebas.
- **Wilson Cruz**, `trinidad@operador.com`, Trinidad: suspensión administrativa
  **YA EJECUTADA** el 20/10/2026 a las 20:11 UTC y verificada por lectura
  posterior: `admin_users.active=false`, 0 operadores activos.
  **NO volver a desactivar, reactivar ni tocar esta cuenta.**
  No se revocó su token de sesión, pero se niegan llamadas siguientes.
- No presuponer que nueve funciones son nueve vulnerabilidades. Las funciones
  internas de cuenta, aprobación de conductor, SOS y perfil/documentos de
  conductor usan `is_admin()`, reservado al superadministrador. Auditar
  controles indirectos y permisos EXECUTE en vez de cambiar código sano.
- Riesgo concreto: `admin_landing_banner_save_v1` y
  `admin_landing_banners_list_v1` validan entorno y zona pero pueden omitir
  exigir el permiso de módulo delegado.
- `admin_assert_target_environment` comprueba entorno, no pertenencia por zona;
  no confundirlo con autorización de un objeto por ID.
- Push por zona: revisar `admin_send_announcement_v4` y su audiencia “Todos”
  para asegurar que nunca alcance personas de otras zonas.

## Encargo técnico — orden de trabajo

1. **Inventario y reconciliación.** Leer el estado real de `main`, este PR,
   los PR #105/#107/#108/#109/#111 y migraciones existentes. Crear una matriz
   de cambios ya publicados, correcciones pendientes y código legado
   no relacionado. No reintroducir funciones antiguas ni modificaciones
   sin conexión con esta auditoría. Si es seguro, resolver conflictos sin
   destruir historial; conservar respaldo antes de fusionar `main` a la
   rama. **Sin force-push ni rebase destructivo sin aprobación.**

2. **Auditoría real de seguridad.** Inventariar aproximadamente 158 funciones
   `SECURITY DEFINER` administrativas que reciben UUID, incluidas unas
   90 rutas de lectura/escritura por identificador y listas globales.
   Clasificar: rol requerido, módulo efectivo, zona obtenida del objeto,
   `EXECUTE`, RLS, control de entorno, otras llamadas SQL indirectas,
   vulnerabilidad demostrada, prueba y solución. **Negar por defecto**
   cuando un operador intente datos ajenos a su zona, módulo sin permiso,
   o acciones centrales. Superadministradores legítimos mantienen su alcance.

3. **Corregir brechas confirmadas**, especialmente banners/promociones si el
   operador carece de módulo asignado; mensajes push y campañas con
   audiencia “Todos”; permisos de detalle/escritura con IDs ajenos.
   Migraciones pequeñas y reversibles con prueba positiva/negativa,
   precondición/postcondición y SQL de rollback. **Prepararlas como archivos
   en la rama, NO aplicarlas a Producción**.

4. **Permisos de interfaz y ambiente.** Menú visible = entorno permitido ∩
   rol ∩ módulos EFECTIVOS que Supabase devuelve en `allowed_modules`;
   no confundir con módulos simplemente `assigned_modules` no listos.
   Ningún selector “Reales/Pruebas” cambia el entorno de una cuenta.
   Preview muestra el trabajo operativo y QA (Dashboard, Operación en vivo,
   Viajes, Despacho manual, Conductores, Usuarios, Seguridad/SOS, Delivery,
   Prioridad conductores, Campeonato, Entornos de prueba, Prueba de carga).
   Finanzas, configuración global, zonas y servicios compartidos se
   administran desde Producción; no duplicar configuración/zonas/datos
   administrativos en Prueba. Operador respeta siempre su zona y módulos.

5. **Operación en vivo.** Si `coverage_mode='polygon'`, dibujar el polígono
   guardado, no el radio legado; si es `radius`, dibujar círculo. La lectura
   de geometría para operadores debe estar limitada por zona y permiso.
   No cambiar polígonos ni zonas reales para corregir visualización.

6. **Alta de operadores.** `admin-create-operator`: validar JWT, rol
   central, asignación de zona y módulos, rollback/compensación de altas
   parciales, edición/suspensión/re-activación y ausencia de cuentas
   huérfanas. La coincidencia de código ya fue comprobada, pero el flujo
   funcional extremo a extremo todavía debe probarse.

7. **Pruebas obligatorias.** Probar con fixtures/reversión, sin escribir
   sobre clientes reales: superadmin; operador Trinidad vs Iquique,
   operador sin permiso, `anon`, módulos denegados, acceso a ID ajeno,
   lectura y escritura, QA vs real, notificaciones “Todos”, formularios
   y límites UI+RPC. `flutter analyze`, `flutter test`,
   `flutter build web`, tests SQL/Edge y workflows CI.
   Documentar aprobadas, fallidas y NO ejecutadas; jamás afirmar éxito
   sin prueba. Para crear cuentas temporales persistentes en Producción,
   solicitar consentimiento por separado.

8. **Limpieza**: los archivos de sesiones antiguas (marketplace,
   conductores, `partner_panel.dart`, `main.dart`, etc.) pueden tener
   cambios ya fusionados o no relacionados. No arrastrarlos a Producción.
   Mantener `analysis_options.yaml` fuera del PR. Comercios demo siguen
   ocultos en Producción y visibles en Prueba; no trasladar datos.
   Opcionales visuales (Despacho dos columnas; Pagos, Tarifas, Zonas,
   Reportes) quedan fuera de esta entrega de seguridad.

## Autorizaciones: límites no negociables

**SÍ:** investigar, leer, crear commits en esta rama del PR #104;
preparar SQL + rollback, pruebas simuladas o transacciones reversibles;
comentar evidencia.  
**NO:** modificar `main`, publicar web, fusionar PR, aplicar
`apply_migration`, publicar `deploy_edge_function`, cambiar cuentas
de producción (la suspensión puntual de Wilson ya fue utilizada),
reactivar operadores, forzar la rama ni pedir accesos globales del clasificador.
`get_edge_function` es lectura aceptable si las herramientas permiten;
no eludir bloqueos. Pedir autorización separada si algo adicional se requiere.

## Criterio de entrega a ChatGPT para revisión

Sube commits **en esta misma rama y PR #104**. Mantén DRAFT.
Al terminar, comenta:

- SHA final, archivos cambiados y qué código legado se retiró.
- Matriz `RPC | rol | módulo | zona | prueba negativa | resultado`.
- Hallazgos verdaderamente explotables, correcciones y riesgos residuales.
- Inventario de migraciones **preparadas vs. ya aplicadas**, y rollback.
- Resultados `analyze/test/build` y CI, con fallos y pruebas pendientes.
- Confirmación de que **no hubo despliegue a Producción ni más cambios
  en cuentas reales**.

**Detenerse y reportar si no hay forma segura de limpiar los conflictos
con `main` en este PR. Esperar revisión de ChatGPT y aprobación del propietario.**
