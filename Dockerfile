FROM phusion/baseimage:latest
MAINTAINER ethnchao <maicheng.linyi@gmail.com>

ENV NAGIOS_HOME             /usr/local/nagios
ENV NAGIOS_USER             nagios
ENV NAGIOS_GROUP            nagcmd
ENV DEBIAN_FRONTEND         noninteractive
ENV NRDP_TOKEN              culaio239ncgklak
ENV NCPA_TOKEN              mfasjlk1asjd7flj3ly
ENV MYSQL_USER              nagios
ENV MYSQL_PASSWORD          nagios
ENV MYSQL_ADDRESS           nagios_mysql
ENV MYSQL_DATABASE          nagios

ENV ADAGIOS_VERSION         1.6.3-2
ENV GRAPHIOS_VERSION        2.0.3
ENV GRAPHITE_VERSION        1.1.3
ENV GRAFANA_VERSION         5.1.3
ENV MK_LIVESTATUS_VERSION   1.2.8p20
ENV NAGIOS_VERSION          4.3.4
ENV NAGIOS_PLUGINS_VERSION  2.2.1
ENV NCPA_VERSION            2.1.3
ENV NDOUTILS_VERSION        2.1.3
ENV NRDP_VERSION            1.5.2
ENV NRPE_VERSION            3.2.1
ENV OKCONFIG_VERSION        1.3.2-1
ENV PYNAG_VERSION           0.9.1-1

# Remove below if you want use default apt mirror sites
ADD config/apt-sources.list /etc/apt/sources.list
# Remove below if you want use default pip mirror sites
ADD config/pip.conf /root/.config/pip/pip.conf
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    automake apache2 apache2-utils autoconf \
    bc build-essential bsd-mailx \
    dc \
    fping \
    gawk gettext gperf git \
    iputils-ping \
    libapache2-mod-php libgd2-xpm-dev libmcrypt-dev libssl-dev libcairo2-dev libffi-dev libapache2-mod-wsgi libmysql++-dev libmysqlclient-dev libnet-snmp-perl \
    m4 mysql-client \
    netcat \
    python-pip python-dev python3-dev parallel php7.0-xml postfix \
    runit \
    smbclient snmp snmpd snmp-mibs-downloader sudo \
    unzip && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  pip install --upgrade --no-cache-dir pip distribute virtualenv

RUN ( id -u $NAGIOS_USER || useradd --system -d $NAGIOS_HOME $NAGIOS_USER ) && \
  ( egrep -i "^${NAGIOS_GROUP}" /etc/group || groupadd $NAGIOS_GROUP ) && \
  usermod -a -G $NAGIOS_GROUP $NAGIOS_USER && \
  usermod -a -G $NAGIOS_GROUP www-data

RUN pip install --no-cache-dir --no-binary=:all: https://github.com/pynag/pynag/tarball/master

# https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/nagioscore/-/archive/nagios-${NAGIOS_VERSION}/nagioscore-nagios-${NAGIOS_VERSION}.zip

RUN cd /tmp && \
  curl -L https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.zip -o nagioscore.zip && \
  unzip nagioscore.zip && \
  mv nagioscore-* nagioscore && \
  cd nagioscore && \
  ./configure \
    --prefix=${NAGIOS_HOME} \
    --enable-event-broker \
    --with-command-group=${NAGIOS_GROUP} \
    --with-nagios-user=${NAGIOS_USER} \
    --with-nagios-group=${NAGIOS_GROUP} && \
  make all && \
  make install && \
  make install-config && \
  make install-commandmode && \
  make install-webconf && \
  make install-init && \
  rm -rf /tmp/nagioscore /tmp/nagioscore.zip

RUN mkdir -p ${NAGIOS_HOME}/etc/mount /data/plugin && \
  chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} /data ${NAGIOS_HOME} && \
  cd /etc/apache2/sites-available && \
  export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)" && \
  sed -i "s,DocumentRoot.*,$DOC_ROOT," 000-default.conf && \
  sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ ${NAGIOS_HOME}/sbin/\n</IfDefine>\n</VirtualHost>," 000-default.conf && \
  a2enmod cgi && \
  pynag delete --force WHERE host_name=localhost AND service_description=SSH && \
  cd ${NAGIOS_HOME}/etc/ && \
  echo "\$USER2\$=/data/plugin" >> resource.cfg && \
  pynag config --append "cfg_dir=${NAGIOS_HOME}/etc/mount" && \
  htpasswd -c -b -s htpasswd.users nagiosadmin nagios && \
  sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg && \
  echo 'define command{\n\
    command_name    check_nrpe\n\
    command_line    $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$\n\
}\n\
\n\
define command{\n\
    command_name    check_dummy\n\
    command_line    $USER1$/check_dummy $ARG1$\n\
}\n\n' >> objects/commands.cfg

# https://github.com/nagios-plugins/nagios-plugins/archive/release-${NAGIOS_PLUGINS_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/nagios-plugins/-/archive/release-${NAGIOS_PLUGINS_VERSION}/nagios-plugins-release-${NAGIOS_PLUGINS_VERSION}.zip

RUN cd /tmp && \
  curl -L https://github.com/nagios-plugins/nagios-plugins/archive/release-${NAGIOS_PLUGINS_VERSION}.zip -o nagios-plugins.zip && \
  unzip nagios-plugins.zip && \
  mv nagios-plugins-* nagios-plugins && \
  cd nagios-plugins && \
  ./tools/setup && \
  ./configure --prefix=${NAGIOS_HOME} && \
  make && \
  make install && \
  cd /tmp && \
  rm -rf /tmp/nagios-plugins /tmp/nagios-plugins.zip

# https://github.com/NagiosEnterprises/nrpe/archive/nrpe-${NRPE_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/nrpe/-/archive/nrpe-${NRPE_VERSION}/nrpe-nrpe-${NRPE_VERSION}.zip

RUN cd /tmp && \
  curl -L https://github.com/NagiosEnterprises/nrpe/archive/nrpe-${NRPE_VERSION}.zip -o nrpe.zip && \
  unzip nrpe.zip && \
  mv nrpe-* nrpe && \
  cd nrpe && \
  ./configure --prefix=${NAGIOS_HOME} --with-nagios-user=${NAGIOS_USER} --with-nagios-group=${NAGIOS_GROUP} && \
  make check_nrpe && \
  make install-plugin && \
  rm -rf /tmp/nrpe /tmp/nrpe.zip

RUN mkdir -p /usr/share/snmp/mibs && \
  ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs && \
  download-mibs && \
  echo "mibs +ALL" > /etc/snmp/snmp.conf

RUN virtualenv --python=python3.5 /opt/graphite && \
  . /opt/graphite/bin/activate && \
  pip install --no-cache-dir cffi scandir && \
  pip install --no-cache-dir --no-binary=:all: \
    https://github.com/graphite-project/whisper/archive/${GRAPHITE_VERSION}.zip \
    https://github.com/graphite-project/carbon/archive/${GRAPHITE_VERSION}.zip \
    https://github.com/graphite-project/graphite-web/archive/${GRAPHITE_VERSION}.zip && \
  deactivate

ADD config/carbon.conf /opt/graphite/conf/carbon.conf
RUN cd /opt/graphite/conf/ && \
  cp storage-schemas.conf.example storage-schemas.conf && \
  cp graphite.wsgi.example graphite.wsgi && \
  cp storage-aggregation.conf.example storage-aggregation.conf && \
  sed -i 's/import sys/import sys, site/' graphite.wsgi && \
  sed -i '/import sys, site/a\site.addsitedir("/opt/graphite/lib/python3.5/site-packages")' graphite.wsgi && \
  cd /opt/graphite/webapp/graphite/ && \
  cp local_settings.py.example local_settings.py && \
  . /opt/graphite/bin/activate && \
  export PYTHONPATH="/opt/graphite/lib/:/opt/graphite/webapp/" && \
  django-admin.py migrate --settings=graphite.settings --run-syncdb && \
  unset PYTHONPATH && \
  deactivate && \
  chown -R www-data:www-data /opt/graphite/storage && \
  cd /etc/apache2/sites-available/ && \
  cp /opt/graphite/examples/example-graphite-vhost.conf graphite.conf && \
  sed -i 's/80/8080/' graphite.conf && \
  sed -i 's;WSGISocketPrefix run/wsgi;WSGISocketPrefix /var/run/apache2/wsgi;' graphite.conf && \
  a2ensite graphite && \
  echo "Listen 8080" >> /etc/apache2/ports.conf

RUN mkdir -p /var/spool/nagios/graphios && \
  chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} /var/spool/nagios && \
  pip install --no-cache-dir graphios==${GRAPHIOS_VERSION} && \
  sed -i 's/^enable_carbon.*/enable_carbon = True/' /etc/graphios/graphios.cfg && \
  sed -i 's/^debug.*/debug = False/' /etc/graphios/graphios.cfg && \
  sed -i 's/^debug.*/debug = False/' /usr/local/bin/graphios.py && \
  sed -i 's;^config_file.*;config_file = "/etc/graphios/graphios.cfg";' /usr/local/bin/graphios.py && \
  cd "${NAGIOS_HOME}/etc/" && \
  pynag config --remove cfg_dir --old_value="${NAGIOS_HOME}/etc/objects" && \
  pynag config --set service_perfdata_file_processing_command=graphite_perf_service && \
  pynag config --set host_perfdata_file_processing_command=graphite_perf_host && \
  pynag update --force SET _graphitepostfix=ping WHERE host_name=localhost AND service_description='PING' && \
  pynag update --force SET _graphitepostfix=loadaverage WHERE host_name=localhost AND service_description='Current Load' && \
  echo 'define command {\n\
    command_name            graphite_perf_host\n\
    command_line            /bin/mv /var/spool/nagios/graphios/host-perfdata /var/spool/nagios/graphios/host-perfdata.$TIMET$\n\
}\n\
\n\
define command {\n\
    command_name            graphite_perf_service\n\
    command_line            /bin/mv /var/spool/nagios/graphios/service-perfdata /var/spool/nagios/graphios/service-perfdata.$TIMET$\n\
}\n\n' >> objects/commands.cfg

# Grafana default mirror site: deb https://packagecloud.io/grafana/stable/debian/ jessie main

RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/grafana/apt/ jessie main" >> /etc/apt/sources.list && \
  curl https://packagecloud.io/gpg.key | sudo apt-key add - && \
  apt-get update && \
  apt-get install -y --no-install-recommends grafana=${GRAFANA_VERSION} && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# https://github.com/NagiosEnterprises/ndoutils/archive/ndoutils-${NDOUTILS_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/ndoutils/-/archive/ndoutils-${NDOUTILS_VERSION}/ndoutils-ndoutils-${NDOUTILS_VERSION}.zip

RUN cd /tmp && \
  curl -L https://github.com/NagiosEnterprises/ndoutils/archive/ndoutils-${NDOUTILS_VERSION}.zip -o ndoutils.zip && \
  unzip ndoutils.zip && \
  mv ndoutils-* ndoutils && \
  cd ndoutils && \
  ./configure --prefix="${NAGIOS_HOME}" --enable-mysql && \
  make all && \
  make install && \
  cp config/ndo2db.cfg-sample ${NAGIOS_HOME}/etc/ndo2db.cfg-sample && \
  cp db/mysql.sql ${NAGIOS_HOME}/share/mysql-createdb.sql && \
  sed -i 's/ENGINE=MyISAM/ENGINE=MyISAM DEFAULT CHARSET=utf8/g' ${NAGIOS_HOME}/share/mysql-createdb.sql && \
  cp config/ndomod.cfg-sample "${NAGIOS_HOME}"/etc/ndomod.cfg && \
  chmod 666 ${NAGIOS_HOME}/etc/ndomod.cfg && \
  rm -rf /tmp/ndoutils /tmp/ndoutils.zip

RUN cd /tmp/ && \
  curl -L https://github.com/vishnubob/wait-for-it/archive/master.zip -o wait-for-it.zip && \
  unzip wait-for-it.zip && \
  mv wait-for-it-master/wait-for-it.sh /usr/bin/wait-for-it && \
  chmod +x /usr/bin/wait-for-it && \
  rm -rf /tmp/wait-for-it-master /tmp/wait-for-it.zip

# https://github.com/NagiosEnterprises/nrdp/archive/${NRDP_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/nrdp/-/archive/nrdp-${NRDP_VERSION}/nrdp-nrdp-${NRDP_VERSION}.zip

RUN cd /usr/local/ && \
  curl -L https://github.com/NagiosEnterprises/nrdp/archive/${NRDP_VERSION}.zip -o nrdp.zip && \
  unzip nrdp.zip && \
  rm -f nrdp.zip && \
  mv nrdp-* nrdp && \
  chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} nrdp && \
  mv nrdp/server/config.inc.php nrdp/server/config.inc.php.example && \
  echo "<Directory \"/usr/local/nrdp\">\n\
    Options None\n\
    AllowOverride None\n\
    Require all granted\n\
</Directory>\n\
Alias /nrdp \"/usr/local/nrdp/server\"\n" > /etc/apache2/sites-available/nrdp.conf && \
  a2ensite nrdp

# https://github.com/opinkerfi/okconfig/archive/okconfig-${OKCONFIG_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/okconfig/-/archive/okconfig-${OKCONFIG_VERSION}/okconfig-okconfig-${OKCONFIG_VERSION}.zip

RUN cd /tmp && \
  curl -L https://github.com/opinkerfi/okconfig/archive/okconfig-${OKCONFIG_VERSION}.zip -o okconfig.zip && \
  unzip okconfig.zip && \
  mv okconfig-* okconfig && \
  cd okconfig && \
  pip install --no-cache-dir . && \
  cp -f etc/okconfig.conf /etc/okconfig.conf && \
  mkdir -p ${NAGIOS_HOME}/etc/okconfig/ /data/example && \
  chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME} /data/example && \
  sed -i "s,/etc/nagios/,${NAGIOS_HOME}/etc/," /etc/okconfig.conf && \
  sed -i "s,${NAGIOS_HOME}/etc/okconfig/examples,/data/example," /etc/okconfig.conf && \
  cd /usr/share/okconfig && \
  find ./templates/ -name '*cfg*' -type f -exec sed -i 's/normal_check_interval/check_interval/' {} \; && \
  okconfig init && \
  okconfig verify && \
  rm -rf /tmp/okconfig /tmp/okconfig.zip

ADD okconfig/install_ncpa.bat /usr/share/okconfig/client/windows/install.bat.example
ADD okconfig/install_nsclient.sh /usr/share/okconfig/client/windows/install_nsclient.sh
ADD okconfig/install_okagent.sh /usr/share/okconfig/client/linux/install_okagent.sh.example

RUN cd /usr/share/okconfig/client/ && \
  mkdir -p windows/ncpa/ && \
  curl -L https://assets.nagios.com/downloads/ncpa/archived/${NCPA_VERSION}/ncpa-${NCPA_VERSION}.exe -o windows/ncpa/ncpa.exe && \
  chmod +x windows/install_nsclient.sh linux/install_okagent.sh.example && \
  curl -L http://ftp.twaren.net/Linux/OpenSuSE/repositories/home:/uibmz:/opsi:/opsi40-experimental/Univention_4.1/amd64/winexe_1.00.1-1_amd64.deb -o /tmp/winexe.deb && \
  dpkg -i /tmp/winexe.deb && \
  rm -f /tmp/winexe.deb

RUN cd /tmp && \
  curl http://mathias-kettner.com/download/mk-livestatus-${MK_LIVESTATUS_VERSION}.tar.gz -o mk-livestatus.tar.gz && \
  tar zxf mk-livestatus.tar.gz && \
  rm -f mk-livestatus.tar.gz && \
  mv mk-livestatus* mk-livestatus && \
  cd mk-livestatus && \
  ./configure --with-nagios4 && \
  make && \
  make install && \
  rm -rf /tmp/mk-livestatus

# https://github.com/opinkerfi/adagios/archive/adagios-${ADAGIOS_VERSION}.zip
# http://192.168.120.155:8000/ethnchao/adagios/-/archive/adagios-${ADAGIOS_VERSION}/adagios-adagios-${ADAGIOS_VERSION}.zip

RUN virtualenv /opt/adagios && \
  . /opt/adagios/bin/activate && \
  cd /tmp && \
  curl -L https://github.com/opinkerfi/adagios/archive/adagios-${ADAGIOS_VERSION}.zip -o adagios.zip && \
  unzip adagios.zip && \
  mv adagios-* adagios && \
  cd adagios && \
  pip install --no-cache-dir --no-binary=:all: -r requirements.txt . https://github.com/pynag/pynag/archive/pynag-${PYNAG_VERSION}.zip && \
  deactivate && \
  cp -r adagios/etc/adagios/ /etc/ && \
  rm -rf /tmp/adagios /tmp/adagios.zip

RUN cd /etc/adagios/ && \
  sed -i 's,^enable_pnp4nagios.*,enable_pnp4nagios=False,' adagios.conf && \
  sed -i "s,^nagios_config.*,nagios_config=\"${NAGIOS_HOME}/etc/nagios.cfg\"," adagios.conf && \
  sed -i "s,^nagios_binary.*,nagios_binary=\"${NAGIOS_HOME}/bin/nagios\"," adagios.conf && \
  sed -i "s,^livestatus_path.*,livestatus_path=\"${NAGIOS_HOME}/var/livestatus\"," adagios.conf && \
  sed -i "s,^destination_directory.*,destination_directory=\"${NAGIOS_HOME}/etc/adagios/\"," adagios.conf && \
  mkdir -p ${NAGIOS_HOME}/etc/adagios/ /var/lib/adagios/ && \
  cd ${NAGIOS_HOME}/etc && \
  git init && \
  git config user.name "nagios" && \
  git config user.email "nagios@localhost.com" && \
  git add * && \
  git commit -m "Initial commit" && \
  pynag config --set cfg_dir="${NAGIOS_HOME}/etc/adagios" && \
  pynag config --append "broker_module=/usr/local/lib/mk-livestatus/livestatus.o ${NAGIOS_HOME}/var/livestatus" && \
  chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} /etc/adagios/ ${NAGIOS_HOME}/ /var/lib/adagios/ && \
  cd /opt/adagios/local/lib/python2.7/site-packages/adagios/ && \
  cp wsgi.py wsgi.py.origin && \
  sed -i 's/import os/import os, site/' wsgi.py && \
  sed -i '/import os, site/a\site.addsitedir("/opt/adagios/lib/python2.7/site-packages")' wsgi.py && \
  echo "${NAGIOS_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/adagios && \
  chmod 0440 /etc/sudoers.d/adagios && \
  echo "WSGISocketPrefix /var/run/apache2/wsgi \n\
WSGIDaemonProcess adagios user=${NAGIOS_USER} group=${NAGIOS_GROUP} processes=1 threads=25 \n\
WSGIScriptAlias /adagios /opt/adagios/lib/python2.7/site-packages/adagios/wsgi.py \n\
Alias /adagios/media /opt/adagios/lib/python2.7/site-packages/adagios/media \n\
<Location /adagios> \n\
    WSGIProcessGroup adagios \n\
    AuthName \"Adagios Access\" \n\
    AuthType Basic \n\
    AuthUserFile ${NAGIOS_HOME}/etc/htpasswd.users \n\
    Require valid-user \n\
    RedirectMatch ^/adagios$ /adagios/ \n\
</Location> \n" > /etc/apache2/sites-available/adagios.conf && \
  a2ensite adagios

ADD run.sh /run.sh
ADD config/sv/apache/run /etc/sv/apache/run
ADD config/sv/carbon/run /etc/sv/carbon/run
ADD config/sv/postfix/run /etc/sv/postfix/run
ADD config/sv/graphios/run /etc/sv/graphios/run

RUN rm -rf /etc/sv/getty-5 && \
  chmod +x /run.sh /etc/sv/apache/run /etc/sv/graphios/run /etc/sv/postfix/run /etc/sv/carbon/run && \
  ln -s /etc/sv/* /etc/service && \
  cp /etc/services /var/spool/postfix/etc/ && \
  ln -sf "/usr/share/zoneinfo/Asia/Shanghai" /etc/localtime

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80
EXPOSE 3000

ENTRYPOINT ["/run.sh"]

CMD [ "main" ]
