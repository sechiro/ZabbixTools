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
          echo $HOST ${_SUFFIX1}.${_SUFFIX2}.$1[$NODE] $2
      else
          echo $HOST ${_SUFFIX1}.${_SUFFIX2}.$1 $2
      fi
  fi
done
return 0
}

RESULT=`/bin/cat <&5 | /bin/egrep -v $EXCEPT | add_suffix | /bin/sed -e 's/  //g'`
/usr/bin/zabbix_sender -z $ZABBIX -i <(echo $RESULT)