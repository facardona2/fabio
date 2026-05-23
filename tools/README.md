# 🛠 Tools — Mantenimiento Windows

Tenés 2 scripts:

| Script | Para qué | Frecuencia |
|--------|----------|------------|
| `optimizar-pc.bat` | Limpieza general + navegadores | mensual |
| `optimizar-arranque.bat` | Acelera el arranque de Windows | una vez (y revisar cada 2-3 meses) |

---

## `optimizar-arranque.bat`

Optimiza el **boot de Windows** y los programas que se cargan al iniciar.
Hace el arranque más rápido y libera RAM al inicio.

### Menú

| Opción | Qué hace |
|--------|----------|
| 1 | Lista programas que arrancan con Windows |
| 2 | Lista servicios automáticos |
| 3 | Desactiva bloatware común del arranque (OneDrive, Spotify, Teams, Xbox, Adobe Updater…) |
| 4 | Optimiza boot con `bcdedit` (timeout 3s, usa todos los núcleos, sin GUI) |
| 5 | Activa Fast Startup |
| 6 | Pone servicios innecesarios en MANUAL (telemetría, Xbox, Fax, etc.) |
| 7 | Desactiva tareas programadas de telemetría |
| 8 | Muestra tiempos de arranque de los últimos 10 boots |
| 9 | Genera **reporte HTML** en el Escritorio |
| **A** | Aplica TODO (con confirmación) |
| **R** | Restaurar valores por defecto si algo no te gustó |

### Lo bueno

- Todo es **reversible** (los servicios pasan a "Manual", no se eliminan).
- Te **pregunta antes** de los pasos riesgosos (servicios opcionales).
- Genera un reporte HTML para que veas el "antes y después".
- Muestra los tiempos de boot reales (medidos por Windows).

### Tiempos típicos después de optimizar

| Equipo | Antes | Después |
|--------|-------|---------|
| SSD NVMe | 20-30 s | **5-12 s** |
| SSD SATA | 30-50 s | **10-20 s** |
| HDD | 90-180 s | 30-60 s |

### Si algo se rompe

Corré la opción **R** (Restaurar) o desde un símbolo del sistema admin:

```bat
bcdedit /timeout 30
bcdedit /deletevalue quietboot
```

Para re-activar un servicio:
```bat
sc config <NombreServicio> start= auto
sc start <NombreServicio>
```

---

## `optimizar-pc.bat`

Script con menú interactivo para optimizar Windows + limpiar navegadores
(Brave, Chrome, Firefox, Edge) sin tocar tus datos personales.

### Cómo usarlo

1. Descargá el archivo `optimizar-pc.bat`
2. **Click derecho → Ejecutar como administrador**
   (si lo abrís normal, igual se auto-eleva pidiéndote permiso)
3. Elegí una opción del menú (o la **9** para hacer todo de una)

### Menú

| Opción | Qué hace | Tiempo aprox |
|--------|----------|--------------|
| 1 | Limpia temporales, prefetch, papelera | 1-2 min |
| 2 | DNS flush, reset Winsock, renueva IP | 30 seg |
| 3 | Verifica integridad (sfc + DISM + chkdsk al reiniciar) | 10-30 min |
| 4 | Repara Windows Update + limpia WinSxS | 5-15 min |
| 5 | TRIM en SSD / defrag en HDD | 5-20 min |
| 6 | Cache de Brave + Chrome + Firefox + Edge | 30 seg |
| 7 | Plan de energía "Rendimiento máximo" + apaga hibernación | 5 seg |
| 8 | Limpia logs del visor de eventos | 30 seg |
| **9** | **Todo lo anterior** (recomendado 1 vez por mes) | 30-60 min |

### Qué NO toca (a salvo)

- Bookmarks
- Contraseñas guardadas
- Sesiones abiertas / cookies de login
- Historial
- Extensiones
- Archivos personales (Documentos, Descargas, Escritorio…)
- Programas instalados

### Qué SÍ borra

- Caché del navegador (se regenera sola al usar)
- GPU Cache, Code Cache, Service Workers
- `%TEMP%` y `C:\Windows\Temp`
- Prefetch (Windows lo recrea)
- Logs de eventos
- Papelera de reciclaje

### Recomendaciones

- **Frecuencia**: opción 9 una vez al mes. Opciones 1 + 6 una vez por semana.
- **Reinicia después** de las opciones 3, 4 o 9 (chkdsk corre al boot).
- Si tenés una **VPN** o **DNS personalizado** (Cloudflare, NextDNS), la
  opción 2 los puede resetear; volvelos a configurar después.
- El script descomenta automáticamente líneas para forzar DNS de Cloudflare
  si querés; están comentadas por defecto.

### Si algo falla

- "Acceso denegado" → no estás en modo admin, cerralo y abrilo de nuevo
- DISM se cuelga → tu conexión es lenta, dejalo correr o cancelá con Ctrl+C
- Algún navegador no se cierra → cerrá manualmente y volvé a correr opción 6
