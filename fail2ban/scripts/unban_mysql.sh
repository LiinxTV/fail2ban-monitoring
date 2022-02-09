#!/bin/bash

user=$( xmlstarlet sel -t -v '/config/user' "/etc/fail2ban-monitoring/config.xml" )
password=$( xmlstarlet sel -t -v '/config/password' "/etc/fail2ban-monitoring/config.xml" )
database=$( xmlstarlet sel -t -v '/config/database' "/etc/fail2ban-monitoring/config.xml" )

request() {
	mysql -u$user -p$password --database=$database -e "$1"
}

request "DELETE FROM data WHERE ip='${1}';"
