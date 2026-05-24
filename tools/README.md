# Tools - Mantenimiento Windows

4 scripts para optimizar tu PC. Todos:
- Se **auto-elevan a admin** (UAC)
- Tienen **menu interactivo**
- Son **reversibles**
- **No tocan datos personales** (bookmarks, passwords, archivos)

| Orden recomendado | Script | Para que | Frecuencia |
|-------------------|--------|----------|------------|
| 1 | `optimizar-pc.bat` | Limpieza general + navegadores | mensual |
| 2 | `optimizar-arranque.bat` | Acelera el boot de Windows | una vez |
| 3 | `optimizar-rendimiento.bat` | RAM, memoria virtual, liberar C:, alto rendimiento | una vez + puntual |
| 4 | `acelerar-red.bat` | TCP, DNS rapido, gaming, streaming | una vez (revisar si cambias ISP) |

---

## `acelerar-red.bat` 🌐

Optimiza tu conexion: latencia, throughput, DNS, gaming.

| Opcion | Que hace |
|--------|----------|
| 1 | Diagnostico (adaptadores, DNS, ping, estado TCP) |
| **2** | **DNS rapido**: Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9, OpenDNS |
| **3** | **TCP/IP**: autotuning, RSS multi-core, ECN, CUBIC, timestamps off |
| **4** | **Gaming**: Nagle off, TcpAckFrequency=1, MMCSS prioridad alta, QoS sin reserva |
| 5 | NIC: quita power saving, activa RSS en la tarjeta |
| 6 | Reset stack de red (DNS+Winsock+IP) |
| 7 | Test de velocidad y ping a 5 servidores |
| 8 | Streaming: ventana TCP grande para 4K/video |
| **9** | **APLICAR TODO** (gaming + DNS + TCP) |
| R | Restaurar valores por defecto |

### Mejoras tipicas

| Metrica | Antes | Despues |
|---------|-------|---------|
| Ping a Cloudflare | 25-40 ms | 5-15 ms |
| Resolucion DNS | 80-200 ms | 5-20 ms |
| Latencia gaming (CS, Valorant) | 30-50 ms | 15-25 ms |
| Buffering YouTube 4K | a veces | nunca |

---

## `optimizar-rendimiento.bat` ⚡

| Opcion | Que hace |
|--------|----------|
| 1 | Analisis de C: con top 15 carpetas mas pesadas |
| 2 | Busca archivos >500 MB |
| **3** | **Liberar agresivo**: Windows.old, cache WU, dumps, WER, shaders |
| **4** | **Memoria Virtual** optima segun tu RAM (detecta automatico) |
| 5 | Liberar RAM en uso (working sets) |
| 6 | Efectos visuales para rendimiento |
| **7** | **Alto Rendimiento** + sin throttling + Modo Juego |
| 8 | Quitar IE, WMP legacy, apps inutiles |
| 9 | Defender optimizado (limita CPU, excluye cache) |
| A | WinSxS cleanup (libera 5-15 GB) |
| B | Asistente mover Documentos/Descargas |
| **C** | **APLICAR TODO** |

Tipicamente libera **20-60 GB** en la primera corrida.

---

## `optimizar-arranque.bat` 🚀

| Opcion | Que hace |
|--------|----------|
| 1-2 | Ver programas y servicios que arrancan |
| **3** | Quitar bloatware (OneDrive, Spotify, Teams, Xbox, Adobe...) |
| **4** | Optimizar boot (timeout 3s, todos los nucleos) |
| 5 | Fast Startup |
| **6** | Servicios innecesarios en manual |
| 7 | Desactivar telemetria |
| 8 | Ver tiempos reales de los ultimos boots |
| 9 | Reporte HTML en el Escritorio |
| A | Aplicar todo |
| R | Restaurar |

Mejora boot: **20-30s → 5-12s** en SSD NVMe.

---

## `optimizar-pc.bat` 🧹

Limpieza general - corre esto una vez al mes.

| Opcion | Que hace |
|--------|----------|
| 1 | Temporales + Prefetch + Papelera |
| 2 | DNS flush, Winsock reset |
| 3 | sfc + DISM + chkdsk al reiniciar |
| 4 | Reparar Windows Update |
| 5 | TRIM/defrag |
| 6 | Cache de Brave/Chrome/Firefox/Edge |
| 7 | Plan Rendimiento Maximo |
| 8 | Limpiar logs |
| 9 | Todo |

---

## Como usarlos

1. Descargar el .bat
2. **Click derecho - Ejecutar como administrador**
3. Elegir opcion del menu

Si la ventana se cierra de golpe, abre **CMD como admin** y ejecutalo desde ahi:
```cmd
cd C:\ruta\al\bat
optimizar-pc.bat
```
Asi ves el error completo aunque algo falle.

## Orden recomendado primera vez

```
1) optimizar-pc.bat        -> opcion 9
2) optimizar-arranque.bat  -> opcion A
3) optimizar-rendimiento.bat -> opcion C
4) acelerar-red.bat        -> opcion 9
5) REINICIAR
```

Despues de eso:
- Boot ~5-12s
- 20-60 GB libres en C:
- Mas FPS y menos lag
- DNS resolviendo en <20ms
