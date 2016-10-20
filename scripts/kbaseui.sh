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

NARRATIVE_URL=$(grep -A20 '\[narrative\]' /kb/deployment/deployment.cfg|grep service-url|head -1|sed 's/.*=//'|sed 's|http.*://||'|sed 's|/||')

if [ -e /kb/deployment/services/kbase-ui ] ; then
  sed -i "s|public.hostname.org:8443|$PUBLICSSL|" /kb/deployment/services/kbase-ui/modules/config/service.yml
  sed -i "s|narrative.kbase.us|$NARRATIVE_URL|" /kb/deployment/services/kbase-ui/modules/config/service.yml
  sed -i "s|narrative.kbase.us|$NARRATIVE_URL|" /kb/deployment/services/kbase-ui/search/config.json
fi

grep -lr public.hostname.org /kb/deployment/*bin/ /kb/deployment/lib/ /kb/deployment/services/ | \
   xargs sed -i "s|public.hostname.org:8443|$PUBLICSSL|g"


if [ "$1" = "rsync" ] ; then
  echo "rsync"
  rsync -avz /kb/deployment/services/kbase-ui /data/
elif [ "$1" = "shell" ] ; then
  exec bash --login
else
  echo "What do you want to do? rsync or shell?"
fi
