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
# function compress_journal() {
#     rawpath="$1"
#     imgpath="$(sed 's/cover-raw/cover/' <<< "$rawpath" | sed 's/.[a-zA-Z]*$/.jpg/')"
#     if [[ -e $imgpath ]] && [[ $(date -r $rawpath +%s) -lt $(date -r $imgpath +%s) ]] && [[ -z $FORCE ]]; then
#         return 0
#     fi
#     # if [[ ]]
#     du -h "$rawpath"
#     echo "imgpath = $imgpath"
#     return 0
#     echo "Converting...   $rawpath  ->  $imgpath"
#     convert "$rawpath" -quality 89 "$imgpath"
#     du -h "$rawpath" "$imgpath"
# }







if [[ ! -z $2 ]]; then
    for i in $*; do
        bash build.sh "$i" &
    done
    exit
fi



case "$1" in
    *.tex)
        ### Usage example:  ./build.sh tex journal/2023/2023-01.tex
        texfile="$1"
        mkdir -p .tmp
        xelatex -interaction=scrollmode -output-directory=".tmp" "$texfile"
        output_pdf=".tmp/$(basename "$texfile" | sed 's/tex$/pdf/')"
        final_dir="_dist/$(dirname "$texfile" | cut -c1-)"
        mkdir -p "$final_dir"
        final_path="$final_dir/$(basename "$output_pdf")"
        mv "$output_pdf" "$final_path"
        du -h "$(realpath "$final_path")"
        ### If the operating user is Neruthes
        if [[ "$USER" == neruthes ]]; then
            ### Generate cover image
            pdfrange "$final_path" 1-1 .tmp
            jpgpath="$(realpath "$(pdftoimg ".tmp/$(basename "$final_path" | cut -c1-8)_page1-1.pdf" _dist/covers)")"
            du -h "$jpgpath"
        fi
        if [[ "$USER" == neruthes ]] && [[ -z "$NOUPLOAD" ]]; then
            ### Upload now 
            bash build.sh osspdf "$final_path"
            shareDirToNasPublic
        fi
        ;;
    *A.pdf | *B.pdf | *.tar | *.zip)
        uploadFn="$1"
        echo "[INFO] Uploading '$uploadFn'"
        OSSURL="$(OSS_SUBDIR=ysplayerjournal cfoss "$uploadFn" | grep FINAL_HTTP_URL | cut -d= -f2-)"
        echo "$uploadFn $OSSURL"
        echo "$uploadFn $OSSURL" >> .osslist
        sort -u .osslist -o .osslist
        ;;
    alltex)
        for texfile in $(find journal -name '*.tex'); do
            bash build.sh tex "$texfile"
            bash build.sh tex "$texfile"
        done
        ;;
    large-assets/cover*)
        mkdir -p large-assets/cover{,-raw}
        for rawpath in large-assets/cover-raw/*; do
            compress_cover "$rawpath"
        done
        ;;
    pkgdist | pkgdist/)
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
    deploy)
        git add .
        git commit -m "Automatic deploy command: $(TZ=UTC date -Is | cut -c1-19 | sed 's/T/ /')"
        git push
        if [[ $USER == neruthes ]]; then
            ### 1. nas-public   https://nas-public-zt.neruthes.xyz/ysplayerjournal-f681b66df3384d4ed08719ce/
            shareDirToNasPublic -e
            ### 2. Dropbox      https://www.dropbox.com/sh/mmbdbv6xcqyrg7x/AAD-fGMnNeK0eiEpatnpWYyFa?dl=0
            for dropboxdir in pkgdist _dist; do
                rclone sync -P -L  $dropboxdir  dropbox-main:devdistpub/ysplayerjournal/$dropboxdir
            done
        fi
        ;;
    mklist)
        for pdfpath in $(find _dist -name '*.pdf' | sort -r); do
            pdffn="$(basename $pdfpath)"
            pdfyear="${pdffn:0:4}"
            pdfmon="${pdffn:5:3}"
            echo "- [${pdfyear} 年 $( sed 's/A/ 月（上）/' <<< "$pdfmon" | sed 's/B/ 月（下）/' )](https://neruthesgithubdistweb.vercel.app/ysplayerjournal/${pdfpath:6})" >> .mklist.md
        done
        mv .mklist.md ISSUES_LIST.md
        cat ISSUES_LIST.md
        ;;
    test)
        rm -rf .cloudbuildroot/*
        cd .cloudbuildroot
        tar -pxvf ../pkgdist/pdfdist.tar
        tree
        ;;
    full|'')
        echo "Starting full build..."
        bash build.sh pkgdist pkgdist/*.{tar,zip} deploy
        ;;
    *)
        echo "[ERROR] No rule to make '$1'. Stopping."
        ;;
esac
