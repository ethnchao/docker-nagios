#!/bin/bash
# Please attention: this script will install ncpa agent

INSTALL_DIR=`dirname $0`
NAGIOS_SERVER=$1
NCPA_DIR=/usr/local/ncpa
NCPA_USER=nagios
NCPA_GROUP=nagcmd
EPEL_MIRROR="mirrors.aliyun.com"

if [ -z $NAGIOS_SERVER ] ; then
	NAGIOS_SERVER=`echo $SSH_CLIENT | awk '{ print $1 }'`
	echo "IP Address of Nagios server not specified. Using $NAGIOS_SERVER"
fi

get_os_release() {
    # Run in a sub-shell so we do not overwrite any environment variables
    (
        . /etc/os-release
        echo ${ID}${VERSION_ID}
    )
}

fatal_error() {
	local message
	message="$1"
	echo "${message}" 1>&2
	exit 1
}

# Use /etc/os-release, see http://0pointer.de/blog/projects/os-release
if [ -f "/etc/os-release" ]; then
	DISTRO=$(get_os_release)
else
	grep -q "release 7" /etc/redhat-release 2>/dev/null && DISTRO=rhel7
	grep -q "release 6" /etc/redhat-release 2>/dev/null && DISTRO=rhel6
	grep -q "release 5" /etc/redhat-release 2>/dev/null && DISTRO=rhel5
	grep -q "openSUSE 11" /etc/SuSE-release 2>/dev/null && DISTRO=opensuse11
	test -f /etc/debian_version && DISTRO=debian
fi

link_plugins() {
    ln -sf "${NAGIOS_PLUGINDIR}"/* "${NCPA_DIR}/plugins/" \
    && chmod +x "${NCPA_DIR}/plugins"/*
}

config_ncpa() {
    cp -fb "${NCPA_DIR}/etc/ncpa.cfg" "${NCPA_DIR}/etc/ncpacfg.bak"
    cat << EOF > "${NCPA_DIR}/etc/ncpa.cfg"
[listener]
uid = nagios
certificate = adhoc
loglevel = info
ip = 0.0.0.0
gid = nagcmd
logfile = var/ncpa_listener.log
port = 5693
pidfile = var/ncpa_listener.pid
# Available versions: PROTOCOL SSLv2, SSLv3, TLSv1
ssl_version = TLSv1

[passive]
uid = nagios
handlers = nrdp
loglevel = info
gid = nagcmd
sleep = 300
logfile = var/ncpa_passive.log
pidfile = var/ncpa_passive.pid

[nrdp]
token = culaio239ncgklak
hostname = ${HOSTNAME}
parent = http://${NAGIOS_SERVER}/nrdp/

[nrds]
URL = None
CONFIG_VERSION = None
TOKEN = None
CONFIG_NAME = None
CONFIG_OS = None

[api]
community_string = mfasjlk1asjd7flj3lytoken

[plugin directives]
plugin_path = plugins/
.sh = /bin/sh $plugin_name $plugin_args
.ps1 = powershell -ExecutionPolicy Bypass -File $plugin_name $plugin_args
.vbs = cscript $plugin_name $plugin_args //NoLogo

[passive checks]
%HOSTNAME%|CPU-Usage = /cpu/percent --warning 20 --critical 30
%HOSTNAME%|Swap-Usage = /memory/swap/percent --warning 40 --critical 80
%HOSTNAME%|Memory-Usage = /memory/virtual/percent --warning 60 --critical 80

EOF
    cat << EOF > "${NCPA_DIR}/etc/ncpa.cfg.d/passive.cfg"
[passive checks]
%HOSTNAME%|Users = /user/count --warning 5 --critical 9
%HOSTNAME%|Processes = /processes --warning 250 --critical 300
%HOSTNAME%|Partition-Usage = /agent/plugin/check_disk/-w/15%/-c/10%/-A
%HOSTNAME%|Load-Average = /agent/plugin/check_load/-w/15,10,5/-c/30,25,20
%HOSTNAME%|Zombie-Process = /agent/plugin/check_procs/-w/5/-c/10/-s/Z

EOF
    /etc/init.d/ncpa_listener restart \
    && /etc/init.d/ncpa_passive restart \
    && chown -R "${NCPA_USER}:${NCPA_GROUP}" "${NCPA_DIR}"
}

install_debian() {
    DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.amd64.deb"
    if [[ $HOSTTYPE == "i686" ]]; then
        DISTRO_PACKAGE=$(echo $DISTRO_PACKAGE | sed 's/amd64/i386/')
    fi
    echo "Installing nagios-plugins & ncpa" \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y nagios-plugins \
    && cd /tmp \
    && curl -LSf "$DISTRO_PACKAGE" -o ncpa.deb \
    && dpkg -i ncpa.deb \
    && rm -f ncpa.deb \
    && link_plugins \
    && config_ncpa \
    && echo "Install Complete" \
    && exit 0
}

install_opensuse() {
    DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.os.x86_64.rpm"
    for version in '11' '12' '13'
    do
        echo "$DISTRO" | grep -q "$version" 2>/dev/null && DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-1.8.1-1.os${version}.x86_64.rpm"
    done
    if [ $HOSTTYPE == "i686" ]; then
        DISTRO_PACKAGE=$(echo $DISTRO_PACKAGE | sed 's/x86_64/i586/')
    fi
    echo "Installing nagios-plugins & ncpa" \
	&& rpm -q nagios-plugins || zypper install -n nagios-plugins \
    && rpm -q ncpa || zypper -n install "$DISTRO_PACKAGE" \
    && link_plugins \
    && config_ncpa \
    && echo "Install Complete" \
    && exit 0
}

install_epel() {
    if [[ $DISTRO =~ fedora ]] ; then
        EPEL_MIRROR="download.fedoraproject.org/pub"
    fi
    yum -y install epel-release \
    && cp -fb /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epelrepo.bak \
    && sed -i "s,#baseurl=http://download.fedoraproject.org/pub,baseurl=http://${EPEL_MIRROR},;s,mirrorlist=,#mirrorlist=," /etc/yum.repos.d/epel.repo
}

install_rhel() {
    if [[ $DISTRO == rhel5 || $DISTRO == centos5 ]] ; then
        rpm -Uvh http://repo.nagios.com/nagios/5/nagios-repo-5-2.el5.noarch.rpm
        DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.el5.x86_64.rpm"
    elif [[ $DISTRO == rhel6 || $DISTRO == centos6 ]]; then
        rpm -Uvh http://repo.nagios.com/nagios/6/nagios-repo-6-2.el6.noarch.rpm
        DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.el6.x86_64.rpm"
    elif [[ $DISTRO == rhel7 || $DISTRO == centos7 ]]; then
        rpm -Uvh http://repo.nagios.com/nagios/7/nagios-repo-7-2.el7.noarch.rpm
        DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.el7.x86_64.rpm"
    else
        rpm -Uvh http://repo.nagios.com/nagios/6/nagios-repo-6-2.el6.noarch.rpm
        DISTRO_PACKAGE="https://assets.nagios.com/downloads/ncpa/ncpa-2.0.3.el6.x86_64.rpm"
    fi
    if [[ $HOSTTYPE == "i686" ]]; then
        if [[ "$DISTRO" =~ fedora ]]; then
            DISTRO_PACKAGE=$(echo $DISTRO_PACKAGE | sed 's/x86_64/i686/')
        else
            DISTRO_PACKAGE=$(echo $DISTRO_PACKAGE | sed 's/x86_64/i386/')
        fi
    fi
    echo "Installing nagios-plugins" \
    && install_epel \
    && rpm -q nagios-plugins-load || yum install -y nagios-plugins-load || fatal_error "Failed to yum install nagios-plugins-load package" \
    && rpm -q nagios-plugins-disk || yum install -y nagios-plugins-disk || fatal_error "Failed to yum install nagios-plugins-disk package" \
    && rpm -q nagios-plugins-procs || yum install -y nagios-plugins-procs || fatal_error "Failed to yum install nagios-plugins-procs package" \
    && echo "Installing ncpa" \
    && yum install ncpa -y \
    && link_plugins \
    && config_ncpa \
    && echo "Install Complete" \
    && exit 0
}

if [[ "$DISTRO" =~ "opensuse" ]]; then
	NAGIOS_PLUGINDIR=/usr/lib64/nagios/plugins/
	if [ $HOSTTYPE == "i686" ]; then
		NAGIOS_PLUGINDIR=`echo $NAGIOS_PLUGINDIR | sed 's/lib64/lib/'`
	fi
	install_opensuse;
elif [[ "$DISTRO" =~ "fedora" ]]; then
	NAGIOS_PLUGINDIR=/usr/lib64/nagios/plugins/
	if [ $HOSTTYPE == "i686" ]; then
		NAGIOS_PLUGINDIR=`echo $NAGIOS_PLUGINDIR | sed 's/lib64/lib/'`
	fi
	install_rhel;
elif [[ "$DISTRO" =~ rhel[567] ]]; then
	NAGIOS_PLUGINDIR=/usr/lib64/nagios/plugins/
	if [ $HOSTTYPE == "i686" ]; then
		NAGIOS_PLUGINDIR=`echo $NAGIOS_PLUGINDIR | sed 's/lib64/lib/'`
	fi
	install_rhel;
elif [[ "$DISTRO" =~ centos[567] ]]; then
    NAGIOS_PLUGINDIR=/usr/lib64/nagios/plugins/
    if [ $HOSTTYPE == "i686" ]; then
        NAGIOS_PLUGINDIR=`echo $NAGIOS_PLUGINDIR | sed 's/lib64/lib/'`
    fi
    install_rhel;
elif [[ "$DISTRO" =~ "debian" ]]; then
	NAGIOS_PLUGINDIR=/usr/lib/nagios/plugins/
	install_debian
elif [[ "$DISTRO" =~ "ubuntu" ]]; then
	NAGIOS_PLUGINDIR=/usr/lib/nagios/plugins/
	install_debian
else
	echo could not detect distribution. Exiting...
	exit 1
fi
