#! /bin/sh
SERVER=$1
PORT=$2
TIMEOUT=25
/etc/zabbix/externalscripts/timeout $TIMEOUT /etc/zabbix/externalscripts/ssl-cert-check -s $SERVER -p $PORT -n | sed -e 's/  */ /g' -e 's/|days=//g' | cut -f6 -d" "