# OPERATIONS

## Comportamiento nuevo del watchdog

El watchdog ahora reinicia el pipeline completo cuando detecta que la subida RTMP/RTMPS a YouTube ya no es valida aunque `ffmpeg` siga vivo localmente.

Casos cubiertos:

- `Error in the push function`
- `IO error: Broken pipe`
- `Slave muxer #0 failed: Broken pipe, continuing with 1/2 slaves`
- otros errores de escritura RTMP/RTMPS equivalentes

Esto evita el caso silencioso en el que la grabacion local sigue bien, `progress.last` sigue avanzando y la emision remota ya esta cortada.

Ademas, antes de cada relanzamiento:

- toma un lock de watchdog
- mata cualquier `ffmpeg` residual del proyecto
- mata cualquier `run_ffmpeg_once.sh` residual del proyecto
- valida por `pgrep` que no quede otra instancia activa

Esto reduce el riesgo del error de YouTube `same ingestion URL used`.

## Logs

Revisar:

- `runtime/logs/current/ops/watchdog_*.log`
- `runtime/logs/current/ops/stream_youtube_*.log`
- `runtime/state/progress.last`

Ahora el watchdog deja mensajes con:

- timestamp
- causa del reinicio
- detalle de la ultima linea relevante cuando aplica
- cuando mata un `ffmpeg`
- cuando lanza un nuevo `ffmpeg` y con que PID

Ejemplo esperado:

```text
[2026-03-25 10:00:00] [ERROR] Detectados 1 errores RTMP/RTMPS relevantes en los ultimos 120s
[2026-03-25 10:00:00] [ERROR] RTMP reciente: [tee @ 0x1] Slave muxer #0 failed: Broken pipe, continuing with 1/2 slaves.
[2026-03-25 10:00:00] [ERROR] Reinicio solicitado: Emision remota RTMP/RTMPS caida con ffmpeg vivo
```

## Anti-loop

Hay dos limites:

- `MAX_RESTARTS`
- `RESTART_LOOP_THRESHOLD` dentro de `RESTART_LOOP_WINDOW_SECONDS`

El segundo limita bucles rapidos aunque `MAX_RESTARTS=0`.

Valores por defecto actuales:

- `RESTART_LOOP_WINDOW_SECONDS=300`
- `RESTART_LOOP_THRESHOLD=6`

## Verificacion local

Comprobacion minima recomendada:

```bash
./bin/youtube360 env-check
./scripts/check_single_instance.sh
```
