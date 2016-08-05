# Dockerfile that builds the base KBase image
#
#Copyright (c) 2015 The KBase Project and its Contributors
# United States Department of Energy
# The DOE Systems Biology Knowledgebase (KBase)
# Made available under the KBase Open Source License
#
FROM kbase/runtime:latest
MAINTAINER Shane Canon scanon@lbl.gov

RUN \
   apt-get update && \
   DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
   DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python-pip libcurl4-gnutls-dev python-dev ncurses-dev software-properties-common


# Split here just to manage the layer sizes
RUN \
   echo ''|add-apt-repository ppa:nginx/stable && \
   apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
   echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' \
          > /etc/apt/sources.list.d/mongodb.list && \
   curl -sL https://deb.nodesource.com/setup_4.x | bash && \
   DEBIAN_FRONTEND=noninteractive apt-get install -y \
     lua5.1 luarocks liblua5.1-0 liblua5.1-0-dev liblua5.1-json liblua5.1-lpeg2 \
     nginx nginx-extras nodejs \
     mongodb-10gen=2.4.14 apt-transport-https && \
   npm install -g grunt-cli && \
   apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
   echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" >> /etc/apt/sources.list.d/docker.list && \
   apt-get update && apt-get install -y docker-engine=1.7.1-0~trusty && \
   pip install --upgrade sphinx && \
   pip install docker-py gitpython pyyaml \
       pyopenssl ndg-httpsclient pyasn1 && \
   sed -i 's/not cert.get..subjectAltName., .../False/' /usr/local/lib/python2.7/dist-packages/requests/packages/urllib3/connection.py && \
   cpanm -i Config::IniFiles



RUN luarocks install luasocket;\
    luarocks install luajson;\
    luarocks install penlight;\
    luarocks install lua-spore;\
    luarocks install luacrypto

#mysystem("usermod www-data -G docker");

ENV TARGET /kb/deployment
ENV PATH ${TARGET}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Incremental package updates not yet in the run-time
# May not be needed anymore
RUN cpanm -i REST::Client && cpanm -i Time::ParseDate && \
    cd /kb/bootstrap/kb_seed_kmers/ && \
    ./build.seed_kmers /kb/runtime/ && \
    cd /kb/bootstrap/kb_glpk/ && \
    ./glpk_build.sh /kb/runtime/


# Bogus file to trigger a git clone and rebuild
ADD build.trigger /tmp/
RUN ( echo "Git clone";date) > /tmp/git.log

# Clone the base repos
RUN cd /kb && \
     git clone https://github.com/kbase/dev_container && \
     cd dev_container/modules && \
     git clone --recursive https://github.com/kbase/kbapi_common && \
     git clone --recursive https://github.com/kbase/typecomp && \
     git clone --recursive https://github.com/kbase/jars && \
     git clone --recursive https://github.com/kbase/auth -b develop && \
     git clone --recursive https://github.com/kbase/kbrest_common && \
     git clone --recursive https://github.com/kbase/kb_sdk -b develop && \
     cd /kb/dev_container && \
     grep -lr kbase.us/services /kb/| grep -v docs/ |\
        xargs sed -ri 's|https?://kbase.us/services|https://public.hostname.org:8443/services|g' && \
     ./bootstrap /kb/runtime && \
     . ./user-env.sh && make && make deploy


# Checkout core kbase software
RUN cd /kb/dev_container/modules && \
     git clone --recursive https://github.com/kbase/handle_service -b develop && \
     git clone --recursive https://github.com/kbase/narrative_method_store -b develop && \
     git clone --recursive https://github.com/kbase/narrative_job_service -b develop && \
     git clone --recursive https://github.com/kbase/handle_mngr -b develop && \
     git clone --recursive https://github.com/kbase/njs_wrapper -b develop && \
     git clone --recursive https://github.com/kbase/narrative_job_proxy -b develop && \
     git clone --recursive https://github.com/kbase/shock_service && \
     git clone --recursive https://github.com/kbase/auth_service && \
     git clone --recursive https://github.com/kbase/workspace_deluxe -b develop && \
     git clone --recursive https://github.com/kbase/awe_service && \
     git clone --recursive https://github.com/kbase/search && \
     git clone --recursive https://github.com/kbase/java_type_generator && \
     git clone --recursive https://github.com/kbase/user_profile -b develop && \
     git clone --recursive https://github.com/kbase/user_and_job_state -b develop && \
     git clone --recursive https://github.com/kbase/catalog -b develop && \
     git clone --recursive https://github.com/kbaseincubator/service_wizard -b develop && \
     git clone --recursive https://github.com/kbase/data_import_export -b dev && \
     git clone --recursive https://github.com/kbase/kbwf_common && \
     grep -lr kbase.us/services /kb/| grep -v docs/ | \
        xargs sed -ri 's|https?://kbase.us/services|https://public.hostname.org:8443/services|g' && \
     find /kb/dev_container/modules -iname ".git" | grep -v communities_api | grep -v m5nr | xargs rm -rf 

# Build and deploy kbase core software
ADD autodeploy.cfg /kb/dev_container/autodeploy.cfg
RUN cd /kb/dev_container && \
     . ./user-env.sh && make && \
     perl auto-deploy ./autodeploy.cfg

# Checkout narrative and UI
# Fixup kbase URL references
RUN \
        cd /kb/dev_container/modules && \
        git clone --recursive https://github.com/kbase/kbase-ui -b develop && \
        git clone --recurse-submodules https://github.com/kbase/narrative -b develop && \
        grep -lr kbase.us/services /kb/| grep -v docs/ | \
          xargs sed -ri 's|https?://kbase.us/services|https://public.hostname.org:8443/services|g' && \
        cd /kb/dev_container/modules/kbase-ui && \
        make init && make config=prod build && ./deploy.sh && \
        rm -rf /kb/dev_container/modules/kbase-ui/.git /kb/dev_container/modules/narrative/.git

# Minor fixes
RUN \
        apt-get install -y python-gevent && \
        wget https://github.com/rancher/rancher-compose/releases/download/v0.8.5/rancher-compose-linux-amd64-v0.8.5.tar.gz && \
        tar xzf rancher-compose-linux-amd64-v0.8.5.tar.gz  && \
        mv ./rancher-compose-v0.8.5/rancher-compose  /usr/bin/ && \
        pip install semantic_version && \
        pip install gdapi

# Make things run in the foreground and spit out logs -- hacky
RUN \
        sed -i 's/--daemonize [^ ]*log//' /kb/deployment/services/catalog/start_service && \
        sed -i 's/--daemonize [^ ]*log//' /kb/deployment/services/narrativejobproxy/start_service && \
        sed -i 's/--daemonize [^ ]*log//' /kb/deployment/services/service_wizard/start_service && \
        sed -i 's/--daemonize//' /kb/deployment/services/*/start_service && \
        sed -i 's/--error-log [^ "]*//' /kb/deployment/services/*/start_service && \
        sed -i 's/--pid [^ "]*//' /kb/deployment/services/*/start_service && \
        sed -i 's/\/kb\/runtime\/sbin\/daemonize .*\/kb/\/kb/' /kb/deployment/services/*/start_service && \
        sed -i 's/>.*//' /kb/deployment/services/njs_wrapper/start_service && \
        sed -i 's/nohup //' /kb/deployment/services/*/start_service

# General fixup
RUN \
    cd /kb/dev_container/modules/auth_service && . ../../user-env.sh && \
    mv authorization_server/oauth.py authorization_server/koauth.py && \
    sed -i 's/from oauth/from koauth/' authorization_server/authorization_server/urls.py  && \
    sed -i 's/oauth/koauth/' authorization_server/authorization_server/settings.py  && \
    sed -i 's/.\/start_service/echo done/' Makefile  && \
    sed -i 's/from django.conf.urls.d/#from django.conf.urls.d/' authorization_server/authorization_server/urls.py  && \
    make deploy-services && \
    sed -i 's/server.err/server.err daemonize=false/' /kb/deployment/services/authorization_server/start_service

ADD ./scripts /kb/scripts
ADD ./config /kb/config
# Additions
# - link is for backwards compatibility
#	cp /kb/config/nginx-full.cfg /etc/nginx/nginx.cfg && \
RUN \
        sed -i 's/user www-data;/user www-data docker;\ndaemon off;\nerror_log \/dev\/stdout info;/' /etc/nginx/nginx.conf && \
        mkdir -p /kb/deployment/services/narrative/docker && \
        cp -a /kb/dev_container/modules/narrative/docker/* /kb/deployment/services/narrative/docker/ && \
        ln -s /kb/scripts/config_mysql /kb/config/setup_mysql && \
        ln -s /kb/scripts/config_mongo /kb/config/setup_mongo && \
        ln -s /kb/scripts/config_Workspace /kb/config/postprocess_Workspace && \
        ln -s /kb/scripts/config_aweworker /kb/config/postprocess_aweworker && \
        chmod a+rx /kb/scripts /kb/config /kb/scripts/*

WORKDIR /kb/

ENV USER root
ENTRYPOINT [ "/kb/scripts/entrypoint.sh" ]
CMD [ ]
