containerid=`docker run -d --net=none --name cas2 --hostname cas2 --dns 10.0.0.1 --dns-search endor.lab cassandra`
ovs-docker add-port br0 eth0 $containerid --ipaddress=10.0.0.200/16 --gateway=10.0.0.100
