# Dual-Camera 360 YouTube Pipeline

Pipeline para generar y emitir video 360 a YouTube Live a partir de dos camaras individuales.

La idea del proyecto es simple:

- la camara 1 aporta un hemisferio
- la camara 2 aporta el otro hemisferio
- ambos streams RTSP se recortan, se unen y se transforman a equirectangular con `v360`
- la salida final se puede enviar a YouTube y grabar localmente al mismo tiempo

Pipeline principal:

`RTSP cam1 + RTSP cam2 -> crop -> hstack -> v360(dfisheye->equirect) -> H.264/AAC -> YouTube RTMPS + recording`

## Estructura

```text
youtube360_next/
  bin/
  config/
  docs/
  scripts/
  systemd/
```

## Configuracion

Parte de [config/youtube360.env.example](/home/carla/cam/360_streaming/youtube360_next/config/youtube360.env.example) y crea tu copia local en `config/youtube360.env`.

`config/youtube360.env` no debe versionarse porque puede contener credenciales RTSP y la `STREAM_KEY`.

Parametros principales:

- `URL_RTSP_CAM1`
- `URL_RTSP_CAM2`
- `YOUTUBE_RTMP_URL`
- `STREAM_KEY`
- `OUTPUT_MODE`
- `FPS`
- `OUTPUT_WIDTH`
- `OUTPUT_HEIGHT`
- `BITRATE_VIDEO`
- `BITRATE_AUDIO`
- `GOP`

Parametros que seguramente tocaras para recalibrar:

- `CAM1_CROP`
- `CAM2_CROP`
- `V360_IH_FOV`
- `V360_IV_FOV`
- `CAM1_FISHEYE_CENTER_OFFSET_X`
- `CAM1_FISHEYE_CENTER_OFFSET_Y`
- `CAM2_FISHEYE_CENTER_OFFSET_X`
- `CAM2_FISHEYE_CENTER_OFFSET_Y`
- `CAM1_PRE_ROTATE`
- `CAM2_PRE_ROTATE`
- `CAM1_HFLIP`
- `CAM2_HFLIP`
- `CAM1_VFLIP`
- `CAM2_VFLIP`
- `AUTO_ADJUST_CROP`

## Uso rapido

Comprobar dependencias y configuracion:

```bash
./bin/youtube360 env-check
```

Validar YouTube:

```bash
./bin/youtube360 youtube-preflight
```

Validar camaras:

```bash
./bin/youtube360 validate-cameras
```

Validar crops:

```bash
./bin/youtube360 validate-crops
```

Generar previews de calibracion:

```bash
./bin/youtube360 calibration-test cam1
./bin/youtube360 calibration-test cam2
./bin/youtube360 calibration-test equirect
```

Barridos de calibracion:

```bash
./bin/youtube360 calibration-sweep cam1
./bin/youtube360 calibration-sweep cam2
./bin/youtube360 calibration-sweep equirect
```

Arranque manual:

```bash
./bin/youtube360 stream-youtube
./bin/youtube360 watchdog
```

## Dónde mirar

- operacion y watchdog: [docs/OPERATIONS.md](/home/carla/cam/360_streaming/youtube360_next/docs/OPERATIONS.md)
- pendientes de ajuste con hardware real: [docs/pending_with_cameras.md](/home/carla/cam/360_streaming/youtube360_next/docs/pending_with_cameras.md)
- servicio systemd: [systemd/youtube360.service](/home/carla/cam/360_streaming/youtube360_next/systemd/youtube360.service)
- configuracion de ejemplo: [config/youtube360.env.example](/home/carla/cam/360_streaming/youtube360_next/config/youtube360.env.example)

## Credits & License

**System Design & Development:**

- Carla Artero Delgado
- Universitat Politècnica de Catalunya (UPC)
- Catalunya
- Email: carola.artero@upc.edu

**Project:** Dual-Camera 360 YouTube Pipeline

**Technologies:** Bash, FFmpeg, FFprobe, systemd

**Repository:** `dual-camera-360-youtube-pipeline`

**License:** Pending

Made for 360 live streaming and calibration.
