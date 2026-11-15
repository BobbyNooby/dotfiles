alias ytmp4='yt-dlp -f "bestvideo+bestaudio" --remux-video mp4'
alias ytmp3='yt-dlp -x --audio-format mp3 --audio-quality 0'

# Download a video and compress it to fit Discord's upload limit (default 50MB, Nitro Basic)
# Usage: ytdiscord <url> [max_mb]  ->  saves to ~/Downloads/<title> [discord].mp4
ytdiscord() {
  emulate -L zsh
  local url="$1" max_mb="${2:-50}"
  [[ -z "$url" ]] && { echo "usage: ytdiscord <url> [max_mb]"; return 1 }

  local tmp="/tmp/ytdiscord_$$.mkv"
  local passlog="/tmp/ytdiscord_pass_$$"

  yt-dlp -f "bv*+ba/b" -S "res:720" --merge-output-format mkv -o "$tmp" "$url" || return 1

  local dur
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp") || return 1
  dur="${dur%%.*}"

  local audio_kbits=96
  local video_kbits=$(( max_mb * 8192 * 95 / 100 / dur - audio_kbits ))
  (( video_kbits < 100 )) && { echo "video too long to fit in ${max_mb}MB"; rm -f "$tmp" "$passlog"*; return 1 }
  (( video_kbits > 8000 )) && video_kbits=8000

  local out="$HOME/Downloads/$(yt-dlp --print title --skip-download "$url" | tr '/:' '-' | cut -c1-80) [discord].mp4"

  ffmpeg -y -v error -i "$tmp" -c:v libx264 -b:v "${video_kbits}k" -preset medium \
    -vf "scale=-2:'min(720,ih)'" -an -pass 1 -passlogfile "$passlog" -f mp4 /dev/null &&
  ffmpeg -y -v error -i "$tmp" -c:v libx264 -b:v "${video_kbits}k" -preset medium \
    -vf "scale=-2:'min(720,ih)'" -c:a aac -b:a "${audio_kbits}k" -movflags +faststart \
    -pass 2 -passlogfile "$passlog" "$out" || { rm -f "$tmp" "$passlog"*; return 1 }

  rm -f "$tmp" "$passlog"*
  echo "saved: $out ($(du -h "$out" | cut -f1))"
}
