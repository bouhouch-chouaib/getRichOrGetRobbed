#!/bin/bash
# rec.sh NOM SECONDES : filme la vue du jeu de Roblox Studio dans assets/store/video/rushes/NOM.mp4 (sans son).
# Capture de la fenêtre par Windows (ffmpeg 8+, filtre gfxcapture) : Studio peut rester derrière d'autres fenêtres,
# mais pas réduit. Avant de filmer (voir docs/PAGE_DU_JEU.md, « Vidéo de jeu ») : fenêtre de Studio en 1450 x 1102,
# panneaux Explorateur et Sortie fermés, la vue du jeu fait alors 1392 x 783 (16:9) à cet endroit de la fenêtre.
cd "$(dirname "$0")/../../assets/store/video"
mkdir -p rushes
ffmpeg -hide_banner -loglevel error -y \
  -filter_complex "gfxcapture=window_title='- Roblox Studio$':capture_cursor=0:crop_left=6:crop_top=181:crop_right=34:crop_bottom=91,hwdownload,format=bgra" \
  -t "$2" -c:v h264_nvenc -preset p6 -rc vbr -cq 15 -b:v 0 -pix_fmt yuv420p "rushes/$1.mp4"
echo "rushes/$1.mp4 $(ffprobe -v error -show_entries format=duration -of csv=p=0 "rushes/$1.mp4")"
