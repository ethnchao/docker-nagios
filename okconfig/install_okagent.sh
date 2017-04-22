#!/bin/bash
# Please attention: this script will install ncpa agent

INSTALL_DIR=`dirname $0`
NCPA_DIR=/usr/local/ncpa
NCPA_USER=nagios
NCPA_GROUP=nagios


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

config_ncpa() {
    cd "${NCPA_DIR}/etc/" || exit 1
    cp -f ncpa.cfg.sample ncpa.cfg
    sed -i "s/community_string.*/community_string = NCPA_TOKEN/;\
        s/^handlers.*/handlers = nrdp/;\
        s,^parent.*,parent = NRDP_URL,;\
        s/^token.*/token = NRDP_TOKEN/;\
        s/^hostname.*/hostname = ${HOSTNAME}/" ncpa.cfg
    cd ncpa.cfg.d || exit 1
    cat << EOF >> nrdp.cfg
[passive checks]
%HOSTNAME%|__HOST__ = system/agent_version
%HOSTNAME%|CPU Usage = cpu/percent --warning 60 --critical 80 --aggregate avg
%HOSTNAME%|Swap Usage = memory/swap --warning 60 --critical 80 --units Gi
%HOSTNAME%|Memory Usage = memory/virtual --warning 80 --critical 90 --units Gi
%HOSTNAME%|Process Count = processes --warning 300 --critical 400
%HOSTNAME%|Root Partition Usage = disk/logical/|/used_percent --warning 85 --critical 90 --units Gi
%HOSTNAME%|Traffic Recv = interface/eth0/bytes_recv --warning 80 --critical 90 --units Mi --delta 1
%HOSTNAME%|Traffic Sent = interface/eth0/bytes_sent --warning 80 --critical 90 --units Mi --delta 1

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
    echo "Installing ncpa" \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && cd /tmp \
    && curl -LSf "$DISTRO_PACKAGE" -o ncpa.deb \
    && dpkg -i ncpa.deb \
    && rm -f ncpa.deb \
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
    echo "Installing ncpa" \
    && rpm -q ncpa || zypper -n install "$DISTRO_PACKAGE" \
    && config_ncpa \
    && echo "Install Complete" \
    && exit 0
}


install_rhel() {
    if [[ $DISTRO == rhel5 || $DISTRO == centos5 ]] ; then
        rpm -Uvh http://repo.nagios.com/nagios/5/nagios-repo-5-2.el5.noarch.rpm
    elif [[ $DISTRO == rhel6 || $DISTRO == centos6 ]]; then
        rpm -Uvh http://repo.nagios.com/nagios/6/nagios-repo-6-2.el6.noarch.rpm
    elif [[ $DISTRO == rhel7 || $DISTRO == centos7 ]]; then
        rpm -Uvh http://repo.nagios.com/nagios/7/nagios-repo-7-2.el7.noarch.rpm
    else
        rpm -Uvh http://repo.nagios.com/nagios/6/nagios-repo-6-2.el6.noarch.rpm
    fi
    echo "Installing ncpa" \
    && yum install -y ncpa \
    && config_ncpa \
    && echo "Install Complete" \
    && exit 0
}

if [[ "$DISTRO" =~ "opensuse" ]]; then
	install_opensuse;
elif [[ "$DISTRO" =~ "fedora" ]]; then
	install_rhel;
elif [[ "$DISTRO" =~ rhel[567] ]]; then
	install_rhel;
elif [[ "$DISTRO" =~ centos[567] ]]; then
    install_rhel;
elif [[ "$DISTRO" =~ "debian" ]]; then
	install_debian
elif [[ "$DISTRO" =~ "ubuntu" ]]; then
	install_debian
else
	echo could not detect distribution. Exiting...
	exit 1
fi
