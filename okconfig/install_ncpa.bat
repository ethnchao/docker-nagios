cd /d %~dp0
@echo off
cls
set "basedir=%cd%"
echo "Installing ncpa"
"ncpa.exe" /S /TOKEN='NCPA_TOKEN' /NRDPURL='NRDP_URL' /NRDPTOKEN='NRDP_TOKEN' /NRDPHOSTNAME='%COMPUTERNAME%'
(
echo [passive checks]
echo %%HOSTNAME%%^|__HOST__ = system/agent_version
echo %%HOSTNAME%%^|CPU Usage = cpu/percent --warning 80 --critical 90 --aggregate avg
echo %%HOSTNAME%%^|Swap Usage = memory/swap --warning 60 --critical 80
echo %%HOSTNAME%%^|Memory Usage = memory/virtual --warning 80 --critical 90
echo %%HOSTNAME%%^|Process Count = processes --warning 300 --critical 400
echo %%HOSTNAME%%^|C Partition Usage = disk/logical/C:^|/used_percent --warning 80 --critical 90
) >"%programfiles(x86)%\Nagios\NCPA\etc\ncpa.cfg.d\nrdp.cfg"

net start ncpapassive

echo COMPLETE!
