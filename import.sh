#!/bin/bash

user="root"
password="P@ssw0rd"
database="grafana"

request() {
	mysql -u$user -p$password --database=$database -e "$1"
}

if [[ ! -e banned.txt ]]; then
    touch banned.txt
fi

if [[ ! -e /var/log/fail2ban-monitoring/fail2ban.log ]]; then
    mkdir /var/log/fail2ban-monitoring/
    touch /var/log/fail2ban-monitoring/fail2ban.log
fi

iptables -L -n | awk '$1=="REJECT" && $4!="0.0.0.0/0" {print $4}' > banned.txt

now=$(date +'%d_%m_%Y-%T')

cat banned.txt | while read ip
do
    endpoint=$(curl -s "http://ip-api.com/json/${ip}")
    data=$(request "SELECT * FROM data")

    case ${data} in
        *${ip}*) echo "[$now : ERROR] Adress $ip already exist in the database : Skipping" >> /var/log/fail2ban-monitoring/${now}.log;;
        *) echo "[$now : SUCCESS] Adress $ip added inside the database" >> /var/log/fail2ban-monitoring/${now}.log
            country=$(echo "${endpoint}" | jq -r ".country")
            city=$(echo "${endpoint}" | jq -r ".city")
            zip=$(echo "${endpoint}" | jq -r ".zip")
            lat=$(echo "${endpoint}" | jq -r ".lat")
            lng=$(echo "${endpoint}" | jq -r ".lon")
            isp=$(echo "${endpoint}" | jq -r ".isp")

            request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${ip}','${country}','${city}','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
            ;;
    esac
    sleep 0.5s
done

rm -rf banned.txt