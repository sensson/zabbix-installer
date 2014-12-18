#!/bin/bash
#
# This installs a very basic installation of the Zabbix Agent
# It is safe to run it multiple times, though it will overwrite
# any configuration changes you have made to zabbix_agentd.conf
#
# It currently supports CentOS only.
#

echo -n "Monitoring server: "
read MONITORING_SERVER
echo -n "Listening port (10050): "
read LISTEN_PORT

# if LISTEN_PORT is empty, set it to 10050
if [ -z "$LISTEN_PORT" ]; then
	LISTEN_PORT=10050
fi

# import the right key
rpm --import http://repo.zabbix.com/RPM-GPG-KEY-ZABBIX

# set up the repository
cat > /etc/yum.repos.d/zabbix.repo << EOF
[zabbix]
name=Zabbix Repository Server
baseurl=http://repo.zabbix.com/zabbix/2.0/rhel/\$releasever/\$basearch
enabled=1
gpgcheck=1
EOF

# install zabbix-agent
yum install -y zabbix-agent

# set up the configuration file
cat > /etc/zabbix/zabbix_agentd.conf << EOF
# This is a very minimal configuration, adjust it if required.
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=100
DebugLevel=3
EnableRemoteCommands=1
LogRemoteCommands=0
Server=$MONITORING_SERVER
ListenPort=$LISTEN_PORT
StartAgents=3
ServerActive=127.0.0.1
Hostname=`hostname`
HostnameItem=system.hostname
RefreshActiveChecks=120
BufferSend=5
BufferSize=100
MaxLinesPerSecond=100
Timeout=3
AllowRoot=0
Include=/etc/zabbix/zabbix_agentd.d
UnsafeUserParameters=0
EOF

# set up automated disk discovery in zabbix
cat > /etc/zabbix/zabbix_agentd.d/zabbix-disk-discovery.conf << EOF
UserParameter=discovery.disk,/usr/bin/disk-discovery
UserParameter=custom.vfs.dev.read.ops[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$4}'
UserParameter=custom.vfs.dev.read.ms[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$7}'
UserParameter=custom.vfs.dev.write.ops[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$8}'
UserParameter=custom.vfs.dev.write.ms[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$11}'
UserParameter=custom.vfs.dev.io.active[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$12}'
UserParameter=custom.vfs.dev.io.ms[*],cat /proc/diskstats | egrep \$1 | head -1 y| awk '{print \$\$13}'
UserParameter=custom.vfs.dev.read.sectors[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$6}'
UserParameter=custom.vfs.dev.write.sectors[*],cat /proc/diskstats | egrep \$1 | head -1 | awk '{print \$\$10}'
EOF

cat > /usr/bin/disk-discovery << EOF
#!/bin/bash
#
# Gather all disks from the system and present them in a json format
#

disks=\`/bin/ls /dev/sd* | awk '{print \$NF}' | sed 's/[0-9]//g' | uniq\`
echo "{"
echo "\\"data\\":["
for disk in $disks
do
    echo "    {\\"{#DISKNAME}\\":\\"\$disk\\",\\"{#SHORTDISKNAME}\\":\\"\${disk:5}\\"},"
done
echo "]"
echo "}"
EOF

# restart the zabbix agent
service zabbix-agent restart
chkconfig zabbix-agent on
