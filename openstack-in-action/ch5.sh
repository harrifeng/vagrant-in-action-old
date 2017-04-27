# update the package we use mirror 163
sudo apt-get update

###############
# section 5.1 #
###############

MYSQL_ROOT_PASS=rootpass
echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections

sudo apt-get -y install \
     rabbitmq-server \
     python-mysqldb \
     mysql-server

# bind mysql to 0.0.0.0, ignore the mysql performance so far
sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
sudo service mysql restart
sudo service mysql status

###############
# section 5.2 #
###############
MYSQL_ROOT_PASS=rootpass
MYSQL_OPENSTACK_PASS_1=openstack1

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install keystone
mysql -uroot -p$MYSQL_ROOT_PASS -e 'DROP DATABASE IF EXISTS keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone_dbu'@'localhost' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone_dbu'@'%' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"

KEYSTONE_CONF=/etc/keystone/keystone.conf
sudo sed -i "s#^connection.*#connection = mysql://keystone_dbu:openstack1@localhost:3306/keystone#" ${KEYSTONE_CONF}
sudo sed -i 's/^#admin_token.*/admin_token = ADMIN/' ${KEYSTONE_CONF}
sudo sed -i 's,^#log_dir.*,log_dir = /var/log/keystone,' ${KEYSTONE_CONF}
sudo service keystone restart

sudo keystone-manage db_sync


# Host address
HOST_IP=192.168.2.50 #The Management Address
# Keystone definitions
KEYSTONE_REGION=RegionOne
ADMIN_PASSWORD=admin_pass
SERVICE_PASSWORD=service_pass
export SERVICE_TOKEN="ADMIN"
export SERVICE_ENDPOINT="http://192.168.2.50:35357/v2.0"
SERVICE_TENANT_NAME=service

keystone discover
echo '--------------------------------'
keystone service-create --name=keystone --type=identity --description="Identity Service"
keystone endpoint-create \
         --region RegionOne \
         --service=keystone \
         --publicurl=http://10.33.2.50:5000/v2.0 \
         --internalurl=http://192.168.2.50:5000/v2.0 \
         --adminurl=http://192.168.2.50:35357/v2.0

echo '--------------------------------'
keystone tenant-create --name=admin --description "Admin Tenant"

echo '--------------------------------'
keystone tenant-create --name=service  --description="Service Tenant"

echo '--------------------------------'
keystone user-create --name=admin \
         --pass=openstack1 \
         --email=admin@testco.com

echo '--------------------------------'
keystone role-create --name=admin

echo '--------------------------------'
keystone role-create --name=Member

echo '--------------------------------'
keystone user-role-add --user=admin --role=admin --tenant=admin


mysql -uroot -p$MYSQL_ROOT_PASS -e 'DROP DATABASE IF EXISTS glance;'
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE glance DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance_dbu'@'localhost' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance_dbu'@'%' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"

echo '--------------------------------'
keystone user-create --name=glance \
         --pass="openstack1" \
         --email=glance@testco.com

echo '--------------------------------'
keystone user-role-add --user=glance --role-id=admin --tenant=service

echo '--------------------------------'
keystone service-create --name=glance --type=image --description="Image Service"

echo '--------------------------------'
keystone endpoint-create \
         --region RegionOne \
         --service=glance \
         --publicurl=http://10.33.2.50:9292 \
         --internalurl=http://192.168.2.50:9292 \
         --adminurl=http://192.168.2.50:9292

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install \
     glance \
     glance-api \
     glance-registry \
     python-glanceclient \
     glance-common

GLANCE_API_CONF=/etc/glance/glance-api.conf
echo "
[DEFAULT]
rpc_backend = rabbit
rabbit_host = 192.168.2.50
rabbit_password = guest

[database]
connection = mysql://glance_dbu:openstack1@localhost:3306/glance
mysqla-sql_mode = TRADITIONAL" | sudo tee -a ${GLANCE_API_CONF}


GLANCE_REGISTRY_CONF=/etc/glance/glance-registry.conf
echo "
[database]
connection = mysql://glance_dbu:openstack1@localhost:3306/glance
mysqla-sql_mode = TRADITIONAL" | sudo tee -a ${GLANCE_REGISTRY_CONF}

sudo service glance-api restart
sudo service glance-registry restart
sudo glance-manage db_sync



glance --os-username=admin --os-password openstack1 \
       --os-tenant-name=admin \
       --os-auth-url=http://10.33.2.50:5000/v2.0  \
       image-create \
       --name="Cirros 0.3.2" \
       --is-public=true \
       --disk-format=qcow2 \
       --container-format=bare \
       --file /vagrant/cirros-0.3.2-x86_64-disk.img

###############
# section 5.3 #
###############

mysql -uroot -p$MYSQL_ROOT_PASS -e 'DROP DATABASE IF EXISTS cinder;'
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE cinder DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder_dbu'@'localhost' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder_dbu'@'%' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"

echo "--------------------------------"
keystone user-create --name=cinder \
         --pass="openstack1" \
         --email=cinder@testco.com

echo "--------------------------------"
keystone user-role-add --user=cinder --role-id=admin --tenant=service

echo "--------------------------------"
keystone service-create --name=cinder --type=volume  --description="Block Storage"

echo "--------------------------------"

keystone endpoint-create \
         --region RegionOne \
         --service=cinder \
         --publicurl=http://10.33.2.50:8776/v1/%\(tenant_id\)s \
         --internalurl=http://192.168.0.50:8776/v1/%\(tenant_id\)s \
         --adminurl=http://192.168.0.50:8776/v1/%\(tenant_id\)s

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cinder-api cinder-scheduler

CINDER_CONF=/etc/cinder/cinder.conf

echo "
[DEFAULT]
rpc_backend = rabbit
rabbit_host = 192.168.2.50
rabbit_password = guest
[database]
connection = mysql://cinder_dbu:openstack1@localhost/cinder
[keystone_authtoken]
auth_uri = http://192.168.2.50:35357
admin_tenant_name = service
admin_password = openstack1
auth_protocol = http
admin_user = cinder " | sudo tee -a ${CINDER_CONF}

sudo service cinder-scheduler restart
sudo service cinder-api restart
sudo cinder-manage db sync

###############
# section 5.4 #
###############

mysql -uroot -p$MYSQL_ROOT_PASS -e 'DROP DATABASE IF EXISTS neutron;'
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE neutron DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron_dbu'@'localhost' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron_dbu'@'%' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"

keystone user-create --name=neutron \
         --pass="openstack1" \
         --email=neutron@testco.com


keystone user-role-add \
         --user=neutron \
         --role=admin \
         --tenant=service

keystone service-create --name=neutron --type=network  --description="OpenStack Networking Service"

keystone endpoint-create \
         --region RegionOne \
         --service=neutron \
         --publicurl=http://10.33.2.50:9696 \
         --internalurl=http://192.168.2.50:9696 \
         --adminurl=http://192.168.2.50:9696
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install neutron-server

SERVICE_TENANT_ID=$(keystone  tenant-list | awk '/\ service\ / {print $2}')
NEUTRON_CONF=/etc/neutron/neutron.conf

echo "
[DEFAULT]
core_plugin = neutron.plugins.ml2.plugin.Ml2Plugin
service_plugins = router,firewall,lbaas,vpnaas,metering
allow_overlapping_ips = True

nova_url = http://192.168.2.50:8774/v2
nova_admin_username = admin
nova_admin_password = openstack1
nova_admin_tenant_id = ${SERVICE_TENANT_ID}
nova_admin_auth_url = http://10.33.2.50:35357/v2.0

[keystone_authtoken]
auth_uri = http://10.33.2.50:5000
auth_protocol = http
admin_tenant_name = service
admin_user = neutron
admin_password = openstack1

[database]
connection = mysql://neutron_dbu:openstack1@localhost/neutron " |  sudo tee -a ${NEUTRON_CONF}


ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini

echo "
[ml2]
type_drivers = gre
tenant_network_types = gre
mechanism_drivers = openvswitch
[ml2_type_gre]
tunnel_id_ranges = 1:1000
[securitygroup]
firewall_driver =
neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver enable_security_group = True" | sudo tee -a ${ML2_TYPE_GRE}

sudo service neutron-server restart

###############
# section 5.5 #
###############

mysql -uroot -p$MYSQL_ROOT_PASS -e 'DROP DATABASE IF EXISTS nova;'
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE nova DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova_dbu'@'localhost' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova_dbu'@'%' IDENTIFIED BY '$MYSQL_OPENSTACK_PASS_1';"

echo "--------------------------------"
keystone user-create --name=nova \
         --pass="openstack1" \
         --email=nova@testco.com

echo "--------------------------------"
keystone user-role-add --user=nova --role=admin --tenant=service

echo "--------------------------------"
keystone service-create --name=nova --type=compute  --description="OpenStack Compute Service"

echo "--------------------------------"
keystone endpoint-create --region RegionOne \
         --service=nova \
         --publicurl='http://10.33.2.50:8774/v2/$(tenant_id)s' \
         --internalurl='http://192.168.0.50:8774/v2/$(tenant_id)s' \
         --adminurl='http://192.168.0.50:8774/v2/$(tenant_id)s'

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install nova-api \
     nova-cert \
     nova-conductor \
     nova-consoleauth \
     nova-novncproxy \
     nova-scheduler \
     python-novaclient


NOVA_CONF=/etc/nova/nova.conf

echo "
rpc_backend = rabbit
rabbit_host = 192.168.2.50
rabbit_password = guest
my_ip = 192.168.2.50
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = 0.0.0.0
auth_strategy=keystone
service_neutron_metadata_proxy = true
neutron_metadata_proxy_shared_secret = openstack1
network_api_class = nova.network.neutronv2.api.API
neutron_url = http://192.168.2.50:9696
neutron_auth_strategy = keystone
neutron_admin_tenant_name = service
neutron_admin_username = neutron
neutron_admin_password = openstack1
neutron_admin_auth_url =  http://192.168.2.50:35357/v2.0
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver
security_group_api = neutron
[database]
connection = mysql://nova_dbu:openstack1@localhost/nova
[keystone_authtoken]
auth_uri = http://192.168.2.50:35357
admin_tenant_name = service
admin_password = openstack1
auth_protocol = http
admin_user = nova" |  sudo tee -a ${NOVA_CONF}

sudo nova-manage db sync

cd /usr/bin/; for i in $( ls nova-* );  do sudo service $i restart; done
echo '--------------------------------'
sudo nova-manage service list

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install openstack-dashboard memcached python-memcache

# remove the Ubuntu theme, which has been reported to cause problems with some modules:
apt-get -y remove --purge openstack-dashboard-ubuntu-theme
