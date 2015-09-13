The instruction describes the manual setup of an OpenContrail Control Node using
the official PPA. In the instructions below 10.0.0.203 is used as the IP address
of the node and 'vip' as the hostname of the virtual IP address of the LB.

<ol>
<li>software installation</li>
</ol>

```
apt-get -y --force-yes install wget curl software-properties-common
add-apt-repository ppa:opencontrail/ppa
add-apt-repository ppa:opencontrail/r2.20
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppetlabs-release-trusty.deb
apt-get update
apt-get install -y --force-yes curl tcpdump iptables openssh-server rsync ntp software-properties-common wget libssl0.9.8 \
					contrail-nodemgr contrail-utils puppet supervisor python-contrail contrail-lib \
                                        contrail-web-core contrail-web-controller nodejs=0.8.15-1contrail1
```

<ol start=2>
<li>configuration variables</li>
</ol>
```
IP='10.0.0.204' # the IP address configured on the database node
DISC_SERVER='10.0.0.201' # IP address, hostname of the Discovery server (config node). Can also be the vip if load-balanced
HOSTNAME=ctrl2 # the hostname of the database node
ADMIN_USER=admin
ADMIN_PASSWORD=ladakh1
ADMIN_TENANT=admin
ADMIN_TOKEN=ladakh1
KEYSTONE_SERVER=vip
CASSANDRA_SERVER_LIST='10.0.0.200'
CASSANDRA_PORT=9160
ZOOKEEPER_PORT=2181
RABBIT_SERVER=vip
RABBIT_PORT=5672
ANALYTICS_SERVER='10.0.0.202'
DNS_SERVER='10.0.0.1'
CONFIG_SERVER='10.0.0.201'
NEUTRON_SERVER=vip
GLANCE_SERVER=vip
NOVA_SERVER=vip
CINDER_SERVER=vip

```

<ol start=3>
<li>configuration</li>
</ol>

<li>modify /etc/contrail/config.global.js</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList \'$ip\',`
done
casList=`echo ${casList::-1}`
casAr=`echo [$casList]`

sed -i "s/config.networkManager.ip = '127.0.0.1';/config.networkManager.ip = '$NEUTRON_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.imageManager.ip = '127.0.0.1';/config.imageManager.ip = '$GLANCE_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.computeManager.ip = '127.0.0.1';/config.computeManager.ip = '$NOVA_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.identityManager.ip = '127.0.0.1';/config.identityManager.ip = '$KEYSTONE_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.storageManager.ip = '127.0.0.1';/config.storageManager.ip = '$CINDER_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.cnfg.server_ip = '127.0.0.1';/config.cnfg.server_ip = '$CONFIG_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.analytics.server_ip = '127.0.0.1';/config.analytics.server_ip = '$ANALYTICS_SERVER';/g" /etc/contrail/config.global.js
sed -i "s/config.discoveryService.enable = false;/config.discoveryService.enable = true;/g" /etc/contrail/config.global.js
sed -i "/config.discoveryService = {};/a config.discoveryService.ip = '$DISC_SERVER'" /etc/contrail/config.global.js
sed -i "s/config.cassandra.server_ips = \['127.0.0.1'\];/config.cassandra.server_ips = $casAr/g" /etc/contrail/config.global.js

<li>start redis-server</li>
```
service redis-server start
```

<li>start contrail webui</li>
```
start contrail-webui-jobserver
start contrail-webui-webserver
```

<li>ntp workaround (only for docker)</li>
```
cat << EOF > /etc/ntp.conf
restrict 127.0.0.1
restrict ::1
server 127.127.1.0 iburst
driftfile /var/lib/ntp/drift
fudge 127.127.1.0 stratum 5
EOF
service ntp restart
```

