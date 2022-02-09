#!bin/bash

sudo apt update && sudo apt upgrade -y

apt install xmlstarlet -y

if [[ ! -e /etc/fail2ban/scripts/ ]]; then
    mkdir /etc/fail2ban/scripts
    mv ban_mysql.sh /etc/fail2ban/scripts/ban_mysql.sh
    mv unban_mysql.sh /etc/fail2ban/scripts/unban_mysql.sh
fi

if [[ ! -e /etc/fail2ban-monitoring ]]; then
    mkdir /etc/fail2ban-monitoring
fi

mv config.xml /etc/fail2ban-monitoring/config.xml

mv grafana.conf /etc/fail2ban/action.d/grafana.conf