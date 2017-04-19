cd /d %~dp0
@echo off
cls
set "basedir=%cd%"
echo "Installing ncpa"
"ncpa.exe" /S /TOKEN='yourn-ncpa-token' /NRDPURL='http://nagios-server-address/nrdp/' /NRDPTOKEN='your-nrdp-token' /HOST='your-host-name'
move "%programfiles(x86)%\Nagios\NCPA\etc\ncpa.cfg" "%programfiles(x86)%\Nagios\NCPA\etc\ncpacfg.bak"
net stop ncpapassive
(
echo [listener]
echo uid = nagios
echo certificate = adhoc
echo loglevel = info
echo ip = 0.0.0.0
echo gid = nagcmd
echo logfile = var/ncpa_listener.log
echo port = 5693
echo pidfile = var/ncpa_listener.pid
echo # Available versions: PROTOCOL SSLv2, SSLv3, TLSv1
echo ssl_version = TLSv1
echo.
echo [passive]
echo uid = nagios
echo handlers = nrds,nrdp
echo loglevel = info
echo gid = nagcmd
echo sleep = 300
echo logfile = var/ncpa_passive.log
echo pidfile = var/ncpa_passive.pid
echo.
echo [nrdp]
echo token = culaio239ncgklak
echo hostname = your-host-name
echo parent = http://nrdp-server-address/nrdp/
echo.
echo [nrds]
echo URL = http://nrds-server-address/nrdp/
echo CONFIG_VERSION = 0
echo TOKEN = your-nrdp-token
echo CONFIG_NAME =
echo CONFIG_OS = None
echo PLUGIN_DIR = plugins/
echo UPDATE_CONFIG = 1
echo UPDATE_PLUGINS = 1
echo.
echo [api]
echo community_string = mfasjlk1asjd7flj3lytoken
echo.
echo [plugin directives]
echo plugin_path = plugins/
echo .sh = /bin/sh $plugin_name $plugin_args
echo .ps1 = powershell -ExecutionPolicy Bypass -File $plugin_name $plugin_args
echo .vbs = cscript $plugin_name $plugin_args //NoLogo
echo.
echo [passive checks]
echo %%HOSTNAME%%^|CPU-Usage = /cpu/percent --warning 20 --critical 30
echo %%HOSTNAME%%^|Swap-Usage = /memory/swap/percent --warning 40 --critical 80
echo %%HOSTNAME%%^|Memory-Usage = /memory/virtual/percent --warning 60 --critical 80
echo %%HOSTNAME%%^|Partition-C-Usage = /disk/logical/C:^| --warning 60 --critical 80
echo %%HOSTNAME%%^|Processes = /processes --warning 250 --critical 300
echo %%HOSTNAME%%^|Users = /user/count --warning 3 --critical 5
echo.
) >"%programfiles(x86)%\Nagios\NCPA\etc\ncpa.cfg"
net start ncpapassive

echo COMPLETE!