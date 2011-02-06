#!/bin/sh
#
# Resource script for rsync daemon
#
# Description:  Manages rsync daemon as an OCF resource in
#               an High Availability setup.
#
# Author: Dhairesh Oza <odhairesh@novell.com>
# License: GNU General Public License (GPL)
#
#
#       usage: $0 {start|stop|status|monitor|validate-all|meta-data}
#
#       The "start" arg starts rsyncd.
#
#       The "stop" arg stops it.
#
# OCF parameters:
# OCF_RESKEY_binpath
# OCF_RESKEY_conffile
#
# Note:This RA requires that the rsyncd config files has a "pid file"
# entry so that it is able to act on the correct process
##########################################################################
# Initialization:

: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/resource.d/heartbeat}
. ${OCF_FUNCTIONS_DIR}/.ocf-shellfuncs

USAGE="Usage: $0 {start|stop|status|meta-data}";

##########################################################################

usage()
{
        echo $USAGE >&2
}

meta_data()
{
cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="zabbix-server">
<version>1.0</version>
<longdesc lang="en">
This script manages zabbix-server daemon
</longdesc>
<shortdesc lang="en">Manages an zabbix-server daemon</shortdesc>

<parameters>

<parameter name="binpath">
<longdesc lang="en">
The zabbix-server binary path.
For example, "/usr/sbin/zabbix_server_mysql"
</longdesc>
<shortdesc lang="en">Full path to the zabbix-server binary</shortdesc>
<content type="string" default="/usr/sbin/zabbix_server"/>
</parameter>

<parameter name="conffile">
<longdesc lang="en">
The zabbix-server daemon configuration file name with full path.
For example, "/etc/zabbix/zabbix_server.conf"
</longdesc>
<shortdesc lang="en">Configuration file name with full path</shortdesc>
<content type="string" default="/etc/zabbix/zabbix_server.conf" />
</parameter>

<actions>
<action name="start" timeout="20s"/>
<action name="stop" timeout="20s"/>
<action name="meta-data"  timeout="5s"/>
</actions>
</resource-agent>
END
exit $OCF_SUCCESS
}


### BEGIN INIT INFO
# Provides: zabbix
# Required-Start: $local_fs $network
# Required-Stop: $local_fs $network
# Default-Start:
# Default-Stop: 0 1 2 3 4 5 6
# Short-Description: start and stop zabbix server
# Description: Zabbix Server
### END INIT INFO

# zabbix details
if [ -x /usr/sbin/zabbix_server ]; then
    ZABBIX=zabbix_server
elif [ -x /usr/sbin/zabbix_server_mysql ]; then
    ZABBIX=zabbix_server_mysql
elif [ -x /usr/sbin/zabbix_server_pgsql ]; then
    ZABBIX=zabbix_server_pgsql
elif [ -x /usr/sbin/zabbix_server_sqlite3 ]; then
    ZABBIX=zabbix_server_sqlite3
else
    exit 5
fi

CONF=/etc/zabbix/zabbix_server.conf
PIDFILE=/var/run/zabbix/zabbix_server.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ ${NETWORKING} = "no" ] && exit 0

[ -e $CONF ] || exit 6

RETVAL=0

case "$1" in
    start)
        echo -n "Starting zabbix server: "
        daemon $ZABBIX -c $CONF
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch /var/lock/subsys/zabbix
        ;;
    stop)
        echo -n "Shutting down zabbix server: "
        killproc $ZABBIX
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/zabbix
        ;;
    restart|reload)
        $0 stop
        $0 start
        RETVAL=$?
        ;;
    condrestart)
        if [ -f /var/lock/subsys/zabbix ]; then
            $0 stop
            $0 start
        fi
        RETVAL=$?
        ;;
    status)
        status $ZABBIX
        RETVAL=$?
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|condrestart|reload|status}"
        exit 1
        ;;
esac

exit $RETVAL