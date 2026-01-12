#!/bin/bash

LOG_FILE="/var/log/curl_domains.log"

get_domains() {
    WEBSITES=(
        "google.com"          # US
        "yahoo.com"           # US
        "facebook.com"        # US
        "twitter.com"         # US
        "amazon.com"          # US
        "ebay.com"            # US
        "reddit.com"          # US
        "stackoverflow.com"   # US
        "github.com"          # US
        "linkedin.com"        # US
        "youtube.com"         # US
        "instagram.com"       # US
        "microsoft.com"       # US
        "apple.com"           # US
        "spotify.com"         # US
        "dropbox.com"         # US
        "twitch.tv"           # US
        "zoom.us"             # US
        "discord.com"         # US
        "paypal.com"          # US
        "imgur.com"           # US
        "walmart.com"         # US
        "target.com"          # US
        "bestbuy.com"         # US
        "homedepot.com"       # US
        "lowes.com"           # US
        "costco.com"          # US
        
        "bbc.co.uk"           # Europe
        "theguardian.com"     # Europe
        "spiegel.de"          # Europe
        "lemonde.fr"          # Europe
        "elpais.com"          # Europe
        "ft.com"              # Europe
        "tagesspiegel.de"     # Europe
        "faz.net"             # Europe
        "sueddeutsche.de"     # Europe
        "derstandard.at"      # Europe
        "nrc.nl"              # Europe
        "aftonbladet.se"      # Europe
        "dagbladet.no"        # Europe
        
        "alibaba.com"         # Asia
        "baidu.com"           # Asia
        "rakuten.co.jp"       # Asia
        "flipkart.com"        # Asia
        "lazada.com"          # Asia
        "jd.com"              # Asia
        "taobao.com"          # Asia
        "coupang.com"         # Asia
        "shopee.com"          # Asia
        "1688.com"            # Asia
        "weibo.com"           # Asia"

        "globo.com"          # South America
        "uol.com.br"         # South America
        "estadao.com.br"     # South America
        "terra.com.br"       # South America
        "ig.com.br"          # South America
        "eltiempo.com"       # South America
        "elcomercio.pe"      # South America
        "lanacion.com.ar"    # South America
        "clarin.com"         # South America
        "elpais.com.uy"      # South America
        "eluniversal.com"    # South America
        "elmercurio.com"     # South America
        "elpais.com.co"      # South America
        "elcomercio.com"     # South America
        "elsalvador.com"     # South America
    )
}

check_internet() {
    if curl -s --head http://www.google.com/ | head -n 1 | grep "200 OK" > /dev/null; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Internet connection successful..." >>"$LOG_FILE"
      return 0
    else
      return 1
    fi
}


get_domains

echo "Starting background script. Press Ctrl+C to stop."

while true; do
    if check_internet; then
        echo "Internet connection detected. Starting ping tests."
        for website in "${WEBSITES[@]}"; do
            #echo "Pinging $website"
            #if ping -c 1 "$website" > /dev/null; then
            #    echo "Ping to $website succeeded"
            #else
            #    echo "Ping to $website failed"
            #fi

            echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking $website..." >>"$LOG_FILE"
            # Perform the HTTP request and capture the HTTP status code
            http_status=$(curl -s -o /dev/null -w "%{http_code}" "$website")

            # Check if the status code indicates success (2xx or 3xx codes)
            if [[ "$http_status" -ge 200 && "$http_status" -lt 400 ]]; then
              echo "$(date '+%Y-%m-%d %H:%M:%S') - $website is Up (HTTP Status: $http_status)" >>"$LOG_FILE"
            else
              echo "$(date '+%Y-%m-%d %H:%M:%S') - $website is Down (HTTP Status: $http_status)" >>"$LOG_FILE"
            fi
            
            sleep 3
        done
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No internet connection. Retrying in 1 minute..." >>"$LOG_FILE"
        sleep 60
    fi
done