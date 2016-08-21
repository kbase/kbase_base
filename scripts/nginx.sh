#!/bin/bash

CONFIG=/kb/deployment/deployment.cfg

# Copy deployment.cfg
[ -e /config/deployment.cfg ] && cp /config/deployment.cfg /kb/deployment/deployment.cfg

# Add the ssl certs into the certificate tree
if [ -e /config/ssl ] ;then
    PC=/config/ssl/proxy.crt
    cat $PC  >> /etc/ssl/certs/ca-certificates.crt
    cat $PC > /etc/ssl/certs/`openssl x509 -noout -hash -in $PC`.0
    cat $PC  >> /usr/local/lib/python2.7/dist-packages/requests/cacert.pem
    cat $PC  >> /etc/ssl/certs/ca-certificates.crt
    cat $PC > /etc/ssl/certs/`openssl x509 -noout -hash -in $PC`.0
fi

# Get the hostname and trim any port
PUBLIC=$(grep baseurl= /kb/deployment/deployment.cfg|sed 's/baseurl=//'|sed 's/:.*//')

# Get ports
PUBLIC_SSL_PORT=$(grep base.ssl.port=  /kb/deployment/deployment.cfg|sed 's/base.ssl.port=//')
PUBLIC_PORT=$(grep base.port=  /kb/deployment/deployment.cfg|sed 's/base.port=//')

# Set URL base names for SSL and non-SSL
if [ -z $PUBLIC_SSL ] || [ "$PUBLIC_SSL"= "443" ] ; then
  PUBLICSSL="$PUBLIC"
else
  PUBLICSSL="${PUBLIC}:${PUBLIC_SSL}"
fi

if [ -z $PUBLIC_PORT ] || [ "$PUBLIC_PORT"= "80" ] ; then
  PUBLICNONSSL="${PUBLIC}"
else
  PUBLICNONSSL="${PUBLIC}:${PUBLIC_PORT}"
fi


#NARRATIVE_URL=$(./scripts/get_config /kb/deployment/deployment.cfg narrative service-url|sed 's|http.*://||'|sed 's|/||')

NARRATIVE_URL=$(grep -A20 '\[narrative\]' /kb/deployment/deployment.cfg|grep service-url|head -1|sed 's/.*=//'|sed 's|http.*://||'|sed 's|/||')

if [ -e /kb/deployment/services/kbase-ui ] ; then
  sed -i "s|public.hostname.org:8443|$PUBLICSSL|" /kb/deployment/services/kbase-ui/modules/config/service.yml
  sed -i "s|narrative.kbase.us|$NARRATIVE_URL|" /kb/deployment/services/kbase-ui/modules/config/service.yml
  sed -i "s|narrative.kbase.us|$NARRATIVE_URL|" /kb/deployment/services/kbase-ui/search/config.json
fi

grep -lr public.hostname.org /kb/deployment/*bin/ /kb/deployment/lib/ /kb/deployment/services/ | \
   xargs sed -i "s|public.hostname.org:8443|$PUBLICSSL|g"


if [ $# -gt 0 ] ; then
  export MYSERVICES="$1"
  shift
fi

if [ "$MYSERVICES" = "narrative" ] ; then
  echo "narrative"
  if [ -e /config/nginx.conf ] ; then
    cp /config/nginx.conf /etc/nginx/nginx.conf
  fi
  # Use production auth since redeployed auth is broken
  if [ ! -z $PRODAUTH ] ; then
    grep -rl authorization /kb/deployment/ui-common|xargs sed -i 's/\/\/[^/]*\/services\/authorization/\/\/kbase.us\/services\/authorization/'
  fi

  # Dial back number of narratives
  sed -i 's/M.provision_count = 20/M.provision_count = 2/' /kb/deployment/services/narrative/docker/proxy_mgr.lua 
  sed -i 's/VolumesFrom = "",/VolumesFrom = json.util.null,/' /kb/deployment/services/narrative/docker/docker.lua
  # Certs
  mkdir /etc/nginx/ssl
  if [ -e /config/ssl/narrative.crt ] ; then
    cp /config/ssl/narrative.crt /etc/nginx/ssl/server.chained.crt
    cp /config/ssl/narrative.key /etc/nginx/ssl/server.key
  fi
  # Fix docker socket group
  GID=$(ls -n /var/run/docker.sock |awk '{print $4}')
  cat /etc/group|awk -F: '{if ($3=='$GID'){print "groupdel "$1}}'|sh
  groupmod -g $GID docker || groupadd -g $GID docker
  #sed -i 's/user www-data;/user www-data docker;\ndaemon off;\nerror_log \/dev\/stdout info;/' /etc/nginx/nginx.conf
  /usr/sbin/nginx
elif [ "$MYSERVICES" = "shell" ] ; then
  exec bash --login
else
  echo "What do you want to do? narrative or shell?"
fi
