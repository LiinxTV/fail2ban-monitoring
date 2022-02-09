#!/bin/bash

user=$( xmlstarlet sel -t -v '/config/user' "/etc/fail2ban-monitoring/config.xml" )
password=$( xmlstarlet sel -t -v '/config/password' "/etc/fail2ban-monitoring/config.xml" )
database=$( xmlstarlet sel -t -v '/config/database' "/etc/fail2ban-monitoring/config.xml" )

request() {
	mysql -u$user -p$password --database=$database -e "$1"
}

now=$(date +'%d_%m_%Y-%T')

endpoint=$(curl -s "http://ip-api.com/json/${1}")
data=$(request "SELECT * FROM data")

case ${data} in
    *$1*) ;;
    *)
        country=$(echo "${endpoint}" | jq -r ".country")
        city=$(echo "${endpoint}" | jq -r ".city")
        zip=$(echo "${endpoint}" | jq -r ".zip")
        lat=$(echo "${endpoint}" | jq -r ".lat")
        lng=$(echo "${endpoint}" | jq -r ".lon")
        isp=$(echo "${endpoint}" | jq -r ".isp")

        request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('$1','${country}','${city}','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
        ;;
esac
