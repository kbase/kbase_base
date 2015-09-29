# Dockerfile that builds the base KBase image
#
#Copyright (c) 2015 The KBase Project and its Contributors
# United States Department of Energy
# The DOE Systems Biology Knowledgebase (KBase)
# Made available under the KBase Open Source License
#
FROM kbase/runtime:latest
MAINTAINER Shane Canon scanon@lbl.gov

#RUN DEBIAN_FRONTEND=noninteractive apt-get update;apt-get -y upgrade;apt-get install -y \
#	mercurial bzr gfortran subversion tcsh cvs mysql-client libgd2-dev tcl-dev tk-dev \
#	libtiff-dev libpng12-dev libpng-dev libjpeg-dev libgd2-xpm-dev libxml2-dev \
#	libwxgtk2.8-dev libdb5.1-dev libgsl0-dev libxslt1-dev libfreetype6-dev libreadline-dev \
#	libpango1.0-dev libx11-dev libxt-dev libcairo2-dev zlib1g-dev libgtk2.0-dev python-dev \
#	libmysqlclient-dev libmysqld-dev libssl-dev libpq-dev libexpat1-dev libzmq-dev libbz2-dev \
#	libncurses5-dev libcurl4-gnutls-dev uuid-dev git wget uuid-dev build-essential curl \
#	libsqlite3-dev libffi-dev
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
         python-pip libcurl4-gnutls-dev python-dev ncurses-dev software-properties-common

RUN echo ''|add-apt-repository ppa:nginx/stable; apt-get update; apt-get install -y nginx nginx-extras

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
         lua5.1 luarocks liblua5.1-0 liblua5.1-0-dev liblua5.1-json liblua5.1-lpeg2 \
         nodejs-dev npm nodejs-legacy docker.io && \
         npm install -g grunt-cli && \
         apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
         echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list && \
         apt-get update && \
         apt-get install -y mongodb-10gen=2.4.14


RUN luarocks install luasocket;\
    luarocks install luajson;\
    luarocks install penlight;\
    luarocks install lua-spore;\
    luarocks install luacrypto

#mysystem("usermod www-data -G docker");

ENV TARGET /kb/deployment
ENV PATH ${TARGET}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Incremental package updates not yet in the run-time
RUN cpanm -i REST::Client && cpanm -i Time::ParseDate && \
    cd /kb/bootstrap/kb_seed_kmers/ && \
    ./build.seed_kmers /kb/runtime/ && \
    cd /kb/bootstrap/kb_glpk/ && \
    ./glpk_build.sh /kb/runtime/


# Clone the base repos
RUN cd /kb && \
     git clone https://github.com/kbase/dev_container && \
     cd dev_container/modules && \
     git clone --recursive https://github.com/kbase/kbapi_common && \
     git clone --recursive https://github.com/kbase/typecomp && \
     git clone --recursive https://github.com/kbase/jars && \
     git clone --recursive https://github.com/kbase/auth && \
     git clone --recursive https://github.com/kbase/kbrest_common && \
     cd /kb/dev_container && \
     ./bootstrap /kb/runtime && \
     . ./user-env.sh && make && make deploy


RUN cd /kb/dev_container/modules && \
     git clone --recursive https://github.com/kbase/handle_service && \
     git clone --recursive https://github.com/kbase/kb_model_seed && \
     git clone --recursive https://github.com/kbase/kmer_annotation_figfam && \
     git clone --recursive https://github.com/kbase/narrative_method_store && \
     git clone --recursive https://github.com/kbase/ontology_service && \
     git clone --recursive https://github.com/kbase/matR && \
     git clone --recursive https://github.com/kbase/protein_structure_service && \
     git clone --recursive https://github.com/kbase/erdb_service && \
     git clone --recursive https://github.com/kbase/narrative_job_service && \
     git clone --recursive https://github.com/kbase/KBaseFBAModeling && \
     git clone --recursive https://github.com/kbase/handle_mngr && \
     git clone --recursive https://github.com/kbase/idserver && \
     git clone --recursive https://github.com/kbase/meme && \
     git clone --recursive https://github.com/kbase/translation && \
     git clone --recursive https://github.com/kbase/strep_repeats && \
     git clone --recursive https://github.com/kbase/njs_wrapper && \
     git clone --recursive https://github.com/kbase/shock_service && \
     git clone --recursive https://github.com/kbase/trees && \
     mv trees/data /kb/deployment/services/trees/ && \
     mkdir trees/data && \
     git clone --recursive https://github.com/kbase/expression && \
     git clone --recursive https://github.com/kbase/auth_service && \
     git clone --recursive https://github.com/kbase/workspace_deluxe && \
     git clone --recursive https://github.com/kbase/awe_service && \
     git clone --recursive https://github.com/kbase/search && \
     git clone --recursive https://github.com/kbase/protein_info_service && \
     git clone --recursive https://github.com/kbase/transform && \
     rm -rf transform/t && \
     git clone --recursive https://github.com/kbase/uploader && \
     git clone --recursive https://github.com/kbase/gwas && \
     git clone --recursive https://github.com/kbase/kb_seed && \
     git clone --recursive https://github.com/kbase/coexpression && \
     git clone --recursive https://github.com/kbase/java_type_generator && \
     git clone --recursive https://github.com/kbase/m5nr && \
     git clone --recursive https://github.com/kbase/genome_comparison && \
     git clone --recursive https://github.com/kbase/user_profile && \
     git clone --recursive https://github.com/kbase/communities_api && \
     git clone --recursive https://github.com/kbase/user_and_job_state && \
     git clone --recursive https://github.com/kbase/networks && \
     git clone --recursive https://github.com/kbase/genome_annotation && \
     git clone --recursive https://github.com/kbase/id_map && \
     git clone --recursive https://github.com/kbase/cbd && \
     git clone --recursive https://github.com/kbase/kbwf_common && \
     git clone --recursive https://github.com/kbase/probabilistic_annotation && \
     git clone --recursive https://github.com/kbase/mgrast_pipeline && \
     git clone --recursive https://github.com/kbase/feature_values && \
     find /kb/dev_container/modules -iname ".git" | grep -v communities_api | grep -v m5nr | xargs rm -rf 

ADD autodeploy.cfg /kb/dev_container/autodeploy.cfg
RUN cd /kb/dev_container && \
     . ./user-env.sh && make && \
     perl auto-deploy ./autodeploy.cfg

# Make things run in the foreground and spit out logs -- hacky
RUN \
        sed -i 's/--daemonize [^ ]*log//' /kb/deployment/services/Transform/start_service;\
        sed -i 's/--daemonize//' /kb/deployment/services/*/start_service;\
        sed -i 's/--error-log [^ "]*//' /kb/deployment/services/*/start_service;\
        sed -i 's/--pid [^ "]*//' /kb/deployment/services/*/start_service;\
        [ -e /kb/deployment//services/fbaModelServices/start_service ] && sed -i 's/starman -D/starman/' /kb/deployment/services/fbaModelServices/start_service;\
        sed -i 's/\/kb\/runtime\/sbin\/daemonize .*\/kb/\/kb/' /kb/deployment/services/*/start_service;\
        sed -i 's/>.*//' /kb/deployment//services/*/start_service;\
        sed -i 's/nohup //' /kb/deployment//services/*/start_service

RUN \
        cd /kb/dev_container/modules;\
        git clone --recursive https://github.com/kbase/ui-common && \
        git clone --recurse-submodules https://github.com/kbase/narrative -b docker && \
        rm -rf /kb/dev_container/modules/ui-common/.git /kb/dev_container/modules/narrative/.git

ADD ./scripts /root/scripts
ADD ./config /root/config
# Additions
# - link is for backwards compatibility
RUN \
        cpanm -i Config::IniFiles && \
        ln -s /kb/deployment/deployment.cfg /root/cluster.ini.docker && \
        ln -s /root/scripts/config_mysql /root/config/setup_mysql && \
        ln -s /root/scripts/config_mongo /root/config/setup_mongo && \
        ln -s /root/scripts/config_Workspace /root/config/postprocess_Workspace && \
        ln -s /root/scripts/config_aweworker /root/config/postprocess_aweworker

WORKDIR /root/

ONBUILD ENV USER root

# Eventually move away from cluster.ini
ONBUILD ADD cluster.ini /root/deployment.cfg
ONBUILD ADD ssl /root/ssl
ONBUILD RUN ln -s /root/deployment.cfg /root/cluster.ini

# Add the ssl certs into the certificate tree
ONBUILD RUN cat ssl/proxy.crt  >> /etc/ssl/certs/ca-certificates.crt && \
    cat ssl/proxy.crt > /etc/ssl/certs/`openssl x509 -noout -hash -in ssl/proxy.crt`.0 && \
    cat ssl/proxy.crt  >> /usr/local/lib/python2.7/dist-packages/requests/cacert.pem && \
    cat ssl/narrative.crt  >> /etc/ssl/certs/ca-certificates.crt && \
    cat ssl/narrative.crt > /etc/ssl/certs/`openssl x509 -noout -hash -in ssl/narrative.crt`.0


# This run command does several things including:
# - Changing the memory size for the workspace
# - Change memory for other glassfish services
# - Deploy the nginx config (setup_www)
# - Run postporcess for shock and awe
# - Clones special versions of ui-common and narrative

ONBUILD RUN cp ./deployment.cfg /kb/deployment/deployment.cfg && \
        cd /kb/dev_container/ && . ./user-env.sh && \
        sed -i 's/10000/256/' /kb/deployment/services/workspace/start_service && \
        sed -i 's/15000/384/' /kb/deployment/services/workspace/start_service && \
        sed -i 's/--Xms 1000 --Xmx 2000/--Xms 384 --Xmx 512/' /kb/deployment/services/*/start_service && \
        /root/scripts/config_shock && \
        /root/scripts/config_awe && \
        sed -i 's/ssl_verify = True/ssl_verify = False/' /kb/deployment/lib/biokbase/Transform/script_utils.py && \
        /root/scripts/config_Transform && \
        [ -e /mnt/Shock/logs ] || mkdir -p /mnt/Shock/logs

# Fix up URLs in clients
ONBUILD RUN PUBLIC=$(grep baseurl= deployment.cfg|sed 's/baseurl=//'|sed 's/:.*//') && \
         sed -i "s|api-url=$|api-url=http://$PUBLIC:8080/services/shock-api|" /kb/deployment//services/shock_service/conf/shock.cfg  && \
         sed -i "s|public.hostname.org|$PUBLIC|" /kb/deployment/lib/biokbase/*/Client.py && \
         sed -i "s|public.hostname.org|$PUBLIC|" /kb/deployment/lib/Bio/KBase/*/Client.pm && \
         sed -i "s|public.hostname.org|$PUBLIC|" /kb/deployment/lib/javascript/*/Client.js

ONBUILD ENTRYPOINT [ "./scripts/entrypoint.sh" ]
ONBUILD CMD [ ]
