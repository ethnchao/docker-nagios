#!/bin/bash
# Please attention: this script will install ncpa agent

BATCHFILE='c:\temp\ncpa\install.bat'
AUTHFILE=$(mktemp /tmp/okconfig.XXXXXXXXXX)
INSTALL_LOCATION=/usr/share/okconfig/client/windows/
LOGFILE=/tmp/install_ncpa.log
TEST=0
STAGEINFO=0

while [ $# -gt 0 ]; do
	arg=$1 ; shift
	case $arg in
	"--domain")
		DOMAIN=$1 ; shift ;;
	"--user")
		DOMAIN_USER="$1" ; shift;;
	"--password")
		DOMAIN_PASSWORD="$1" ; shift;;
	"--test")
		TEST=1
		;;
    "--stages")
        STAGEINFO=1
        ;;
	"--authentication-file" | "-A")
		USER_AUTHFILE="$1" ; shift ;;
	*)
		HOSTLIST="$HOSTLIST $arg"  ;;

	esac
done

if [ $STAGEINFO -gt 0 ]; then
    cat <<EO
Check Prerequisites;Checks whether the nsclient install directory exists
Connection test;Test connection to the target machine
Upload NSClient++ Setup;Stages the install on the remote host for installation
Installing NSClient++;Performing the actual install
EO
    exit 0
fi

if [ -z "${USER_AUTHFILE}" ]; then
	if [ -z "$DOMAIN" ]; then
		echo -n "Domain Name (DOMAIN): "
		read DOMAIN
	fi


	if [ -z "$DOMAIN_USER" ]; then
		echo -n "Domain user (user): "
		read DOMAIN_USER
	fi


	if [ -z "$DOMAIN_PASSWORD" ]; then
		stty -echo
		echo -n "Domain password: "
		read DOMAIN_PASSWORD
		stty echo
		echo
	fi
	trap "rm -f ${AUTHFILE}" EXIT
	cat <<EO > ${AUTHFILE}
username=${DOMAIN_USER}
password=${DOMAIN_PASSWORD}
domain=${DOMAIN}
EO
else
	DOMAIN=$(grep -i ^domain ${USER_AUTHFILE} |awk -F"=" '{print $2}'|sed 's/ //g')
	AUTHFILE="${USER_AUTHFILE}"
fi

fatal_error() {
	stage=$1
        host=$2
	msg=$3
	printf "[%-24s] %s FATAL %s\n" "${stage}" "${host}" "${msg}" >&2
	echo -e "$(date -R): FATAL ${msg}\n" >> ${LOGFILE}
	exit 1
}

error() {
	stage=$1
	host=$2
	msg=$3
	error_count=$(( ${error_count} + 1 ))
	printf "[%-24s] %s ERROR %s\n" "${stage}" "${host}" "${msg}" >&2
	echo -e "$(date -R): ERROR ${msg}\n" >> ${LOGFILE}
}

host_stage() {
        stage=$1
	host=$2
	printf "[%-24s] %s Starting..\n" "${stage}" "${host}"
	printf "$(date -R): [%-24s] %s Starting\n" "${stage}" "${host}" >> ${LOGFILE}
}

OK() {
        stage=$1
        host=$2
	printf "[%-24s] %s %s\n" "${stage}" "${host}" "OK"
	printf "$(date -R): [%-24s] %s %s\n" "${stage}" "${host}" "OK" >> ${LOGFILE}
}

error_count=0
host_stage "Check Prerequisites" "$(hostname)"
if [ ! -d "${INSTALL_LOCATION}/ncpa" ]; then
	fatal_error "Check Prerequisites" "$(hostname)" "Directory $INSTALL_LOCATION/ncpa not found\nMore info at https://github.com/ethnchao/Docker-Nagios/wiki/Deploying-ncpa-on-windows-servers"
fi

OK "Check Prerequisites" "$(hostname)"

install_host() {
	local host
	host=$1
	host_stage "Connection test" "${host}"
	cat < /dev/null | winexe --reinstall -d 0 -A ${AUTHFILE} "//${host}" "cmd /c echo test" 2>&1 | awk "{ print \"$(date -R): ${host}\", \$0}" >> ${LOGFILE}
    RESULT=${PIPESTATUS[0]}
	if [ $RESULT -gt 0 ]; then
		error "Connection test" "${host}" "Connection test failed, check ${LOGFILE}"
		continue
	fi
	OK "Connection test" "${host}"

	# Stop run, we can connect
	if [ $TEST -gt 0 ]; then
		exit 0
	fi

	host_stage "Upload NCPA Setup" "${host}"

	cd $INSTALL_LOCATION
	echo "$host   $AUTHFILE   $DOMAIN"

	if [[ -z $DOMAIN ]]; then
		DOMAIN=$HOSTNAME
	fi
	smbclient -d 0 //${host}/c$ -A ${AUTHFILE} -W ${DOMAIN} -c  "mkdir \\temp ; cd /temp ; recurse ; prompt ; mput ncpa" 2>&1 | awk "{ print \"$(date -R): ${host}\", \$0}" >> ${LOGFILE}
	RESULT=${PIPESTATUS[0]}

	if [ $RESULT -gt 0 ]; then
		error "Upload NCPA Setup" "${host}" "Failed to copy files to ${host}, check ${LOGFILE}"
		continue
	fi
	OK "Upload NCPA Setup" "${host}"

	host_stage "Installing NCPA" "${host}"
	cat < /dev/null | winexe --reinstall -d 0 -A ${AUTHFILE} "//${host}" "cmd /c $BATCHFILE" 2>&1 | awk "{ print \"$(date -R): ${host}\", \$0}" >> ${LOGFILE}
	RESULT=${PIPESTATUS[0]}

	if [ $RESULT -gt 0 ]; then
		error "Installing NCPA" "${host}" "install of ${host} failed, check ${LOGFILE}"
		continue
	fi
	OK "Installing NCPA" "${host}"

	host_stage "Delete Tempfiles" "${host}"
	smbclient -d 0 //${host}/c$ -A ${AUTHFILE} -W ${DOMAIN} -c  "cd /temp/ncpa ; rm ncpa.exe ; rm install.bat ; cd /temp/ ; rd ncpa ; cd / ; rd temp" 2>&1 | awk "{ print \"$(date -R): ${host}\", \$0}" >> ${LOGFILE}
	RESULT=${PIPESTATUS[0]}

	if [ $RESULT -gt 0 ]; then
		error "Delete Tempfiles" "${host}" "Failed to delete tempfiles at ${host}, check ${LOGFILE}"
		continue
	fi
	OK "Delete Tempfiles" "${host}"
}

for i in $HOSTLIST ; do
	install_host "${i}"
done

if [ $error_count -gt 0 ]; then
	exit 1
else
	exit 0
fi
