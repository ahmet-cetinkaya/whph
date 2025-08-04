#!/bin/bash

echo "Converting Opus files to MP3 for windows platform compatibility..."
echo

converted=0
errors=0

# Get the script directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname "$script_dir")"

# Find all .opus files recursively
while IFS= read -r -d '' opus_file; do
    # Generate MP3 filename
    mp3_file="${opus_file%.opus}.mp3"
    
    echo "Converting: $(basename "$opus_file")"
    
    # Check if MP3 already exists
    if [[ -f "$mp3_file" ]]; then
        echo "  - MP3 already exists, skipping"
    else
        # Convert using ffmpeg
        if ffmpeg -i "$opus_file" -acodec mp3 -ab 192k "$mp3_file" -y >/dev/null 2>&1; then
            echo "  - Successfully converted to MP3"
            ((converted++))
        else
            echo "  - ERROR: Conversion failed"
            ((errors++))
        fi
    fi
    echo
done < <(find "$project_root" -name "*.opus" -type f -print0)

echo
echo "=== Conversion Summary ==="
echo "Files converted: $converted"
echo "Errors: $errors"

if [[ $errors -gt 0 ]]; then
    echo
    echo "Note: FFmpeg is required for conversion. Install it from https://ffmpeg.org/"
    exit 1
fi

echo
echo "Conversion completed successfully!"
exit 0