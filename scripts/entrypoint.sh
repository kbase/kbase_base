#!/bin/bash

CONFIG=/kb/deployment/deployment.cfg

if [ $# -gt 0 ] ; then
  export MYSERVICES=$1
  shift
fi

if [ "$MYSERVICES" = "www" ] ; then
  echo "www"
  mkdir /etc/nginx/ssl
  cp ./ssl/proxy.crt /etc/nginx/ssl/server.crt
  cp ./ssl/proxy.key /etc/nginx/ssl/server.key.insecure
  /etc/init.d/nginx start
  sleep 10000000000
elif [ "$MYSERVICES" = "narrative" ] ; then
  echo "narrative"
  SKIPNAR=1 ./scripts/config_narrative 
  # Use production auth since redeployed auth is broken
  grep -rl authorization /kb/deployment/ui-common|xargs sed -i 's/\/\/[^/]*\/services\/authorization/\/\/kbase.us\/services\/authorization/'
  # Dial back number of narratives
  sed -i 's/M.provision_count = 20/M.provision_count = 2/' /kb/deployment/services/narrative/docker/proxy_mgr.lua 
  sed -i 's/VolumesFrom = "",/VolumesFrom = json.util.null,/' /kb/deployment/services/narrative/docker/docker.lua
  # Certs
  mkdir /etc/nginx/ssl
  cp ./ssl/narrative.crt /etc/nginx/ssl/server.chained.crt
  cp ./ssl/narrative.key /etc/nginx/ssl/server.key
  GID=$(ls -n /var/run/docker.sock |awk '{print $4}')
  cat /etc/group|awk -F: '{if ($3=='$GID'){print "groupdel "$1}}'|sh
  groupmod -g $GID docker || groupadd -g $GID docker
  sed -i 's/user www-data;/user www-data docker;\ndaemon off;\nerror_log \/dev\/stdout info;/' /etc/nginx/nginx.conf
  /usr/sbin/nginx
elif [ "$MYSERVICES" = "aweworker" ] ; then
  CGROUP=$1
  [ -z $CGROUP ] && CGROUP=dev 
  ADMIN_USER=$(grep awe-admin-user $CONFIG|sed 's/awe-admin-user=//')
  ADMIN_PASS=$(grep awe-admin-password $CONFIG|sed 's/awe-admin-password=//')
  URL=$(grep serverurl $CONFIG|sed 's/serverurl=//'|sed 's/\/$//')
  echo $ADMIN_PASS|kbase-login $ADMIN_USER
  unset ADMIN_PASS
  AUTH="Authorization: OAuth $(grep token ~/.kbase_config|sed 's/token=//')";
  curl -s -X POST -H "$AUTH" ${URL}/cgroup/$CGROUP > /dev/null
  TOK=$(curl -s -H "$AUTH" ${URL}/cgroup/|python -mjson.tool|sed 's/ /\n/'|grep $CGROUP|grep token|sed 's/.*name=/name=/'|sed 's/"//')
  sed -i "s/replacetoken/$TOK/" $CONFIG
  ./scripts/postprocess_aweworker
  sed -i 's/\/kb\/runtime\/sbin\/daemonize.*PID_FILE//' /kb/deployment/services/awe_service/start_*
  . /kb/deployment/user-env.sh 
  cd /kb/deployment/services/awe_service
  ./start_service
elif [ "$MYSERVICES" = "narrative_job_service" ] ; then
  USER=$(grep service_auth_name $CONFIG|sed 's/service_auth_name=//')
  PASS=$(grep service_auth_pass $CONFIG|sed 's/service_auth_pass=//')
  echo $PASS|kbase-login $USER
  TOK=$(grep token ~/.kbase_config|sed 's/token=//')
  sed -i "s#njstoken#$TOK#" $CONFIG
  sed -i "s#njstoken#$TOK#" /kb/deployment/deployment.cfg
  cd /kb/deployment/services/narrative_job_service
  ./start_service
elif [ "$MYSERVICES" = "shell" ] ; then
  exec bash --login
elif [ "$MYSERVICES" = "initialize" ] ; then
  echo "Initialize MysSQL"
  ./scripts/config_mysql

  echo "Initialize Mongo"
  ./scripts/config_mongo

  echo "Initialize shock"
  yes|/kb/deployment/services/shock_service/start_service &
  sleep 2
  kill $(ps aux|grep shock-server|grep -v grep|awk '{print $2}')

  echo "Initialize Workspace"
  ./scripts/config_Workspace

  echo "Initialize wstypes"
  ./scripts/config_wstypes
elif [ "$MYSERVICES" = "config" ] ; then
  cat /kb/deployment/deployment.cfg  
else
  [ -e /mnt/Shock/data ] || mkdir /mnt/Shock/data
  [ -e /mnt/Shock/site ] || mkdir /mnt/Shock/site
  [ -e /mnt/Shock/logs ] || mkdir /mnt/Shock/logs
  [ -e /mnt/transform_working ] || mkdir /mnt/transform_working
  # TODO: Make it work for multiple services
  BASEDIR=$(./scripts/get_config $CONFIG $MYSERVICES basedir)
  cd /kb/deployment/services/$BASEDIR
  ./start_service
  L=$(ls /kb/deployment//services/*/*/*/*/server.log)
  [ ! -z $L ] && tail -n 1000 -f $L
fi

