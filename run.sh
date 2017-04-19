#!/bin/bash

# adapted from https://github.com/discourse/discourse_docker/blob/master/image/base/boot
# this script becomes PID 1 inside the container, catches termination signals, and stops
# processes managed by runit

if [ "xxx${NAGIOSADMIN_USER}" != "xxx" ] && [ "xxx${NAGIOSADMIN_PASS}" != "xxx" ]; then
  htpasswd -c -b -s ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOSADMIN_USER} ${NAGIOSADMIN_PASS}
  chown -R nagios.nagios ${NAGIOS_HOME}/etc/htpasswd.users
fi

if [ -f /tmp/mysql.sql ]; then
  echo "${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_ADDRESS} ${MYSQL_DATABASE}"
  wait-for-it "${MYSQL_ADDRESS}:3306"
  mysql "-u${MYSQL_USER}" "-p${MYSQL_PASSWORD}" "-h${MYSQL_ADDRESS}" "-P3306" "${MYSQL_DATABASE}" < /tmp/mysql.sql
  sed -i "s/^db_host=.*/db_host=${MYSQL_ADDRESS}/g;s/^db_name=.*/db_name=${MYSQL_DATABASE}/g;s/^db_user=.*/db_user=${MYSQL_USER}/g;s/^db_pass=.*/db_pass=${MYSQL_PASSWORD}/g;" "${NAGIOS_HOME}/etc/ndo2db.cfg"
  mv /tmp/mysql.sql /tmp/mysql.sql.executed
fi

shutdown() {
  echo Shutting Down
  ls /etc/service | SHELL=/bin/sh parallel --no-notice sv force-stop {}
  if [ -e /proc/$RUNSVDIR ]; then
    kill -HUP $RUNSVDIR
    wait $RUNSVDIR
  fi

  # give stuff a bit of time to finish
  sleep 1

  ORPHANS=`ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$'`
  SHELL=/bin/bash parallel --no-notice 'timeout 5 /bin/bash -c "kill {} && wait {}" || kill -9 {}' ::: $ORPHANS 2> /dev/null
  exit
}

chmod 755 -R "${NAGIOS_HOME}/libexec/"
/opt/graphite/bin/carbon-cache.py start
/etc/init.d/graphios start
/etc/init.d/grafana-server start
/etc/init.d/nagios start

exec runsvdir -P /etc/service &
RUNSVDIR=$!
echo "Started runsvdir, PID is $RUNSVDIR"
${NAGIOS_HOME}/bin/ndo2db -c ${NAGIOS_HOME}/etc/ndo2db.cfg
trap shutdown SIGTERM SIGHUP SIGINT
wait $RUNSVDIR

shutdown

