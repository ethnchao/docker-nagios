[![Build Status](https://api.travis-ci.org/ethnchao/docker-nagios.svg?branch=master)](https://travis-ci.org/ethnchao/docker-nagios)  [![](https://images.microbadger.com/badges/image/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own image badge on microbadger.com")  [![](https://images.microbadger.com/badges/version/ethnchao/nagios.svg)](https://microbadger.com/images/ethnchao/nagios "Get your own version badge on microbadger.com")

# docker-nagios

[![](https://avatars0.githubusercontent.com/u/5666660?v=3&s=200)](https://www.nagios.org/ "Nagios")

Docker-Nagios 提供运行于 Docker 容器的 Nagios 服务和一系列有关 Nagios 服务的解决方案：
Adagios 用于在网页端处理各类配置和总览状态查看，Grafana 用于编辑和显示仪表盘、折线图、Dashboard等内容，Ndoutils 用于转移监控数据到MySQL数据库，以便于其他系统进行二次开发使用。

由于本docker-image包含软件众多，下面介绍下各组件的版本和基本介绍信息：

* [`phusion/baseimage:latest`](https://hub.docker.com/r/phusion/baseimage/) Docker baseimage
* [`Nagios Core 4.3.4`](https://github.com/NagiosEnterprises/nagioscore) Nagios core - 社区版本
* [`Nagios Plugins 2.2.1`](https://github.com/nagios-plugins/nagios-plugins) Nagios plugins
* [`Graphios 2.0.3`](https://pypi.python.org/pypi/graphios) 发送Nagios spool数据给Graphite
* [`Graphite 1.1.3`](https://github.com/graphite-project/graphite-web/) Grafana 的数据源
* [`Grafana 5.1.3`](https://grafana.com/) 用于Graphite，InfluxDB和Prometheus等监控的度量分析和仪表盘的工具，图形界面很赞
* [`NDOUtils 2.1.3`](https://github.com/NagiosEnterprises/ndoutils) 允许你把Nagios的监控数据存储在MySQL 数据库
* [`PyNag 0.9.1-1`](https://github.com/pynag/pynag/) 一个命令行工具，用于管理Nagios的配置，并提供了框架用于编写插件
* [`Okconfig 1.3.2-1`](https://github.com/opinkerfi/okconfig) 提供了模板化的Nagios配置方式，Adagios可使用okconfig来方便快速的配置Nagios
* [`MK-livestatus 1.2.8p20`](http://mathias-kettner.com/) MK-livestatus可以获取Nagios状态信息，作为broker module 加载到 Nagios配置中，, Adagios使用mk-livestatus来获取状态信息
* [`Adagios 1.6.3-2`](https://github.com/opinkerfi/adagios.git) 基于Web 的Nagios配置界面，简单、直观的设计，覆盖了Nagios杂乱无章的UI界面。Adagios在UI上 比Check_MK更加轻量，基于mod_wsgi（所以无法与Check_MK一起使用，Check_MK基于mod_python，已经过时并且与mod_wsgi冲突）
* [`NRDP 1.5.2`](https://github.com/NagiosEnterprises/nrdp) 用于Nagios的一个可扩展的数据传输方式与处理单元。使用标准端口协议（HTTP(S) 和 XML 用于api响应）并用于替代NSCA。与NCPA一同使用，天哪，这些该死的名字（nrpe,ncpa,nrds,nrdp,nsti...）。
* [`NCPA 2.1.3`](https://github.com/NagiosEnterprises/ncpa) Nagios跨平台的Agent，适用于所有主流操作系统，NCPA自带Web 界面，我们同时将使用NCPA用于被动监控。

从 DockerHub 获取 nagios

~~~~shell
$ docker pull ethnchao/nagios
~~~~

从github 源码 Build Nagios 镜像

~~~~shell
$ docker build -t nagios .
~~~~

使用docker运行Nagios

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 -d ethnchao/nagios
~~~~

访问地址：

~~~~shell
# Nagios
http://127.0.0.1/

# Adagios
http://127.0.0.1/adagios

# NRDP
http://127.0.0.1/nrdp

# Grafana
http://127.0.0.1:3000/

# NCPA (客户端)
https://ncpa-agent-address:5693/
~~~~

Nagios 网页登录:

> `用户名`: `nagiosadmin`
>
> `密码`: `nagios`

Grafana 网页登录:

> `用户名`: `admin`
>
> `密码`: `admin`

如果需要使用自定义的登录用户名和密码，可以在运行容器时，传入环境变量：`NAGIOSADMIN_USER` 和 `NAGIOSADMIN_PASS`。

~~~~shell
$ docker run --name nagios -p 9001:80 -p 3000:3000 \
  -e NAGIOSADMIN_USER=john \
  -e NAGIOSADMIN_PASS=secret_code \
  -d ethnchao/nagios
~~~~

在某些功能中，例如使用Adagios - Install Agent中，需要在远程客户端中配置NRDP服务端的地址，该地址的IP + 端口也同时是Nagios服务的地址，但是由于使用Docker运行容器时，Nagios并不知道自身的服务端地址是什么，所以需要在运行容器时，手动配置服务端地址信息。

~~~~shell
$ docker run --name nagios -p 9001:80 -p 3000:3000 -d ethnchao/nagios --server-url http://172.17.242.190:9001
~~~~

你可以选择挂载额外的配置文件、plugin、okconfig-example到容器中，例如把额外的配置文件放在 /data/conf ，plugin 放在 /data/plugin，okconfig-example 放在 /data/example.

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -v /data/conf:/usr/local/nagios/etc/mount \
  -v /data/plugin:/data/plugin \
  -v /data/example:/data/example \
  -d ethnchao/nagios
~~~~

如果需要把监控信息存储到MySQL数据库，则需要启用Ndoutils，在这里有两种情况：


1. 如果你已经在MySQL 数据库执行了Ndoutils 数据库初始化脚本，则运行container时附带这个选项：`--enable-ndo`。

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -e MYSQL_USER=nagios -e MYSQL_PASSWORD=nagios \
  -e MYSQL_ADDRESS=172.17.242.178 -e MYSQL_DATABASE=nagios \
  -d ethnchao/nagios --enable-ndo
~~~~

2. 如果你没有在MySQL数据库执行过Ndoutils数据库初始化脚本，则运行container是附带这个选项：`--enable-ndo --create-db`

~~~~shell
$ docker run --name nagios -p 80:80 -p 3000:3000 \
  -e MYSQL_USER=nagios -e MYSQL_PASSWORD=nagios \
  -e MYSQL_ADDRESS=172.17.242.178 -e MYSQL_DATABASE=nagios \
  -d ethnchao/nagios --enable-ndo --create-db
~~~~

最终我们推荐使用docker-compose运行Nagios和MySQL容器，查看这个 [docker-compose.yml][72bb6132] 。

## 配置文件位置

Software | Config file location
---------|---------------------------
Nagios   | /usr/local/nagios/etc
Adagios  | /etc/adagios
Okconfig | /etc/okconfig.conf
NRDP     | /usr/local/nrdp
Graphios | /etc/graphios/graphios.cfg
Graphite | /opt/graphite/conf/

## 包的依赖关系

为了缩小 docker-image 大小，我们在同一个`RUN`指令中使用工具： apt 和 pip 安装了很多包，每个软件（例如adagios，nagios-plugins）只依赖其中的部分包，下面记录下各软件依赖哪些包，依赖关系的来源多数是软件的官方文档，有些来源于实际运行的调整。

Nagioscore 需要以下依赖：
(这里的软件列表较官方文档要少些，因为部分软件有依赖关系，无需写出)

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

在Nagios-Plugin编译安装时需要以下依赖：

~~~~
m4 \
gettext \
automake \
autoconf
~~~~

Nagios Plugins 运行时可能会使用的依赖：

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

软件安装相关：

`python-pip`、 `git`、 `python-dev`

系统服务：

`runit`、 `sudo`、 `parallel`

Graphite安装时所需依赖：

~~~~
apache2 \
apache2-utils \
build-essential \
libcairo2-dev \
libffi-dev \
libapache2-mod-wsgi
~~~~

Graphios安装时所需依赖：

~~~~
sudo
~~~~

Ndoutils安装时所需依赖：

~~~~
mysql-client \
libmysql++-dev \
libmysqlclient-dev
~~~~

Nrpe安装时所需依赖：

~~~~
build-essential
~~~~

NRDP运行时所需依赖：

~~~~
php7.0-xml
~~~~

[72bb6132]: https://github.com/ethnchao/docker-nagios/blob/master/docker-compose.yml "docker-compose.yml"
