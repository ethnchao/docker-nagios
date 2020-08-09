[![Build Status](https://api.travis-ci.org/ethnchao/docker-nagios.svg?branch=master)](https://travis-ci.org/ethnchao/docker-nagios)  [![](https://images.microbadger.com/badges/image/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own image badge on microbadger.com")  [![](https://images.microbadger.com/badges/version/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own version badge on microbadger.com")

# [docker-nagios](#docker-nagios)
  - [Run](#run)
  - [Build from source](#build-from-source)
  - [Configuration file location](#configuration-file-location)
  - [Packages Dependency](#packages-dependency)

[![](https://avatars0.githubusercontent.com/u/5666660?v=3&s=200)](https://www.nagios.org/ "Nagios")

Docker-Nagios provide Nagios service running on the docker container and a series of solution for Nagios: Adagios for Web Based Nagios Configuration, Grafana for monitor metric & dashboards, Ndoutils for transfer monitor data to MySQL Database, NCPA&NRDP for nagios passive checks.

As the docker-image contains a large number of software, the following describes the various components of the version and the basic information:

* [`phusion/baseimage:latest`](https://hub.docker.com/r/phusion/baseimage/) Docker baseimage
* [`Nagios Core 4.4.6`](https://github.com/NagiosEnterprises/nagioscore) Nagios core - the community version
* [`Nagios Plugins 2.2.1`](https://github.com/nagios-plugins/nagios-plugins) Nagios plugins
* [`Graphios 2.0.3`](https://pypi.python.org/pypi/graphios) Send Nagios spool data to graphite
* [`Graphite 1.1.3`](https://github.com/graphite-project/graphite-web/) Grafana's datasource
* [`Grafana 5.1.3`](https://grafana.com/) The tool for beautiful monitoring and metric analytics & dashboards for Graphite, InfluxDB & Prometheus & More
* [`NDOUtils 2.1.3`](https://github.com/NagiosEnterprises/ndoutils) Allow you save all the data to MySQL database
* [`PyNag 0.9.1-1`](https://github.com/pynag/pynag/) A command line tool for managing nagios configuration and provides a framework to write plugins
* [`Okconfig 1.3.2-1`](https://github.com/opinkerfi/okconfig) Provides a templated Nagios configuration, Adagios can use okconfig to quickly and easily configure Nagios
* [`MK-livestatus 1.2.8p20`](http://mathias-kettner.com/) MK-livestatus can get Nagios status information, loaded as broker module into Nagios configuration, and Adagios uses mk-livestatus to get status information
* [`Adagios 1.6.3-2`](https://github.com/opinkerfi/adagios.git) A web based Nagios configuration interface built to be simple and intuitive in design, exposing less of the clutter under the hood of nagios. Adagios is more lighter UI than Check_MK, based on mod_wsgi(so it cannot be used with Check_MK, Check_MK based on mod_python, already deprecated and conflict with mod_wsgi)
* [`NRDP 1.5.2`](https://github.com/NagiosEnterprises/nrdp) A flexible data transport mechanism and processor for Nagios. It uses standard ports protocols (HTTP(S) and XML for api response) and can be implemented as a replacement for NSCA. Used with NCPA, omg, those bloody names(nrpe,ncpa,nrds,nrdp,nsti...).
* [`NCPA 2.1.3`](https://github.com/NagiosEnterprises/ncpa) The Nagios Cross-Platform Agent; a single monitoring agent that installs on all major operating systems. NCPA with a built-in web GUI, we will use ncpa for passive checks.

## Quick start

Ad-hoc run nagios in docker.

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 -d ethnchao/nagios
~~~~
Accessing nagios and Adagios:

- Nagios http://127.0.0.1/
    
    - `User`: `nagiosadmin`
    - `Password`: `nagios`

- Adagios http://127.0.0.1/adagios
- NRDP http://127.0.0.1/nrdp
- Grafana http://127.0.0.1:3000/
    
    - `User`: `admin`
    - `Password`: `admin`

- NCPA (Client) https://ncpa-agent-address:5693/

If you need to use a custom login user name and password, you can run the container with the environment variables: `NAGIOSADMIN_USER` and` NAGIOSADMIN_PASS`.

~~~~shell
$ docker run --name nagios -p 9001:80 -p 3000:3000 \
  -e NAGIOSADMIN_USER=john \
  -e NAGIOSADMIN_PASS=secret_code \
  -d ethnchao/nagios
~~~~

## Run with docker-compose

We recommend that you use docker-compose to run Nagios with MySQL containers, check this [docker-compose.yml][72bb6132] 。

## Setting advertise address

In some features, such as using the Adagios - Okconfig - Install Agent, you need to configure the NRDP server address in the remote client. The IP + port of the address is also the address of the Nagios server, but when you use the Docker to run the container, Nagios Do not know what their own server address, so when we run the container, passing the server address to it.

~~~~shell
$ docker run --name nagios -p 9001:80 -p 3000:3000 -d ethnchao/nagios --server-url http://172.17.242.190:9001
~~~~

## Store data files in local

You can choose to mount additional configuration files, plugin, okconfig-example to the container, such as the additional configuration file on /data/conf, plugin on /data/plugin, okconfig-example on /data/example.

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -v /data/conf:/usr/local/nagios/etc/mount \
  -v /data/plugin:/data/plugin \
  -v /data/example:/data/example \
  -d ethnchao/nagios
~~~~

## Store monitoring data in MySQL

If you need to store the monitoring information in MySQL database, you need to enable Ndoutils, which there are two cases：

1. If you already executed the Ndoutils database initialization script in the MySQL database, then run this container with option: `--enable-ndo`.

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -e MYSQL_USER=nagios -e MYSQL_PASSWORD=nagios \
  -e MYSQL_ADDRESS=172.17.242.178 -e MYSQL_DATABASE=nagios \
  -d ethnchao/nagios --enable-ndo
~~~~

2. If you did not execute the Ndoutils initalization script in the MySQL database, you can run this container with option: `--enable-ndo --create-db`

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -e MYSQL_USER=nagios -e MYSQL_PASSWORD=nagios \
  -e MYSQL_ADDRESS=172.17.242.178 -e MYSQL_DATABASE=nagios \
  -d ethnchao/nagios --enable-ndo --create-db
~~~~

## Setting E-Mail

By setting heirloom-mailx, you'll be able to send email with s-nail command in nagios/adagios interface.

1. Set /etc/s-nail.rc, adding these line:

~~~shell
set from=your-email@demo.com
set smtp=smtps://demo.com:465
set smtp-auth-user=your-email@demo.com
set smtp-auth-password=your-email-password
set smtp-auth=login
~~~

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.qq.com'
EMAIL_PORT = 25
EMAIL_HOST_USER = '695991913@qq.com'
EMAIL_HOST_PASSWORD = 'sramookfxzaubega'
EMAIL_SUBJECT_PREFIX = u'django'
EMAIL_USE_TLS = True
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER

SERVER_EMAIL = '695991913@qq.com'


## Build from source

Build the Nagios image from github source.

~~~~shell
$ docker build -t nagios .
~~~~

## Configuration file location

Software | Config file location
---------|---------------------------
Nagios   | /usr/local/nagios/etc
Adagios  | /etc/adagios
Okconfig | /etc/okconfig.conf
NRDP     | /usr/local/nrdp
Graphios | /etc/graphios/graphios.cfg
Graphite | /opt/graphite/conf/

## Packages Dependency

To reduce the size of the docker-image, we use the apt and pip to install a lot of packages in the same `RUN` instruction, each software(like adagios/nagios-plugins) only depends on some of the packages, the following records the software depends on which packages, dependencies all come from official documents of the software, some from the actual operation of the adjustment.

Nagioscore needs the following dependencies:
(The software list is less than the official documents, some of the official website of the software has been dependent on each other, no need to write)

~~~~
apache2 \
apache2-utils \
autoconf \
bc \
build-essential \
dc \
gawk \
gettext \
gperf \
libapache2-mod-php \
libgd2-xpm-dev \
libmcrypt-dev \
libssl-dev \
unzip
~~~~

Nagios command: notify-by-mail

~~~~
bsd-mailx
~~~~

The following dependencies are required for the Nagios-Plugin compilation installation:

~~~~
m4 \
gettext \
automake \
autoconf
~~~~

The dependencies that may be used when the Nagios plugin is running：

~~~~
iputils-ping \
fping \
postfix \
libnet-snmp-perl \
smbclient \
snmp \
snmpd \
snmp-mibs-downloader \
netcat
~~~~

Software installation related：

`python-pip`、 `git`、 `python-dev`

System services：

`runit`、 `sudo`、 `parallel`

The following dependencies are required for the Graphite installation:

~~~~
apache2 \
apache2-utils \
build-essential \
libcairo2-dev \
libffi-dev \
libapache2-mod-wsgi
~~~~

The following dependencies are required for the Graphios installation:

~~~~
sudo
~~~~

The following dependencies are required for the Ndoutils installation:

~~~~
mysql-client \
libmysql++-dev \
libmysqlclient-dev
~~~~

The following dependencies are required for the Nrpe installation:

~~~~
build-essential
~~~~

The following dependencies are required when the NRDP is running:

~~~~
php7.0-xml
~~~~

[72bb6132]: https://github.com/ethnchao/docker-nagios/blob/master/docker-compose.yml "docker-compose.yml"
