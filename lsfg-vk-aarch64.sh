#!/bin/bash

# ─────────────────────────────────────────────
#  lsfg-vk-aarch64.sh
#  Uso: sudo ./lsfg-vk-aarch64.sh start --real-frames <fps> --frames-multiplier <mult> [--flow-scale <0.20-1.00>]
# ─────────────────────────────────────────────

# ── Controllo root ─────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Errore: questo script deve essere eseguito con sudo."
    echo "Uso: sudo $0 start --real-frames <fps> --frames-multiplier <mult> [--flow-scale <0.20-1.00>]"
    exit 1
fi

# ── Rileva l'utente reale (chi ha chiamato sudo) ──
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_UID=$(id -u "$REAL_USER")

MAX_RATE=120
REAL_FRAMES=""
MULTIPLIER=""
FLOW_SCALE="0.80"

# ── Parsing argomenti ──────────────────────────
if [[ "$1" != "start" ]]; then
    echo "Uso: sudo $0 start --real-frames <fps> --frames-multiplier <mult> [--flow-scale <0.20-1.00>]"
    exit 1
fi
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --real-frames)
            REAL_FRAMES="$2"; shift 2 ;;
        --frames-multiplier)
            MULTIPLIER="$2"; shift 2 ;;
        --flow-scale)
            FLOW_SCALE="$2"; shift 2 ;;
        *)
            echo "Argomento sconosciuto: $1"
            exit 1 ;;
    esac
done

# ── Validazione ────────────────────────────────
if [[ -z "$REAL_FRAMES" || -z "$MULTIPLIER" ]]; then
    echo "Errore: --real-frames e --frames-multiplier sono obbligatori."
    exit 1
fi

if ! [[ "$REAL_FRAMES" =~ ^[0-9]+$ ]] || ! [[ "$MULTIPLIER" =~ ^[0-9]+$ ]]; then
    echo "Errore: --real-frames e --frames-multiplier devono essere numeri interi positivi."
    exit 1
fi

# Validazione flow-scale (deve essere un numero decimale tra 0.20 e 1.00)
if ! [[ "$FLOW_SCALE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Errore: --flow-scale deve essere un numero decimale (es. 0.80)."
    exit 1
fi

FLOW_INT=$(echo "$FLOW_SCALE * 100" | bc | cut -d. -f1)
if [[ "$FLOW_INT" -lt 20 || "$FLOW_INT" -gt 100 ]]; then
    echo "Errore: --flow-scale deve essere compreso tra 0.20 e 1.00 (valore inserito: ${FLOW_SCALE})."
    exit 1
fi

TARGET_RATE=$(( REAL_FRAMES * MULTIPLIER ))

if [[ "$TARGET_RATE" -gt "$MAX_RATE" ]]; then
    MAX_MULT=$(( MAX_RATE / REAL_FRAMES ))
    echo "Errore: ${REAL_FRAMES} fps x ${MULTIPLIER} = ${TARGET_RATE} Hz supera il massimo consentito (${MAX_RATE} Hz)."
    if [[ "$MAX_MULT" -ge 1 ]]; then
        echo "  Moltiplicatore massimo consentito per ${REAL_FRAMES} fps: ${MAX_MULT} (-> $(( REAL_FRAMES * MAX_MULT )) Hz)"
    else
        echo "  Attenzione: ${REAL_FRAMES} fps da soli superano gia i ${MAX_RATE} Hz. Riduci i real-frames."
    fi
    exit 1
fi

echo "── Configurazione ───────────────────────────"
echo "  Utente         : ${REAL_USER} (UID: ${REAL_UID})"
echo "  Home           : ${REAL_HOME}"
echo "  Real frames    : ${REAL_FRAMES} fps"
echo "  Moltiplicatore : x${MULTIPLIER}"
echo "  Target rate    : ${TARGET_RATE} Hz"
echo "  Flow scale     : ${FLOW_SCALE}"
echo "─────────────────────────────────────────────"

# ── 1. Imposta il refresh rate del monitor ─────
echo "[1/3] Impostazione xrandr a ${TARGET_RATE} Hz..."
DISPLAY=:0 XAUTHORITY="${REAL_HOME}/.Xauthority" \
    xrandr --output HDMI-1 --mode 1920x1080 --rate "${TARGET_RATE}"

if [[ $? -ne 0 ]]; then
    echo "Errore: xrandr non e riuscito a impostare ${TARGET_RATE} Hz."
    exit 1
fi

# ── 2. Avvia MPV con LSFG-VK ──────────────────
echo "[2/3] Avvio MPV con frame generation (x${MULTIPLIER})..."
nice -n -20 sudo -u "$REAL_USER" env \
    DISPLAY=:0 \
    XAUTHORITY="${REAL_HOME}/.Xauthority" \
    XDG_RUNTIME_DIR="/run/user/${REAL_UID}" \
    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/panfrost_icd.json \
    VK_LOADER_LAYERS_DISABLE=~implicit~ \
    VK_INSTANCE_LAYERS=VK_LAYER_LSFGVK_frame_generation \
    LSFGVK_ENV=1 \
    LSFGVK_DLL_PATH="${REAL_HOME}/Lossless.dll" \
    LSFGVK_MULTIPLIER="${MULTIPLIER}" \
    LSFGVK_PERFORMANCE_MODE=1 \
    LSFGVK_FLOW_SCALE="${FLOW_SCALE}" \
    mpv --no-config --vo=gpu --gpu-api=vulkan --gpu-context=x11vk --audio=no \
        --cache=no --demuxer-readahead-secs=0 --video-sync=desync --framedrop=vo \
        --profile=low-latency --fullscreen --untimed \
        --demuxer-max-bytes=1MiB --demuxer-max-back-bytes=1MiB \
        --vd-lavc-threads=1 --vd-lavc-skiploopfilter=all \
        --demuxer=lavf --demuxer-lavf-format=video4linux2 \
        --demuxer-lavf-o=input_format=nv12,video_size=1920x1080,framerate="${REAL_FRAMES}",fflags=nobuffer+fastseek,flags=low_delay,probesize=32,analyzeduration=0,avioflags=direct,buffersize=0 \
        /dev/video5 &

MPV_PID=$!
echo "  MPV avviato (PID: ${MPV_PID})"

# ── 3. Avvia il passthrough audio ─────────────
echo "[3/3] Avvio passthrough audio..."
arecord -D plughw:CARD=2,DEV=0 -f S16_LE -c2 -r48000 | \
    aplay -D default -f S16_LE -c2 -r48000 &

AUDIO_PID=$!
echo "  Audio avviato (PID: ${AUDIO_PID})"

echo ""
echo "Tutto avviato. Premi Ctrl+C per fermare."

# ── Cleanup alla chiusura ──────────────────────
cleanup() {
    echo ""
    echo "Arresto in corso..."
    kill "${MPV_PID}" "${AUDIO_PID}" 2>/dev/null
    wait "${MPV_PID}" "${AUDIO_PID}" 2>/dev/null

    echo "Ripristino xrandr a ${MAX_RATE} Hz..."
    DISPLAY=:0 XAUTHORITY="${REAL_HOME}/.Xauthority" \
        xrandr --output HDMI-1 --mode 1920x1080 --rate "${MAX_RATE}"

    echo "Fatto."
    exit 0
}

trap cleanup SIGINT SIGTERM

wait "${MPV_PID}"
cleanup
