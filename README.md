# docker-nagios (Last version 4.2.1) 

[![](https://avatars0.githubusercontent.com/u/5666660?v=3&s=200)](https://www.nagios.org/ "Nagios")

### Last update: 13/10/2016. Add NCPA (linux & windows agent) support

Build Status: 
[![Build Status](https://api.travis-ci.org/ethnchao/docker-nagios.svg?branch=master)](https://travis-ci.org/ethnchao/docker-nagios)  [![](https://images.microbadger.com/badges/image/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own image badge on microbadger.com")  [![](https://images.microbadger.com/badges/version/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own version badge on microbadger.com")

### Nagios
Nagios is a host/service/network monitoring program written in C and released under the GNU General Public License, version 2. CGI programs are included to allow you to view the current status, history, etc via a web interface if you so desire.

### Docker

[Docker](https://www.docker.com/) allows you to package an application with all of its dependencies into a standardized unit for software development.

More information : 

* [What is docker](https://www.docker.com/what-docker)
* [How to Create a Docker Business Case](https://www.brianchristner.io/how-to-create-a-docker-business-case/)

### Get to the point

This repository provides the *LATEST STABLE* version of the Nagios Docker & Docker-Compose file. 

Component & Version:

* [`phusion/baseimage:latest`](https://hub.docker.com/r/phusion/baseimage/)
* [`Nagios Core 4.2.1`](https://github.com/NagiosEnterprises/nagioscore.git)
* [`Nagios Plugins 2.1.3`](https://github.com/nagios-plugins/nagios-plugins.git)
* [`Nagiosgraph 1.5.2`](http://git.code.sf.net/p/nagiosgraph/git) Sorry PNPNagios, I much prefrere Nagiosgraph
* [`NDOUtils 2.1.1`](https://github.com/NagiosEnterprises/ndoutils.git) Allow you save all the data to MySQL database
* [`MySQL 5.6`](https://hub.docker.com/_/mysql/)
* [`PyNag master`](https://github.com/pynag/pynag.git) A command line tool for managing nagios configuration and provides a framework to write plugins
* [`Okconfig master`](https://github.com/opinkerfi/okconfig.git) A robust template mechanism for Nagios configuration files, required for Adagios
* [`MK-livestatus 1.2.8p12`](http://mathias-kettner.com/) Broker module for nagios for high performance status information, required for Adagios
* [`Adagios 1.6.3-1`](https://github.com/opinkerfi/adagios.git) A web based Nagios configuration interface built to be simple and intuitive in design, exposing less of the clutter under the hood of nagios. Adagios is more lighter UI than Check_MK, based on mod_wsgi, so it cannot be used with Check_MK (Check_MK based on mod_python, already deprecated and conflict with mod_wsgi)
* [`NRDP master`](https://github.com/NagiosEnterprises/nrdp.git) A flexible data transport mechanism and processor for Nagios. It uses standard ports protocols (HTTP(S) and XML for api response) and can be implemented as **a replacement for NSCA**. Used with NCPA, oh, those names(nrpe,ncpa,nrds,nrdp,nsti)...
* [`NCPA 1.8.1`](https://github.com/NagiosEnterprises/ncpa) The Nagios Cross-Platform Agent; a single monitoring agent that installs on all major operating systems. NCPA with a built-in web GUI, we will use ncpa for passive checks.
* [`JR-Nagios-Plugins`](https://github.com/JasonRivers/nagios-plugins)
* [`WL-Nagios-Plugins`](https://github.com/willixix/WL-NagiosPlugins)
* [`JE-Nagios-Plugins`](https://github.com/justintime/nagios-plugins)

### Configurations
Nagios configuration lives in /opt/nagios/etc
NagiosGraph configuration lives in /opt/nagiosgraph/etc
Adagios configuration lives in /etc/adagios
Okconfig configuration lives in /etc/okconfig.conf
NRDP configuration lives in /opt/nrdp

### Plugin

Nagios plugin lives in /usr/local/nagios/libexec.

Mount your own plugin at /data/plugin

### Docker Compose

Use `docker-compose up` to up containers, at the very first time start, will write database table structure to MySQL.

#### Network:
[```4.2.1 (latest)```](https://github.com/ethnchao/Docker-Nagios/blob/master/Docker-Compose/docker-compose.yml)

#### Database configuration

* `MYSQL_USER:` nagios
* `MYSQL_PASSWORD:` your_mysql_password
* `MYSQL_ADDRESS:` mysql
* `MYSQL_DATABASE:` nagios

For best results your Nagios image should have access to both IPv4 & IPv6 networks 

#### Nagios & Adagios web login

Addresses:

```sh
# Nagios
http://nagios-server-address/

# Adagios
http://nagios-server-address/adagios

# NRDP
http://nagios-server-address/nrdp

# NCPA (Client Side)
https://ncpa-agent-address:5693/
```

Default authorization:

* `username:` nagiosadmin
* `password:` nagios

Alternative authorization, by adding some environment variables to docker-compose.yml, such as:

````yml
services:
  nagios:
    # other settings section
    environment:
      - MYSQL_USER=nagios
      - MYSQL_PASSWORD=nagios
      - MYSQL_ADDRESS=mysql
      - MYSQL_DATABASE=nagios
      - NAGIOSADMIN_USER=your_login_user
      - NAGIOSADMIN_PASS=your_login_pass
````

## Packages Dependency

Dockerfile中为了缩小镜像大小，在同一个`RUN`命令中使用apt和pip安装了很多依赖包，每个软件只依赖其中的部分包，这里说明下依赖包的对应关系，对应关系的来源多数是软件的官方文档，部分为了解决一些问题而补充的包。

Nagioscore 需要以下依赖：
(这里的软件名称较官方文档要少些，因为部分软件有依赖关系，无需写出)

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

Nagios 其他功能：

~~~~
bsd-mailx
~~~~

Nagios-Plugin编译安装时需要以下依赖：

~~~~
m4 \
gettext \
automake \
autoconf
~~~~

Nagios-Plugins各插件运行时可能会使用的依赖，非必须：

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

软件安装相关：`python-pip`、 `git`、 `python-dev`

系统服务：`runit`、 `sudo`

graphite

~~~~
apache2 \
apache2-utils \
build-essential \
libcairo2-dev \
libffi-dev \
libapache2-mod-wsgi
~~~~

graphios

~~~~
sudo
~~~~

ndoutils

~~~~
mysql-client \
libmysql++-dev \
libmysqlclient-dev
~~~~

Nrpe

~~~~
build-essential
~~~~