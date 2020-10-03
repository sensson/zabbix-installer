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

. /etc/os-release

rpm -ivh "http://repo.zabbix.com/zabbix/4.0/rhel/${VERSION_ID}/x86_64/zabbix-release-4.0-2.el${VERSION_ID}.noarch.rpm"
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
for disk in \$disks
do
    echo "    {\\"{#DISKNAME}\\":\\"\$disk\\",\\"{#SHORTDISKNAME}\\":\\"\${disk:5}\\"},"
done
echo "]"
echo "}"
EOF

chmod +x /usr/bin/disk-discovery

# set up support for mysql
cat > /etc/zabbix/zabbix_agentd.d/mysql.conf << EOF
# mysql status information
UserParameter=mysql.status[*],/usr/bin/mysqladmin -u\$1 -p\$2 extended-status 2>/dev/null | awk '/ \$3 /{print \$\$4}'
UserParameter=mysql.processlist[*],/usr/bin/mysqladmin -u\$1 -p\$2 processlist
EOF

# and remove the existing file as we believe ours to be more useful for now
rm -f /etc/zabbix/zabbix_agentd.d/userparameter_mysql.conf

# restart the zabbix agent
if grep -q -i 'release 6' /etc/redhat-release; then
    service zabbix-agent restart
    chkconfig zabbix-agent on
else
    systemctl restart zabbix-agent
    systemctl enable zabbix-agent
fi
