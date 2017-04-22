#!/bin/bash
set -e

CREATE_DB=0
SERVER_URL="http://your-nagios-address"
MYSQL_CREATEDB_SQL="${NAGIOS_HOME}/share/mysql-createdb.sql"


setup_config() {
    NRDP_URL="${SERVER_URL}/nrdp/"
    cd /usr/share/okconfig/client || exit 1
    cp -f linux/install_okagent.sh.example linux/install_okagent.sh
    sed -i -e "s/NCPA_TOKEN/${NCPA_TOKEN}/" \
        -e "s/NRDP_TOKEN/${NRDP_TOKEN}/" \
        -e "s,NRDP_URL,${NRDP_URL}," linux/install_okagent.sh
    cp -f windows/install.bat.example windows/ncpa/install.bat
    sed -i -e "s/NCPA_TOKEN/${NCPA_TOKEN}/" \
        -e "s/NRDP_TOKEN/${NRDP_TOKEN}/" \
        -e "s,NRDP_URL,${NRDP_URL}," windows/ncpa/install.bat
    cd ${NAGIOS_HOME}/etc/ || exit 1
    cp -f ndo2db.cfg-sample ndo2db.cfg
    sed -i -e "s/^db_host=.*/db_host=${MYSQL_ADDRESS}/" \
        -e "s/^db_name=.*/db_name=${MYSQL_DATABASE}/" \
        -e "s/^db_user=.*/db_user=${MYSQL_USER}/" \
        -e "s/^db_pass=.*/db_pass=${MYSQL_PASSWORD}/" ndo2db.cfg
    cd /usr/local/nrdp/server || exit 1
    cp -f config.inc.php.example config.inc.php
    sed -i -e "s,//\"mysecrettoken\",\"${NRDP_TOKEN}\"," \
        -e "s/nagcmd/${NAGIOS_GROUP}/" \
        -e "s,/usr/local/nagios,${NAGIOS_HOME}," config.inc.php
    touch ${NAGIOS_HOME}/var/config.deployed
}


create_database() {
    wait-for-it "${MYSQL_ADDRESS}:3306"
    mysql -u${MYSQL_USER} \
        -p${MYSQL_PASSWORD} \
        -h${MYSQL_ADDRESS} \
        -P3306 \
        ${MYSQL_DATABASE} < ${MYSQL_CREATEDB_SQL}
    mv ${MYSQL_CREATEDB_SQL} ${MYSQL_CREATEDB_SQL}.executed
}


shutdown() {
  echo Shutting Down
  /etc/init.d/nagios stop
  /etc/init.d/grafana-server stop
  /etc/init.d/graphios stop
  /opt/graphite/bin/carbon-cache.py stop
  ls /etc/service | SHELL=/bin/sh parallel --no-notice sv force-stop {}
  if [ -e /proc/$RUNSVDIR ]; then
    kill -HUP $RUNSVDIR
    wait $RUNSVDIR
  fi
  sleep 1
  ORPHANS=`ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$'`
  SHELL=/bin/bash parallel --no-notice 'timeout 5 /bin/bash -c "kill {} && wait {}" || kill -9 {}' ::: $ORPHANS 2> /dev/null
  exit
}


startup() {
    # /opt/graphite/bin/carbon-cache.py start
    # /etc/init.d/graphios start
    /etc/init.d/grafana-server start
    /etc/init.d/nagios start

    exec runsvdir -P /etc/service &
    RUNSVDIR=$!
    echo "Started runsvdir, PID is $RUNSVDIR"
    ${NAGIOS_HOME}/bin/ndo2db -c ${NAGIOS_HOME}/etc/ndo2db.cfg
    trap shutdown SIGTERM SIGHUP SIGINT
    wait $RUNSVDIR

    shutdown
}


main() {
    if [ ! -f ${NAGIOS_HOME}/var/config.deployed ]; then
        setup_config
    fi

    if [ $CREATE_DB -eq 1 ] && [ -f $MYSQL_CREATEDB_SQL ]; then
        create_database
    fi

    if [ "xxx${NAGIOSADMIN_USER}" != "xxx" ] && [ "xxx${NAGIOSADMIN_PASS}" != "xxx" ]; then
        htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
        chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/etc/htpasswd.users
    fi

    chmod +x ${NAGIOS_HOME}/libexec/* /data/plugin/*
    startup
}


if [ "$1" = 'nagios' ]; then
    shift
    while [ $# -gt 0 ]; do
        arg=$1 ; shift
        case $arg in
        "--create-db")
            CREATE_DB=1
            ;;
        "--server-url")
            SERVER_URL="$1" ; shift;;
        esac
    done
    main
else
    exec "$@"
fi
