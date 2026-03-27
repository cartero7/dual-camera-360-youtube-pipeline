# Pendientes cuando haya camaras conectadas

## Validaciones obligatorias

- confirmar que ambas URLs RTSP reales entregan video estable
- confirmar canal correcto `101` frente a posibles `102/103/104`
- verificar si ambas camaras entregan exactamente el mismo fps y resolucion
- revisar latencia relativa entre hemisferios
- comprobar si conviene `tcp` o `udp` en el entorno real

## Ajustes finos de imagen

- recalibrar `CAM1_CROP`
- recalibrar `CAM2_CROP`
- validar si `V360_IH_FOV=190` y `V360_IV_FOV=190` son correctos o deben cambiar
- comprobar si hace falta desplazar uno de los hemisferios antes del `hstack`
- revisar costura visible en zonas de union

## Validaciones de estabilidad

- dejar el pipeline local corriendo al menos 30 minutos
- observar si aparecen `drop`, `dup`, `Thread message queue blocking` o `speed<1.0x`
- medir uso real de CPU y RAM
- medir tambien el ritmo de escritura a disco
- verificar que el watchdog reinicia correctamente
- verificar que aparece al menos un segmento por minuto
- verificar que los segmentos se pueden abrir con `ffprobe`

## Validaciones con YouTube

- crear el evento en YouTube Studio con `Video 360` activado
- comprobar salud del stream en el panel de control
- confirmar que la salida se interpreta como 360 y no como video plano
- comprobar si la resolucion base elegida es suficiente o conviene subir a `2560x1280`
- comprobar que si YouTube falla, la grabacion local continua
- verificar si la congelacion real de una sola camara sigue produciendo segmentos aparentemente validos; ese caso puede requerir una sonda de calidad mas avanzada

## Si algo falla

- primer retroceso: mantener `15 fps` y bajar a `1600x800`
- segundo retroceso: mantener `1920x960` pero usar clip local en lugar de YouTube para aislar problema
- tercer retroceso: probar una sola camara para descartar origen RTSP
