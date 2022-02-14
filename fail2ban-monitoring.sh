#!/bin/bash

#███████╗ █████╗ ██╗██╗     ██████╗ ██████╗  █████╗ ███╗   ██╗    ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗ ██╗███╗   ██╗ ██████╗ 
#██╔════╝██╔══██╗██║██║     ╚════██╗██╔══██╗██╔══██╗████╗  ██║    ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗██║████╗  ██║██╔════╝ 
#█████╗  ███████║██║██║      █████╔╝██████╔╝███████║██╔██╗ ██║    ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝██║██╔██╗ ██║██║  ███╗
#██╔══╝  ██╔══██║██║██║     ██╔═══╝ ██╔══██╗██╔══██║██║╚██╗██║    ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗██║██║╚██╗██║██║   ██║
#██║     ██║  ██║██║███████╗███████╗██████╔╝██║  ██║██║ ╚████║    ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║██║██║ ╚████║╚██████╔╝
#╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝    ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 

#SQL Query method
request() {
    username=$(grep -oP '(?<=<username>).*?(?=</username>)' "/etc/fail2ban-monitoring/config.xml") #Get username from "/etc/fail2ban-monitoring/config.xml"
    password=$(grep -oP '(?<=<password>).*?(?=</password>)' "/etc/fail2ban-monitoring/config.xml") #Get password from "/etc/fail2ban-monitoring/config.xml"
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml") #Get database from "/etc/fail2ban-monitoring/config.xml"
	MYSQL_PWD=${password} mysql -u${username} --database=${database} -e "$1"
}

#Some colors for terminal text style
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

#This is the help message, equivalent to a man page
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

#Function for printing formated message (Need 2 args)
log() {
    echo "${RESET}[${1}${RESET}] ${2}" ${RESET}
}

directory_exist() { if [ -d "$1" ]; then return 0 ; else return 1; fi } #Checking if a directory exist.

file_exist() { if [ -e "$1" ]; then return 0; else return 1; fi } #Checking if a file exist.

present_in_fail2ban() {
    #Check if IP parsed as parameter is stored in local fail2ban database.
    data=$(sqlite3 /var/lib/fail2ban/fail2ban.sqlite3 "select distinct ip from bips")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

present_in_db() {
    #Check if IP parsed as parameter is stored in mysql database.
    data=$(request "SELECT ip FROM data;")
    if echo "$data" | grep -q "${1}"; then return 0; else return 1; fi
}

mysql_setup() {
    #Define MySQL credentials and store them in a config file (/etc/fail2ban-monitoring/config.xml)
    read -p "[SETUP] MySQL User: " user
    password=$(/lib/cryptsetup/askpass "[MySQL] Password for ${user}: ")
    tries=0
    until MYSQL_PWD=${password} mysql -u${user} -e ";" > /dev/null; do
        password=$(/lib/cryptsetup/askpass "Can't connect, please retry: ")
        tries=$(expr $tries + 1)
        if [ "$tries" -eq "3" ]; then #Let 3 login tries.
            log "${RED}ERROR" "Too many authentification failures !"
            tries=$(expr $tries - $tries)
            mysql_setup #Recursive function
        fi
    done
    #Write informations to file (/etc/fail2ban-monitoring/config.xml)
    log "${LIGHTGREEN}OK" "Connection successfully established !"
    read -p "[SETUP] MySQL Database: " database
    echo "<configuration>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <username>${user}</username>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <password>${password}</password>" >> /etc/fail2ban-monitoring/config.xml
    echo "    <database>${database}</database>" >> /etc/fail2ban-monitoring/config.xml
    echo "</configuration>" >> /etc/fail2ban-monitoring/config.xml
}

install() {
    #Check if a config file is already present, if present, that means that an installation process was already completed
    if file_exist "/etc/fail2ban-monitoring/config.xml"; then
        log "${RED}ERROR" "Failed to continue installation, config file is already present !"
        exit
    fi
    #Update packages and upgrade them before performing the installation.
    sudo apt -qq update && sudo apt upgrade -y >/dev/null 2>&1
    #Cancel installation if mysql if not found [depends]
    if [ $(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "MySQL not found, please install it !"
        exit
    fi
    #Install xmlstarlet package if not found [soft depend]
    if [ $(dpkg-query -W -f='${Status}' xmlstarlet 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "xmlstarlet not installed, Installing... !"
        sudo apt -qq install xmlstarlet -y >/dev/null 2>&1
    else
        log "${LIGHTGREEN}OK" "xmlstarlet package is already installed"
    fi
    #Install sqlite3 package if not found [soft depend]
    if [ $(dpkg-query -W -f='${Status}' sqlite3 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "sqlite3 not installed, Installing... !"
        sudo apt -qq install sqlite3 -y >/dev/null 2>&1
    else
        log "${LIGHTGREEN}OK" "sqlite3 package is already installed"
    fi
    #Install jq package if not found [soft depend]
    if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        log "${RED}ERROR" "jq not installed, Installing... !"
        sudo apt -qq install jq -y >/dev/null 2>&1
    else
        log "${LIGHTGREEN}OK" "sqlite3 package is already installed"
    fi
    #Create folder /etc/fail2ban-monitoring if not exist
    if ! directory_exist "/etc/fail2ban-monitoring"; then
        mkdir /etc/fail2ban-monitoring
        log "${YELLOW}INSTALL" "Created folder: ${LIGHTPURPLE}/etc/fail2ban-monitoring"
    fi
    #Create file /etc/fail2ban/action.d/grafana.conf if not exist
    if ! file_exist "/etc/fail2ban/action.d/grafana.conf"; then
        touch /etc/fail2ban/action.d/grafana.conf
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban/action.d/grafana.conf"
    fi
    #Create file /etc/fail2ban-monitoring/config.xml if not exist
    if ! file_exist "/etc/fail2ban-monitoring/config.xml"; then
        touch /etc/fail2ban-monitoring/config.xml
        log "${YELLOW}INSTALL" "Created file: ${LIGHTPURPLE}/etc/fail2ban-monitoring/config.xml"
        mysql_setup
    fi
    #Writing file that bind ban and unban events to f2bm script
    echo "[Definition]" >> /etc/fail2ban/action.d/grafana.conf
    echo "actionban = sh /usr/bin/fail2ban-monitoring.sh ban <ip>" >> /etc/fail2ban/action.d/grafana.conf
    echo "actionunban = sh /usr/bin/fail2ban-monitoring.sh unban <ip>" >> /etc/fail2ban/action.d/grafana.conf
    echo "[Init]" >> /etc/fail2ban/action.d/grafana.conf
    echo "name = default" >> /etc/fail2ban/action.d/grafana.conf
    #Setup database schema
    database=$(grep -oP '(?<=<database>).*?(?=</database>)' "/etc/fail2ban-monitoring/config.xml")
    request "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"
    request "CREATE DATABASE IF NOT EXISTS ${database};"
    request "DROP TABLE IF EXISTS data;"
    request "USE ${database}; CREATE TABLE IF NOT EXISTS data ( ip varchar(15) NOT NULL, country varchar(92) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, city varchar(92) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, zip text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, lat text NOT NULL, lng text NOT NULL, isp varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL, time date NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;"
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
        time=$(fail2ban-client get sshd bantime)
        fail2ban-client set sshd bantime 1 > /dev/null
        sleep 5s
        fail2ban-client set sshd bantime "${time}" > /dev/null
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
            ban "$ip"

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
        else
            if ! present_in_db "$1"; then
                invalid="'"
                replace=" "
                country=$(echo "${endpoint}" | jq -r ".country")
                city=$(echo "${endpoint}" | jq -r ".city")
                zip=$(echo "${endpoint}" | jq -r ".zip")
                lat=$(echo "${endpoint}" | jq -r ".lat")
                lng=$(echo "${endpoint}" | jq -r ".lon")
                isp=$(echo "${endpoint}" | jq -r ".isp")
                request "INSERT INTO data(ip,country,city,zip,lat,lng,isp,time) VALUES ('${1}','$(echo "${country}" | sed s/\'//g)','$(echo "${city}" | sed s/\'//g)','${zip}',${lat},${lng},'${isp}', '$(date +'%Y-%m-%d')')"
            fi

            if ! present_in_fail2ban "$1"; then
                fail2ban-client set sshd banip ${1} > /dev/null
            fi

            log "${LIGHTGREEN}OK" "The address${RED} ${1} ${RESET}has been banned !"
        fi
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

    ips=0
    cat "$1" | while read ip
    do
        if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
            if ! present_in_db "${ip}" && ! present_in_fail2ban "${ip}"; then
                ban "$ip"
                ips=$(expr $ips + 1)
                sleep 1.5s
            else
                log "${RED}ERROR" "This address is already banned !"
            fi
        fi
    done
    log "${LIGHTGREEN}DONE" "A total of${RED} ${ips} ${RESET}ip's has been banned !"
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
