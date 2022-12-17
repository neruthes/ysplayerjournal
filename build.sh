#!/bin/bash

REPODIR="$PWD"




function compress_cover() {
    rawpath="$1"
    imgpath="$(sed 's/cover-raw/cover/' <<< "$rawpath" | sed 's/.png$/.jpg/')"
    if [[ -e $imgpath ]] && [[ $(date -r $rawpath +%s) -lt $(date -r $imgpath +%s) ]] && [[ -z $FORCE ]]; then
        return 0
    fi
    echo "Converting...   $rawpath  ->  $imgpath"
    convert "$rawpath" -quality 89 "$imgpath"
    du -h "$rawpath" "$imgpath"
}
function compress_journal() {
    rawpath="$1"
    imgpath="$(sed 's/cover-raw/cover/' <<< "$rawpath" | sed 's/.[a-zA-Z]*$/.jpg/')"
    if [[ -e $imgpath ]] && [[ $(date -r $rawpath +%s) -lt $(date -r $imgpath +%s) ]] && [[ -z $FORCE ]]; then
        return 0
    fi
    # if [[ ]]
    du -h "$rawpath"
    echo "imgpath = $imgpath"
    return 0
    echo "Converting...   $rawpath  ->  $imgpath"
    convert "$rawpath" -quality 89 "$imgpath"
    du -h "$rawpath" "$imgpath"
}





case $1 in
    tex)
        ### Usage example:  ./build.sh tex journal/2023/2023-01.tex
        texfile="$2"
        mkdir -p .tmp
        xelatex -interaction=scrollmode -output-directory=".tmp" "$texfile"
        output_pdf=".tmp/$(basename "$texfile" | sed 's/tex$/pdf/')"
        final_dir="_dist/$(dirname "$texfile" | cut -c1-)"
        mkdir -p "$final_dir"
        final_path="$final_dir/$(basename "$output_pdf")"
        mv "$output_pdf" "$final_path"
        du -h "$(realpath "$final_path")"
        ### Upload now if the operating user is Neruthes
        if [[ "$USER" == neruthes ]] && [[ -z "$NOUPLOAD" ]]; then
            bash build.sh osspdf "$final_path"
            shareDirToNasPublic
        fi
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
            compress_cover "$rawpath"
        done
        ;;
    pkgdist)
        ### pdfdist
        cd _dist
        tar -cvf ../pkgdist/pdfdist.tar ./
        cd "$REPODIR"
        ### large-assets
        zip -9vr pkgdist/large-assets large-assets
        ### cover-raw
        zip -9vr pkgdist/cover-raw large-assets/cover-raw
        ### fullrepo
        tar -cvf pkgdist/ysplayerjournal-full.tar \
            --exclude .git \
            --exclude .tmp \
            --exclude .cloudbuildroot \
            --exclude .private \
            --exclude pkgdist \
            ./
        ### End
        du -h pkgdist/*
        ;;
    test)
        rm -rf .cloudbuildroot/*
        cd .cloudbuildroot
        tar -pxvf ../pkgdist/pdfdist.tar
        tree
        ;;
    osspdf)
        pdffn="$2"
        OSSURL="$(OSS_SUBDIR=ysplayerjournal cfoss "$pdffn" | grep FINAL_HTTP_URL | cut -d= -f2-)"
        echo "$pdffn $OSSURL"
        echo "$pdffn $OSSURL" >> .osslist
        sort -u .osslist -o .osslist
        ;;
    full|'')
        echo "Starting full build..."
        ;;
esac
