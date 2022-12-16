#!/bin/bash

function compresscover() {
    rawpath="$1"
    imgpath="$(sed 's/cover-raw/cover/' <<< "$rawpath" | sed 's/.png$/.jpg/')"
    if [[ -e $imgpath ]] && [[ $(date -r $rawpath +%s) -lt $(date -r $imgpath +%s) ]]; then
        return 0
    fi
    echo "$rawpath" '->' "$imgpath"
    convert "$rawpath" -quality 89 "$imgpath"
}


case $1 in
    tex)
        ### Usage example:  ./build.sh tex journal/2023/2023-01.tex
        texfile="$2"
        xelatex -interaction=scrollmode -output-directory=".tmp" "$texfile"
        output_pdf=".tmp/$(basename "$texfile" | sed 's/tex$/pdf/')"
        final_dir="_dist/$(dirname "$texfile" | cut -c1-)"
        mkdir -p "$final_dir"
        final_path="$final_dir/$(basename "$output_pdf")"
        # echo "final_dir = $final_dir"
        mv "$output_pdf" "$final_path"
        du -h "$final_path"
        ;;
    alltex)
        for texfile in $(find journal -name '*.tex'); do
            bash build.sh tex "$texfile"
            bash build.sh tex "$texfile"
        done
        ;;
    cover)
        mkdir -p large-assets/cover{,-raw}
        for rawpath in large-assets/cover-raw/*; do
            compresscover "$rawpath"
        done
        ;;
    full|'')
        echo "Starting full build..."
        ;;
esac
