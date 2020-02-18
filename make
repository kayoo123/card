#!/bin/sh -e
#
# Simple static site builder.
#
# Cron: # * * * * * kayoo (cd /DATA/git/card; git pull |grep "Already up-to-date") || (cd /DATA/git/card && ./make)
## VARS 
WORKDIR="/DATA/git/card"
DOCUMENTROOT="/DATA/www/card"

## FUNCTIONS
sync() {
    sudo rsync -aP --quiet --delete $WORKDIR/.www/ $DOCUMENTROOT
}

mk() {
    pandoc -t html5 \
           --no-highlight \
           --template $WORKDIR/site/templates/* \
           "$WORKDIR/site/$page" |
           sed ':a;N;$!ba;s|>\s*<|><|g' > "${page%%.md}.html"

    printf '%s\n' "CC $page"
}

## CLEAN
rm    -rf .www
mkdir -p  .www
cd        .www

## MAIN 
(cd $WORKDIR/site; find . -type f -a -not -path '*/\.*' |sort) | while read -r page; do
    mkdir -p "${page%/*}"
    file=${page##*/}

    case $page in
        *news/20*.md)
            # vars
            INDEX_PATH="$WORKDIR/site/news/index.md"
            XML_PATH="$WORKDIR/site/news/news.xml"
            DATE=$(grep date: $WORKDIR/site/$page |awk -F\" '{ print $2 }')
            DATE_INDEX=$(date -d "$DATE" +%m/%d/%Y)
            DATE_XML=$(date -d "$DATE" --rfc-2822)
            TITLE=$(grep title: $WORKDIR/site/$page |awk -F\" '{ print $2 }')

            # index
            NEW_LINE="<ul style=\"padding:0\">"
            sed -i "/${file%.*}/d" $INDEX_PATH
            sed -i -e "s|${NEW_LINE}|${NEW_LINE}\n<li><a href='/news/${file%.*}.html'>${DATE_INDEX}: $TITLE</a></li>|g" $INDEX_PATH  
            
            # xml
            NEW_LINE="<atom:link href=\"https://jeremi.biz/news/news.xml\" rel=\"self\" type=\"application/rss+xml\" />"
            sed -i -e "s|${NEW_LINE}|${NEW_LINE}\n\n<item>\n<title>${DATE_INDEX}: $TITLE</title>\n<description>$TITLE</description>\n<link>https://jeremi.biz/news/${file%.*}.html</link>\n<guid isPermaLink=\"true\">https://jeremi.biz/news/${file%.*}.html</guid>\n<pubDate>$DATE_XML</pubDate>\n</item>\n|g" $XML_PATH
            
            mk
        ;;

        *wiki*.md)
            [ "${file%%.md}" = index ] && { title=Wiki; wiki=; }
            [ "${file%%.md}" = index ] || { title=${file%%.md}; wiki=1; }

            sed -i'' 's|https://github.com/kisslinux/wiki/|/|g' "$WORKDIR/site/$page"

            mk --metadata title="$(echo "$title" | sed 's/-/ /g')" \
               --metadata wiki="$wiki" \
               --from markdown-markdown_in_html_blocks-raw_html
        ;;

        *.md)
            mk
        ;;

        *)
            cp "$WORKDIR/site/$page" "$page"

            printf '%s\n' "CP $page"
        ;;
    esac
done

printf 'Build complete.\n'

sync 
