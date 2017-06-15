#!/bin/sh

export KB_DEPLOYMENT_CONFIG=/config/deployment.cfg

cd /kb/dev_container/modules/auth2/jettybase/

/usr/lib/jvm/java-8-openjdk-amd64/bin/java  -DSTOP.PORT=8079 -DSTOP.KEY=foo -jar /usr/local/jetty-distribution-9.3.11.v20160721/start.jar 
