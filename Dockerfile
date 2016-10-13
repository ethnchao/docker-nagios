FROM phusion/baseimage:latest
MAINTAINER ethnchao <maicheng.linyi@gmail.com>

ENV NAGIOS_HOME				/opt/nagios
ENV NAGIOS_USER				nagios
ENV NAGIOS_GROUP			nagios
ENV NAGIOS_CMDUSER			nagios
ENV NAGIOS_CMDGROUP			nagios
ENV APACHE_RUN_USER			nagios
ENV APACHE_RUN_GROUP		nagios
ENV NAGIOS_TIMEZONE			Asia/Shanghai
ENV DEBIAN_FRONTEND			noninteractive
ENV NG_NAGIOS_CONFIG_FILE	${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR				${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR				${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL				/cgi-bin
ENV NRDP_TOKEN              culaio239ncgklak

RUN	sed -i 's/universe/universe multiverse/' /etc/apt/sources.list \
    && apt-get update

RUN	apt-get install -y --no-install-recommends \
		iputils-ping \
		netcat \
		build-essential \
		automake \
		autoconf \
		gettext \
		m4 \
		gperf \
		snmp \
		snmpd \
		snmp-mibs-downloader \
		php-cli \
		php-gd \
		libgd2-xpm-dev \
		apache2 \
		apache2-utils \
		libapache2-mod-php \
		runit \
		unzip \
		bc \
		postfix \
		bsd-mailx \
		libnet-snmp-perl \
		git \
		libssl-dev \
		libcgi-pm-perl \
		librrds-perl \
		libgd-gd2-perl \
		libnagios-object-perl \
		fping \
		libfreeradius-client-dev \
		libnet-snmp-perl \
		libnet-xmpp-perl \
		mysql-client \
		libmysql++-dev \
		libmysqlclient-dev \
		parallel \
		libapache2-mod-wsgi \
		python-django \
		python-simplejson \
		libgmp-dev \
		python-dev \
		python-paramiko \
		sudo \
        php7.0-xml \
        smbclient \
		&& apt-get clean \
    && cd /tmp \
    && curl https://bootstrap.pypa.io/get-pip.py -O \
    && python get-pip.py \
    && pip install distribute \
    && rm -f get-pip.py \
    && rm -rf /var/lib/apt/lists/*

RUN	( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd $NAGIOS_GROUP    ) \
	&& ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP ) \
    && ( id -u $NAGIOS_USER    || useradd --system -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    ) \
	&& ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

RUN	cd /tmp \
	&& git clone https://github.com/multiplay/qstat.git	\
	&& cd qstat \
	&& ./autogen.sh \
	&& ./configure \
	&& make \
	&& make install \
    && rm -rf /tmp/qstat

RUN	cd /tmp \
	&& git clone https://github.com/NagiosEnterprises/nagioscore.git \
	&& cd nagioscore \
	&& git checkout tags/4.2.1 \
	&& ./configure \
		--prefix=${NAGIOS_HOME} \
		--exec-prefix=${NAGIOS_HOME} \
		--enable-event-broker \
		--with-nagios-command-user=${NAGIOS_CMDUSER} \
		--with-command-group=${NAGIOS_CMDGROUP} \
		--with-nagios-user=${NAGIOS_USER} \
		--with-nagios-group=${NAGIOS_GROUP} \
	&& make all \
	&& make install \
	&& make install-config \
	&& make install-commandmode \
	&& cp sample-config/httpd.conf /etc/apache2/conf-available/nagios.conf \
	&& ln -s /etc/apache2/conf-available/nagios.conf /etc/apache2/conf-enabled/nagios.conf \
    && htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users nagiosadmin nagios \
	&& ln -s "${NAGIOS_HOME}/etc" /etc/nagios \
    && mkdir -p ${NAGIOS_HOME}/etc/conf.d \
    && echo "\$USER2\$=${NAGIOS_HOME}/libexec/plugin.d" >> /etc/nagios/resource.cfg \
    && cd /tmp \
    && rm -rf /tmp/nagioscore

RUN	cd /tmp \
	&& git clone https://github.com/nagios-plugins/nagios-plugins.git \
	&& cd nagios-plugins \
	&& git checkout tags/release-2.1.3 \
	&& ./tools/setup \
	&& ./configure \
		--prefix=${NAGIOS_HOME} \
	&& make \
	&& make install \
    && cd /tmp \
    && rm -rf /tmp/nagios-plugins

RUN	cd /tmp \
	&& git clone http://git.code.sf.net/p/nagiosgraph/git nagiosgraph \
	&& cd nagiosgraph \
	&& ./install.pl --install \
		--prefix /opt/nagiosgraph \
		--nagios-user ${NAGIOS_USER} \
		--www-user ${NAGIOS_USER} \
		--nagios-perfdata-file ${NAGIOS_HOME}/var/perfdata.log \
		--nagios-cgi-url /cgi-bin \
	&& cp share/nagiosgraph.ssi ${NAGIOS_HOME}/share/ssi/common-header.ssi \
    && cd /tmp \
    && rm -rf /tmp/nagiosgraph

RUN cd /opt \
	&& git clone https://github.com/willixix/WL-NagiosPlugins.git WL-Nagios-Plugins \
	&& git clone https://github.com/JasonRivers/nagios-plugins.git JR-Nagios-Plugins \
	&& git clone https://github.com/justintime/nagios-plugins.git JE-Nagios-Plugins \
	&& chmod +x /opt/WL-Nagios-Plugins/check* \
	&& chmod +x /opt/JE-Nagios-Plugins/check_mem/check_mem.pl \
	&& cp /opt/JE-Nagios-Plugins/check_mem/check_mem.pl /opt/nagios/libexec/ \
	&& cp /opt/nagios/libexec/utils.sh /opt/JR-Nagios-Plugins/

RUN	sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN	export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)" \
	&& sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-enabled/000-default.conf \
	&& sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ ${NAGIOS_HOME}/sbin/\n</IfDefine>\n</VirtualHost>," /etc/apache2/sites-enabled/000-default.conf \
	&& ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load \
	&& mkdir -p /usr/share/snmp/mibs \
	&& mkdir -p ${NAGIOS_HOME}/.ssh \
	&& chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh \
	&& chmod 700 ${NAGIOS_HOME}/.ssh \
	&& chmod 0755 /usr/share/snmp/mibs \
	&& touch /usr/share/snmp/mibs/.foo \
	&& ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs \
	&& ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios \
	&& echo "SetEnv TZ \"${NAGIOS_TIMEZONE}\"" >> /etc/apache2/conf-enabled/nagios.conf \
	&& download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

ADD files/ndoutils_mysql.patch /tmp/ndoutils_mysql.patch
RUN cd /tmp \
	&& git clone https://github.com/NagiosEnterprises/ndoutils.git \
	&& cd ndoutils \
	&& git checkout tags/2.1.1 \
	&& ./configure \
		--prefix="${NAGIOS_HOME}" \
		--enable-mysql \
	&& make all\
	&& make install \
	&& cp config/ndo2db.cfg-sample "${NAGIOS_HOME}"/etc/ndo2db.cfg \
	&& cp config/ndomod.cfg-sample "${NAGIOS_HOME}"/etc/ndomod.cfg \
	&& cp db/mysql.sql /tmp/mysql.sql \
	&& patch /tmp/mysql.sql /tmp/ndoutils_mysql.patch \
	&& chmod 666 "${NAGIOS_HOME}/etc/ndomod.cfg" \
	&& echo "broker_module=${NAGIOS_HOME}/bin/ndomod.o config_file=${NAGIOS_HOME}/etc/ndomod.cfg" >> ${NAGIOS_HOME}/etc/nagios.cfg \
	&& sed -i 's/ENGINE=MyISAM/ENGINE=MyISAM DEFAULT CHARSET=utf8/g' /tmp/mysql.sql \
	&& cd /tmp \
	&& git clone https://github.com/vishnubob/wait-for-it.git \
	&& chmod +x /tmp/wait-for-it/wait-for-it.sh \
	&& cp /tmp/wait-for-it/wait-for-it.sh /usr/bin/wait-for-it \
    && cd /tmp \
    && rm -rf /tmp/ndoutils /tmp/wait-for-it /tmp/ndoutils_mysql.patch

RUN cd /opt \
    && git clone https://github.com/NagiosEnterprises/nrdp.git \
    && cd nrdp \
    && sed -i "s,//\"mysecrettoken\",\"${NRDP_TOKEN}\"," server/config.inc.php \
    && sed -i "s,^\$cfg\[\"nagios_command_group\"\]=.*,\$cfg[\"nagios_command_group\"]=\"${NAGIOS_CMDGROUP}\";," server/config.inc.php \
    && sed -i "s,/usr/local/nagios,${NAGIOS_HOME}," server/config.inc.php \
    && sed -i "s,;extension=php_xmlrpc.dll,extension=php_xmlrpc.dll," /etc/php/7.0/apache2/php.ini \
    && echo "<Directory \"/opt/nrdp\">\n\
    Options None\n\
    AllowOverride None\n\
    Require all granted\n\
</Directory>\n\
Alias /nrdp \"/opt/nrdp/server\"\n" > /etc/apache2/conf-available/nrdp.conf \
    && ln -s /etc/apache2/conf-available/nrdp.conf /etc/apache2/conf-enabled/nrdp.conf \
    && rm -rf /tmp/nrdp

RUN cd /tmp \
	&& git clone https://github.com/pynag/pynag.git \
	&& cd pynag \
	&& python setup.py build \
	&& python setup.py install \
    && python setup.py clean \
    && cd /tmp \
    && rm -rf /tmp/pynag

RUN cd /tmp \
    && git clone https://github.com/opinkerfi/okconfig.git \
    && cd okconfig \
    && python setup.py build \
    && python setup.py install \
    && python setup.py clean \
    && mkdir -p ${NAGIOS_HOME}/etc/okconfig/ \
    && cp etc/okconfig.conf /etc/okconfig.conf \
    && sed -i "s,^nagios_config.*,nagios_config ${NAGIOS_HOME}/etc/nagios.cfg," /etc/okconfig.conf \
    && sed -i "s,/etc/nagios/okconfig/,${NAGIOS_HOME}/etc/okconfig/," /etc/okconfig.conf \
    && mkdir -p "${NAGIOS_HOME}/etc/okconfig/" \
    && okconfig init \
    && okconfig verify \
    && mkdir /usr/share/okconfig/client/windows/ncpa \
    && cd /usr/share/okconfig/client/windows/ncpa \
    && curl -LSfO https://assets.nagios.com/downloads/ncpa/ncpa-1.8.1.exe \
    && cd /tmp \
    && curl -LSf http://download.opensuse.org/repositories/home:/uibmz:/opsi:/opsi40-testing/xUbuntu_12.04/amd64/winexe_1.00.1-1_amd64.deb -o winexe.deb \
    && dpkg -i winexe.deb \
    && rm -rf /tmp/okconfig /tmp/winexe.deb

RUN cd /tmp \
    && git clone https://github.com/opinkerfi/adagios.git \
    && cd adagios \
    && git checkout tags/adagios-1.6.3-1 \
    && python setup.py build \
    && python setup.py install \
    && python setup.py clean \
    && mkdir -p "${NAGIOS_HOME}/etc/adagios/" \
    && cp -r adagios/etc/adagios /etc/ \
    && chown -R "${NAGIOS_USER}:${NAGIOS_GROUP}" /etc/adagios/ \
    && chown -R "${NAGIOS_USER}:${NAGIOS_GROUP}" "${NAGIOS_HOME}/etc/" \
    && sed -i "s,^nagios_service.*,#nagios_service=," /etc/adagios/adagios.conf \
    && sed -i 's,^enable_pnp4nagios.*,enable_pnp4nagios=False,;' /etc/adagios/adagios.conf \
    && sed -i "s,^nagios_binary.*,nagios_binary=\"${NAGIOS_HOME}/bin/nagios\"," /etc/adagios/adagios.conf \
    && sed -i "s,^nagios_init_script.*,nagios_init_script=\"sudo /etc/init.d/nagios\"," /etc/adagios/adagios.conf \
    && sed -i "s,^livestatus_path.*,livestatus_path=\"${NAGIOS_HOME}/var/livestatus\"," /etc/adagios/adagios.conf \
    && sed -i "s,^destination_directory.*,destination_directory=\"${NAGIOS_HOME}/etc/adagios/\"," /etc/adagios/adagios.conf \
    && echo "WSGISocketPrefix /var/run/apache2/wsgi \n\
WSGIDaemonProcess adagios user=${NAGIOS_USER} group=${NAGIOS_GROUP} processes=1 threads=25 \n\
WSGIScriptAlias /adagios /usr/local/lib/python2.7/dist-packages/adagios/wsgi.py \n\
Alias /adagios/media /usr/local/lib/python2.7/dist-packages/adagios/media \n\
<Location /adagios> \n\
    WSGIProcessGroup adagios \n\
    AuthName \"Adagios Access\" \n\
    AuthType Basic \n\
    AuthUserFile ${NAGIOS_HOME}/etc/htpasswd.users \n\
    Require valid-user \n\
    RedirectMatch ^/adagios$ /adagios/ \n\
</Location> \n" > /etc/apache2/conf-available/adagios.conf \
    && ln -s /etc/apache2/conf-available/adagios.conf /etc/apache2/conf-enabled/adagios.conf \
    && cd "${NAGIOS_HOME}/etc" \
    && git init \
    && git config user.name "nagios" \
    && git config user.email "nagios@localhost.com" \
    && git add * \
    && git commit -m "Initial commit" \
    && mkdir -p /var/lib/adagios/ \
    && chown -R "${NAGIOS_USER}:${NAGIOS_GROUP}" /var/lib/adagios/ \
    && echo "Defaults:nagios    !requiretty \n\
nagios ALL = (root) NOPASSWD: /etc/init.d/nagios * \n\
nagios ALL = (root) NOPASSWD: ${NAGIOS_HOME}/bin/nagios -v *\n" > /etc/sudoers.d/nagios \
    && cd /tmp \
    && rm -rf /tmp/adagios

RUN cd /tmp \
    && curl http://mathias-kettner.com/download/mk-livestatus-1.2.8p12.tar.gz -o mk-livestatus.tar.gz \
    && tar zxf mk-livestatus.tar.gz \
    && rm -f mk-livestatus.tar.gz \
    && mv mk-livestatus* mk-livestatus \
    && cd mk-livestatus \
    && ./configure --with-nagios4 \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/mk-livestatus

ADD files/start.sh /bin/container-start
ADD etc/sv/apache/run /etc/sv/apache/run
ADD etc/sv/nagios/run /etc/sv/nagios/run
ADD etc/sv/postfix/run /etc/sv/postfix/run

RUN rm -rf /etc/sv/getty-5 \
    && ln -s /etc/sv/* /etc/service \
    && cp /etc/services /var/spool/postfix/etc/ \
    && chown -R "${NAGIOS_USER}:${NAGIOS_GROUP}" /opt/nrdp "${NAGIOS_HOME}" \
    && ln -sf "/usr/share/zoneinfo/${NAGIOS_TIMEZONE}" /etc/localtime

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80

CMD [ "/bin/container-start" ]
