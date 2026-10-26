#!/bin/bash
# Montage de la vidéo de la page du jeu (docs/PAGE_DU_JEU.md, « Vidéo de jeu ») : plans de assets/store/video/rushes
# (filmés avec tools/video/rec.sh), 1920 x 1080, 30 i/s, légendes et titre à la police du jeu.
# Sans argument : piste son muette. Avec A ou B : la musique A (8 bits) ou B (moderne) de make_music.py.
# Résultat : assets/store/video/video_page_jeu.mp4 (moins de 60 s et de 100 Mo, limites de Roblox).
set -e
TOOLS="$(cd "$(dirname "$0")" && pwd)"
cd "$TOOLS/../../assets/store/video"
mkdir -p seg titles
rm -f seg/*.mp4

# Police LuckiestGuy : celle livrée avec Roblox (la même que l'interface du jeu).
FONT=$(ls "$LOCALAPPDATA"/Roblox/Versions/*/content/fonts/LuckiestGuy-Regular.ttf 2>/dev/null | head -1)
[ -z "$FONT" ] && FONT=$(ls /c/Users/*/AppData/Local/Roblox/Versions/*/content/fonts/LuckiestGuy-Regular.ttf | head -1)
python -I "$(cygpath -w "$TOOLS/make_titles.py")" "$(cygpath -w "$FONT")" "$(cygpath -w "$PWD/titles")"

VF_BASE="scale=1920:1080:flags=lanczos,unsharp=5:5:0.4,fps=30,format=yuv420p"
n=0

# seg SOURCE DEBUT DUREE [LEGENDE]
seg() {
  local src=$1 ss=$2 dur=$3 cap=$4
  n=$((n + 1))
  local out=$(printf "seg/%02d.mp4" $n)
  if [ -n "$cap" ]; then
    local fo=$(awk "BEGIN{print $dur - 0.45}")
    ffmpeg -hide_banner -loglevel error -y -ss "$ss" -t "$dur" -i "rushes/$src.mp4" -loop 1 -t "$dur" -i "titles/$cap.png" \
      -filter_complex "[0:v]setpts=PTS-STARTPTS,$VF_BASE[v];[1:v]format=rgba,fade=in:st=0.15:d=0.3:alpha=1,fade=out:st=$fo:d=0.3:alpha=1[c];[v][c]overlay=0:0:shortest=1,format=yuv420p" \
      -an -c:v libx264 -preset medium -crf 12 "$out"
  else
    ffmpeg -hide_banner -loglevel error -y -ss "$ss" -t "$dur" -i "rushes/$src.mp4" \
      -vf "setpts=PTS-STARTPTS,$VF_BASE" -an -c:v libx264 -preset medium -crf 12 "$out"
  fi
  echo "$out $src $ss +$dur $cap"
}

seg hole_night   0.0  4.0                 # le trou noir, palier 7
seg throw1       14.8 4.2  cap_throw      # objet au-dessus de la tête, visée, lancer
seg hatch2       10.0 9.3  cap_hatch      # œuf Divin qui tremble, éclosion, carte « QUELLE CHANCE », Dragon Aurore
seg base_day     0.3  4.5                 # la base et ses familiers
seg carry3       0.0  4.0  cap_carry      # le dragon porté au-dessus de la tête
seg w_volcan     5.0  3.0  cap_worlds     # mondes
seg w_glace      4.5  3.0
seg w_cosmos     5.0  3.0
seg w_divin      6.0  3.0
seg hole_volcan  9.5  2.5                 # le trou noir explose
seg collapse     0.0  2.0

# Fin : le nom du jeu sur le trou noir flouté et assombri
n=$((n + 1))
ffmpeg -hide_banner -loglevel error -y -ss 4.0 -t 3.5 -i rushes/hole_night.mp4 -loop 1 -t 3.5 -i titles/title_end.png \
  -filter_complex "[0:v]setpts=PTS-STARTPTS,$VF_BASE,gblur=sigma=6,eq=brightness=-0.12:saturation=1.1[v];[1:v]format=rgba,fade=in:st=0:d=0.35:alpha=1[t];[v][t]overlay=0:0:shortest=1,format=yuv420p" \
  -an -c:v libx264 -preset medium -crf 12 "$(printf "seg/%02d.mp4" $n)"

(cd seg && ls *.mp4) | sed "s/^/file '/; s/$/'/" > seg/list.txt
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i seg/list.txt -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
  -filter_complex "[0:v]fade=in:st=0:d=0.3[v]" -map "[v]" -map 1:a -shortest \
  -c:v libx264 -preset slow -crf 17 -maxrate 15M -bufsize 30M -profile:v high -level 4.2 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 128k -movflags +faststart seg/assemble.mp4
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 seg/assemble.mp4)
ffmpeg -hide_banner -loglevel error -y -i seg/assemble.mp4 -vf "fade=out:st=$(awk "BEGIN{print $D - 0.6}"):d=0.6" \
  -c:v libx264 -preset slow -crf 17 -maxrate 15M -bufsize 30M -profile:v high -level 4.2 -pix_fmt yuv420p \
  -c:a copy -movflags +faststart video_page_jeu.mp4

# Musique (bash tools/video/edit.sh A, ou B) : composée par tools/video/make_music.py, mise à -14 LUFS, sous la vidéo.
if [ -n "$1" ]; then
  mkdir -p music
  python -I "$(cygpath -w "$TOOLS/make_music.py")" "$(cygpath -w "$PWD/music")"
  I=$(ffmpeg -hide_banner -nostats -i "music/music_$1.wav" -af ebur128 -f null - 2>&1 | grep "I:" | tail -1 | awk '{print $2}')
  ffmpeg -hide_banner -loglevel error -y -i "music/music_$1.wav" -af "volume=$(awk "BEGIN{print -14 - ($I)}")dB" \
    -c:a pcm_s16le "music/music_$1_14.wav"
  mv video_page_jeu.mp4 seg/muette.mp4
  ffmpeg -hide_banner -loglevel error -y -i seg/muette.mp4 -i "music/music_$1_14.wav" -map 0:v -map 1:a -c:v copy \
    -c:a aac -b:a 192k -ar 48000 -shortest -movflags +faststart video_page_jeu.mp4
fi
ffprobe -v error -show_entries format=duration,size,bit_rate:stream=codec_name,width,height,r_frame_rate -of default=nw=1 video_page_jeu.mp4
