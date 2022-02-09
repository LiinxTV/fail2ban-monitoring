#!bin/bash

user="user"
password="pass"

request() {
	mysql -u$user -p$password -e "$1"
}

request "CREATE DATABASE grafana;"
request "DROP TABLE IF EXISTS data;"
request "USE grafana; CREATE TABLE data (ip varchar(15) NOT NULL,country varchar(48) NOT NULL,city varchar(48) NOT NULL,zip varchar(12) NOT NULL,lat decimal(10,8) NOT NULL,lng decimal(11,8) NOT NULL,isp varchar(48) NOT NULL,time date NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;"

if [ $(dpkg-query -W -f='${Status}' xmlstarlet 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  sudo apt update && sudo apt upgrade -y
  sudo apt install xmlstarlet -y
fi

if [ ! -d /etc/fail2ban/scripts ]; then
    mkdir /etc/fail2ban/scripts
fi

if [ ! -d /etc/fail2ban-monitoring ]; then
    mkdir /etc/fail2ban-monitoring
fi

cp ban_mysql.sh /etc/fail2ban/scripts/ban_mysql.sh
cp unban_mysql.sh /etc/fail2ban/scripts/unban_mysql.sh
cp config.xml /etc/fail2ban-monitoring/config.xm
cp grafana.conf /etc/fail2ban/action.d/grafana.conf
