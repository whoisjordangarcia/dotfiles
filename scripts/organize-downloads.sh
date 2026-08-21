#!/opt/homebrew/bin/bash

DOWNLOADS="$HOME/Downloads"

declare -A CATEGORIES=(
  ["Images"]="jpg jpeg png gif bmp svg webp ico tiff tif heic heif raw cr2 nef"
  ["Documents"]="pdf doc docx xls xlsx ppt pptx txt rtf odt ods odp csv md pages numbers keynote"
  ["Videos"]="mp4 avi mkv mov wmv flv webm m4v mpg mpeg ts"
  ["Audio"]="mp3 wav flac aac ogg wma m4a opus"
  ["Archives"]="zip tar gz bz2 7z rar xz tgz deb rpm dmg iso"
  ["Code"]="py js ts jsx tsx go rs rb php java c cpp h hpp swift sh bash zsh json xml yaml yml toml sql html css scss"
  ["Executables"]="exe app msi pkg apk"
  ["Fonts"]="ttf otf woff woff2 eot"
)

categorize_file() {
  local file="$1"
  local ext="${file##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

  if [[ "$file" == "$ext" ]]; then
    echo "Other"
    return
  fi

  for category in "${!CATEGORIES[@]}"; do
    for valid_ext in ${CATEGORIES[$category]}; do
      if [[ "$ext" == "$valid_ext" ]]; then
        echo "$category"
        return
      fi
    done
  done

  echo "Other"
}

find "$DOWNLOADS" -maxdepth 1 -type f -mtime +0 | while read -r file; do
  category=$(categorize_file "$file")
  dest="$DOWNLOADS/$category"
  mkdir -p "$dest"

  basename="$(basename "$file")"
  target="$dest/$basename"

  if [[ -e "$target" ]]; then
    name="${basename%.*}"
    ext="${basename##*.}"
    counter=1
    if [[ "$name" == "$ext" ]]; then
      while [[ -e "$dest/${name}_${counter}" ]]; do
        ((counter++))
      done
      target="$dest/${name}_${counter}"
    else
      while [[ -e "$dest/${name}_${counter}.${ext}" ]]; do
        ((counter++))
      done
      target="$dest/${name}_${counter}.${ext}"
    fi
  fi

  mv "$file" "$target"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | Moved: $(basename "$file") -> $category/"
done
