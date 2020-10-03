# A simple Zabbix Agent installer

This script sets up the Zabbix Agent on a host and does this with a very
simple set of configuration settings. It adds support for automated disk
discovery when disks are available on /dev/sd*.

## Usage

To install the agent, use the following command:

```bash
git clone https://github.com/sensson/zabbix-installer.git
cd zabbix-installer
chmod +x agent-installer.sh
./agent-installer.sh
```

And follow the questions on screen. You will need to have the Zabbix server
IP ready. By default it will use port 10050, though you can adjust this.

It does not set up any firewall rules for you. Don't forget to open up the
port you've chosen.
