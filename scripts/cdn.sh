#!/bin/sh

if [ "$1" = "rsync" ] ; then
  echo "rsync"
  [ -e /data/cdn/files ] || mkdir -p /data/cdn/files
  rsync -avz /kb/src/kbase-cdn-js/dist/bin/ /data/cdn/files/
elif [ "$1" = "shell" ] ; then
  exec bash --login
else
  echo "What do you want to do? rsync or shell?"
fi
