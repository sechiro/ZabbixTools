#!/bin/bash
ZABBIX=localhost
HOST=${1:-"namenode01"}
PORT=${2:-"50070"}
NODE=${3:-"namenode"}
IFS='='
EXCEPT='\{'
if [ $NODE = "nojvm" ];then
  JVM_METRIC1='|gc[Count|TimeMillis]|log[Error|Fatal|Info|Warn]'
  JVM_METRIC2='|threads[Blocked|New|Runnable|Terminated|TimedWaiting|Waiting]|maxMemoryM|memHeap|memNonHeap'
  EXCEPT=${EXCEPT}${JVM_METRIC1}${JVM_METRIC2}
fi

echo '<?xml version|"1.0" encoding|"UTF-8"?>
<zabbix_export version|"1.0" date|"11.06.30" time|"22.35">
  <hosts>
    <host name|"Hadoop_'${NODE}'">
      <proxy_hostid>0</proxy_hostid>
      <useip>1</useip>
      <dns></dns>
      <ip>127.0.0.1</ip>
      <port>10050</port>
      <status>3</status>
      <useipmi>0</useipmi>
      <ipmi_ip>127.0.0.1</ipmi_ip>
      <ipmi_port>623</ipmi_port>
      <ipmi_authtype>0</ipmi_authtype>
      <ipmi_privilege>2</ipmi_privilege>
      <ipmi_username></ipmi_username>
      <ipmi_password></ipmi_password>
      <groups>
        <group>Templates</group>
      </groups>
      <triggers/>
      <items>
' | sed -e 's/|/=/g'

ZBXTMPL1='<item type|"2" key|"'
ZBXTMPL2='" value_type|"0">
          <description>'
ZBXTMPL3='</description>
          <delay>30</delay>
          <history>90</history>
          <trends>365</trends>
          <applications>
            <application>'Hadoop${NODE}'</application>
          </applications>
        </item>'

exec 5<>/dev/tcp/$HOST/$PORT
echo "GET /metrics" >&5

add_suffix()
{
_SUFFIX=''
while read line
do
  #echo $line
  set -- $line
  if [ -z $2 ]
  then
      if [[ $1 =~ ^["  "] ]]
      then
          _SUFFIX2=$1
      elif [[ $1 =~ ^[a-zA-Z] ]]
      then
          _SUFFIX1=$1
      fi
  else
      if [ ${_SUFFIX1} = "jvm" ]
      then
          echo ${ZBXTMPL1}${_SUFFIX1}.${_SUFFIX2}.$1[$NODE]${ZBXTMPL2}${_SUFFIX1}.${_SUFFIX2}.$1[$NODE]${ZBXTMPL3}
      else
          echo ${ZBXTMPL1}${_SUFFIX1}.${_SUFFIX2}.$1${ZBXTMPL2}${_SUFFIX1}.${_SUFFIX2}.$1${ZBXTMPL3}
      fi
  fi
done
return 0
}

RESULT=`/bin/cat <&5 | /bin/egrep -v $EXCEPT | add_suffix | /bin/sed -e 's/  //g'`
#/usr/bin/zabbix_sender -z $ZABBIX -i <(echo $RESULT)
echo $RESULT | sed -e 's/|/=/g'
echo '<item type="10" key="get_hadoop_metrics.sh[{$'`echo -n ${NODE}|sed -e "s/\(.*\)/\U\1\E/"`'.PORT} '${NODE}']" value_type="1">
          <description>Hadoopメトリクス取得結果</description>
          <ipmi_sensor></ipmi_sensor>
          <delay>30</delay>
          <history>90</history>
          <trends>365</trends>
          <status>0</status>
          <data_type>0</data_type>
          <applications>
            <application>'Hadoop${NODE}'</application>
          </applications>
        </item>'

echo '</items>
      <templates/>
      <graphs/>
      <macros>
        <macro>
          <value>'${PORT}'</value>
          <name>{$'`echo -n ${NODE}|sed -e "s/\(.*\)/\U\1\E/"`'.PORT}</name>
        </macro>
      </macros>
    </host>
  </hosts>
  <dependencies/>
</zabbix_export>
'