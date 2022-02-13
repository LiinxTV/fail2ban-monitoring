#!/bin/bash

request() {
    username=$(grep -oP '(?<=<username>).*?(?=</username>)' "/etc/fail2ban-monitoring/config.xml")
    password=$(grep -oP '(?<=<password>).*?(?=</password>)' "/etc/fail2ban-monitoring/config.xml")
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml")
	MYSQL_PWD=${password} mysql -u${username} --database=${database} -e "$1"
}

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

help() {
    echo "${RESET}Usage: f2bm [options] <value>"
    echo "${RESET}"
    echo "${RESET}"
    echo "${RESET}List of commands:"
    echo "${RESET}    ${YELLOW}install                                  ${RED}-${RESET} Install components."
    echo "${RESET}    ${YELLOW}uninstall                                ${RED}-${RESET} Uninstall components."
    echo "${RESET}    ${YELLOW}reset                                    ${RED}-${RESET} Unban all and reset iptables rules."
    echo "${RESET}    ${YELLOW}configure mysql <user|password|database> ${RED}-${RESET} Change database connection settings."
    echo "${RESET}    ${YELLOW}import                                   ${RED}-${RESET} Import local fail2ban banned ip's to database."
    echo "${RESET}    ${YELLOW}file <file>                              ${RED}-${RESET} Ban with file."
    echo "${RESET}    ${YELLOW}ban <ip>                                 ${RED}-${RESET} Ban user ip adress."
    echo "${RESET}    ${YELLOW}unban <ip>                               ${RED}-${RESET} Unban user ip adress."
    echo "${RESET}    ${YELLOW}debug                                    ${RED}-${RESET} Show any bad configuration probem."
    echo "${RESET}"
}

log() {
    echo "${RESET}[${1}${RESET}] ${2}" ${RESET}
}

directory_exist() { if [ -d "$1" ]; then return 0 ; else return 1; fi }

file_exist() { if [ -e "$1" ]; then return 0; else return 1; fi }

present_in_fail2ban() {
    data=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

present_in_db() {
    data=$(request "SELECT ip FROM data;")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

mysql_setup() {
    read -p "[SETUP] MySQL User: " user
    password=$(/lib/cryptsetup/askpass "[MySQL] Password for ${user}: ")
    tries=0
    until MYSQL_PWD=${password} mysql -u${user} -e ";" > /dev/null; do
        password=$(/lib/cryptsetup/askpass "Can't connect, please retry: ")
        tries=$(expr $tries + 1)
        if [ "$tries" -eq "3" ]; then
            log "${RED}ERROR" "Too many authentification failures !"
            tries=$(expr $tries - $tries)
            mysql_setup
        fi
    done
    log "${LIGHTGREEN}OK" "Connection successfully established !"
    read -p "[SETUP] MySQL Database: " database
    echo "<configuration>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <username>${user}</username>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <password>${password}</password>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <database>${database}</database>" >> /etc/fail2ban-monitoring/config.xml
    echo "</configuration>" >> /etc/fail2ban-monitoring/config.xml
}

install() {
    if file_exist "/etc/fail2ban-monitoring/config.xml"; then
        log "${RED}ERROR" "Failed to continue installation, config file is already present !"
        exit
    fi
    if [ $(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "MySQL not found, please install it !"
        exit
    fi
    if [ $(dpkg-query -W -f='${Status}' xmlstarlet 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "xmlstarlet not installed, Installing... !"
        sudo apt -qq update && sudo apt upgrade -y >/dev/null 2>&1
        sudo apt -qq install xmlstarlet -y >/dev/null 2>&1
    else
        log "${LIGHTGREEN}OK" "xmlstarlet package is already installed"
    fi
    if [ $(dpkg-query -W -f='${Status}' sqlite3 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "sqlite3 not installed, Installing... !"
        sudo apt -qq update && sudo apt upgrade -y >/dev/null 2>&1
        sudo apt -qq install sqlite3 -y >/dev/null 2>&1
    else
        log "${LIGHTGREEN}OK" "sqlite3 package is already installed"
    fi
    if ! directory_exist "/etc/fail2ban-monitoring"; then
        mkdir /etc/fail2ban-monitoring
        log "${YELLOW}INSTALL" "Created folder: ${LIGHTPURPLE}/etc/fail2ban-monitoring"
    fi
    if ! file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        touch /etc/fail2ban/action.d/grafana.conf
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf"
    fi
    if ! file_exist "/etc/fail2ban-monitoring/config.xml"; then
        touch /etc/fail2ban-monitoring/config.xml
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban-monitoring/config.xml"
        mysql_setup
    fi
    echo "[Definition]" >> /etc/fail2ban/action.d/grafana.conf
    echo "actionban = bash /usr/bin/fail2ban-monitoring.sh ban <ip>" >> /etc/fail2ban/action.d/grafana.conf
    echo "actionunban = bash /usr/bin/fail2ban-monitoring.sh unban <ip>" >> /etc/fail2ban/action.d/grafana.conf
    echo "[Init]" >> /etc/fail2ban/action.d/grafana.conf
    echo "name = default" >> /etc/fail2ban/action.d/grafana.conf
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml")
    request "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"
    request "CREATE DATABASE IF NOT EXISTS ${database};"
    request "DROP TABLE IF EXISTS data;"
    request "USE ${database}; CREATE TABLE IF NOT EXISTS data (ip varchar(15) NOT NULL,country varchar(48) NOT NULL,city varchar(48) NOT NULL,zip varchar(12) NOT NULL,lat decimal(10,8) NOT NULL,lng decimal(11,8) NOT NULL,isp varchar(92) NOT NULL,time date NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;"
    log "${LIGHTGREEN}OK" "Configuration file successfully created !"
}

uninstall() {
        if file_exist "/etc/fail2ban-monitoring/config.xml"; then
        read -p "Do you want to delete database data? [Y/n]" choice
        if [ "$choice" = "y" ] || [ "$choice" = "" ]; then
            request "DELETE FROM data;"
            log "${LIGHTGREEN}OK" "MySQL data entries has been cleared."
        else
            log "${YELLOW}UNINSTALL" "Skipping deleting entries from database."
        fi
    fi
    if  directory_exist "/etc/fail2ban-monitoring"; then
        rm -rf /etc/fail2ban-monitoring
        log "${YELLOW}UNINSTALL" "Deleted folder: ${LIGHTPURPLE}/etc/fail2ban-monitoring/*"
    fi
    if file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        rm -rf /etc/fail2ban/action.d/grafana.conf
        log "${YELLOW}UNINSTALL" "Deleted file: ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf"
    fi
    log "${LIGHTGREEN}OK" "F2BM components has been removed."
}

reset() {
    read -p "Do you want to continue? [Y/n]" choice
    if [ "$choice" = "y" ] || [ "$choice" = "" ]; then
        fail2ban-client unban --all > /dev/null
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -t nat -F
        iptables -t mangle -F
        iptables -F
        iptables -X
        if file_exist "/etc/fail2ban-monitoring/config.xml"; then
            request "DELETE FROM data;"
        fi
        log "${LIGHTGREEN}OK" "Everything has been reset."
    else
        log "${YELLOW}RESET" "Reset aborted."
    fi
}

import() {
    if ! file_exist "/etc/fail2ban-monitoring/config.xml"; then
        log "${RED}ERROR" "Failed to import data, use ${LIGHTPURPLE}f2bm install${RESET} first."
        exit
    fi
    if ! file_exist "banned.txt"; then
        touch banned.txt
    fi
    sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips" > banned.txt
    cat banned.txt | while read ip
    do
        if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
            endpoint=$(curl -s "http://ip-api.com/json/${ip}")
            data=$(request "SELECT ip FROM data;")

            if ! present_in_db "${ip}"; then
                country=$(echo "${endpoint}" | jq -r ".country")
                city=$(echo "${endpoint}" | jq -r ".city")
                zip=$(echo "${endpoint}" | jq -r ".zip")
                lat=$(echo "${endpoint}" | jq -r ".lat")
                lng=$(echo "${endpoint}" | jq -r ".lon")
                isp=$(echo "${endpoint}" | jq -r ".isp")
                request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${ip}','${country}','${city}','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
            fi

            log "${LIGHTGREEN}OK" "The address${RED} ${ip} ${RESET}has been banned !"
            sleep 0.5s
        fi
    done
    rm -rf banned.txt
}

debug() {
    error=0
    if ! directory_exist "/etc/fail2ban-monitoring"; then
        log "${RED}DEBUG" "The folder ${LIGHTPURPLE}/etc/fail2ban-monitoring${RESET} is missing !"
        error=1
    fi
    if ! file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        log "${RED}DEBUG" "The file ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf${RESET} is missing !"
        error=1
    fi
    if [ $error -eq 0 ]; then
        log "${LIGHTGREEN}DEBUG" "The installation seems to be good. Everything should be working ! Congratulations !"
        exit
    fi
}

ban() {
    if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        f2b_db=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
        endpoint=$(curl -s "http://ip-api.com/json/${1}")

        if present_in_db "$1" && present_in_fail2ban "$1"; then
            log "${RED}ERROR" "This address is already banned !"
            exit
        fi

        if ! present_in_db "$1"; then
            country=$(echo "${endpoint}" | jq -r ".country")
            city=$(echo "${endpoint}" | jq -r ".city")
            zip=$(echo "${endpoint}" | jq -r ".zip")
            lat=$(echo "${endpoint}" | jq -r ".lat")
            lng=$(echo "${endpoint}" | jq -r ".lon")
            isp=$(echo "${endpoint}" | jq -r ".isp")
            request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${1}','${country}','${city}','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
        fi

        if ! present_in_fail2ban "$1"; then
            fail2ban-client set sshd banip ${1} > /dev/null
        fi

        log "${LIGHTGREEN}OK" "The address${RED} ${1} ${RESET}has been banned !"
    else
        log "${RED}ERROR" "The address${RED} ${1} ${RESET}is not a valid ip address !"
        exit
    fi
}

unban() {
    if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        f2b_db=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
        data=$(request "SELECT ip FROM data;")

        if ! present_in_db "$1" && ! present_in_fail2ban "$1"; then
            log "${RED}ERROR" "This address is already banned !"
            exit
        fi

        if present_in_db "$1"; then
            request "DELETE FROM data WHERE ip='${1}';"
        fi

        if present_in_fail2ban "$1"; then
            fail2ban-client set sshd unbanip ${1} > /dev/null
        fi

        log "${LIGHTGREEN}OK" "The address${RED} ${1} ${RESET}has been unbanned !"
    else
        log "${RED}ERROR" "The address${RED} ${1} ${RESET}is not a valid ip address !"
        exit
    fi
}

ban_file() {
    if ! file_exist "$1"; then
        log "${RED}ERROR" "Failed to import ${LIGHTPURPLE}$1${RESET} file."
        exit
    fi
    cat "$1" | while read ip
    do
        if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
            endpoint=$(curl -s "http://ip-api.com/json/${ip}")
            data=$(request "SELECT ip FROM data;")

            if ! present_in_db "${ip}"; then
                country=$(echo "${endpoint}" | jq -r ".country")
                city=$(echo "${endpoint}" | jq -r ".city")
                zip=$(echo "${endpoint}" | jq -r ".zip")
                lat=$(echo "${endpoint}" | jq -r ".lat")
                lng=$(echo "${endpoint}" | jq -r ".lon")
                isp=$(echo "${endpoint}" | jq -r ".isp")
                request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${ip}','${country}','${city}','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
                log "${LIGHTGREEN}OK" "The address${RED} ${ip} ${RESET}has been banned !"
                sleep 1.5s    
            fi
        fi
    done
}

update_db_user() {
    read -p "Enter new user:" user
    xmlstarlet ed --inplace -u '/configuration/username' -v "${user}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL user will be:${LIGHTPURPLE} $user ${RESET}"
}

update_db_password() {
    read -p "Enter new password:" password
    xmlstarlet ed --inplace -u '/configuration/password' -v "${password}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL password will be:${LIGHTPURPLE} $password ${RESET}"
}

update_db_database() {
    read -p "Enter new database:" database
    xmlstarlet ed --inplace -u '/configuration/database' -v "${database}" /etc/fail2ban-monitoring/config.xml
    log "${LIGHTGREEN}OK" "The new MySQL user will be:${LIGHTPURPLE} $database ${RESET}"
}

if [ $# -eq 0 ] ; then
    log "${RED}ERROR" "Invalid syntax, please use: ${LIGHTPURPLE}f2bm --help${RESET}"
    exit
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    help
    exit
fi

if [ $# -eq 1 ] && [ "$1" = "install" ]; then
    install
    exit
fi

if [ $# -eq 1 ] && [ "$1" = "uninstall" ]; then
    uninstall
    exit
fi

if [ $# -eq 1 ] && [ "$1" = "reset" ]; then
    reset
    exit
fi

if [ $# -eq 1 ] && [ "$1" = "import" ]; then
    import
    exit
fi

if [ $# -eq 1 ] && [ "$1" = "debug" ]; then
    debug
    exit
fi

if [ $# -eq 2 ] && [ "$1" = "ban" ]; then
    ban "$2"
    exit
fi

if [ $# -eq 2 ] && [ "$1" = "unban" ]; then
    unban "$2"
    exit
fi

if [ $# -eq 2 ] && [ "$1" = "db_ban" ]; then
    db_ban "$2"
    exit
fi

if [ $# -eq 2 ] && [ "$1" = "db_unban" ]; then
    db_unban "$2"
    exit
fi

if [ $# -eq 2 ] && [ "$1" = "file" ]; then
    ban_file "$2"
    exit
fi

if [ $# -eq 3 ] && [ "$1" = "ban" ] && [ "$3" = "--db" ]; then
    ban "$2" "$3"
    exit
fi

if [ $# -eq 3 ] && [ "$1" = "unban" ] && [ "$3" = "--db" ]; then
    unban "$2" "$3"
    exit
fi

if [ $# -eq 3 ] && [ "$1" = "configure" ] && [ "$2" = "mysql" ] && ([ "$3" = "user" ] || [ "$3" = "password" ] ||[ "$3" = "database" ]); then
    if [ "$3" = "user" ]; then
        update_db_user
        exit
    fi
    if ([ "$3" = "password" ] || [ "$3" = "pass" ]); then
        update_db_password
        exit
    fi
    if ([ "$3" = "database" ] || [ "$3" = "db" ]); then
        update_db_database
        exit
    fi
    exit
fi
help
