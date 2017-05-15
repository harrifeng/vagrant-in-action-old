!/bin/bash
echo "
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse" | sudo tee /etc/apt/sources.list

sudo apt-get update

# page 11: [Set the hostname of the node to controller]
echo "
# controller
10.0.0.11  controller

# compute1
10.0.0.31 compute1

# block1
10.0.0.41 block1

# object1
10.0.0.51 object1

# object2
10.0.0.52 object2" | sudo tee -a /etc/hosts

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install chrony

echo '-------------------------------------------------------------------------'
# page 15
CONF_CHRONY=/etc/chrony/chrony.conf
echo "
server 0.amazon.pool.ntp.org iburst
allow 10.0.0.0/24
" | sudo tee -a ${CONF_CHRONY}

sudo service chrony restart

echo '----------------------------------------------------------------------->>'
echo ${CONF_CHRONY}
echo '----------------------------------------------------------------------->>'
cat ${CONF_CHRONY}
echo '-----------------------------------------------------------------------<<'
echo ${CONF_CHRONY}
echo '-----------------------------------------------------------------------<<'

chronyc sources

echo '-------------------------------------------------------------------------'
# page 17 Distributions release Openstack packages as part of the distribution or
# using other methods because of differing release schedules.
# Perform these procedures on all nodes.
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
sudo add-apt-repository -y cloud-archive:ocata

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python-openstackclient

# The database typically runs on the controller node.
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install mariadb-server python-pymysql

echo '-------------------------------------------------------------------------'
# page 18
echo "
[mysqld]
bind-address = 10.0.0.11
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" | sudo tee -a /etc/mysql/mariadb.conf.d/99-openstack.cnf

echo '----------------------------------------------------------------------->>'
echo /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo '----------------------------------------------------------------------->>'
cat /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo '-----------------------------------------------------------------------<<'
echo /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo '-----------------------------------------------------------------------<<'

sudo service mysql restart
sudo mysql -uroot -h localhost -e "SHOW DATABASES"

echo '-------------------------------------------------------------------------'
# page 19: the message queue runs on the controller node.
#
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install rabbitmq-server
RABBIT_PASS=welcome
sudo rabbitmqctl add_user openstack ${RABBIT_PASS}
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install memcached python-memcache

CONF_MEMCACHE=/etc/memcached.conf
sudo sed -i "s/-l 127.0.0.1/-l 10.0.0.11/g" ${CONF_MEMCACHE}
sudo service memcached restart

echo '----------------------------------------------------------------------->>'
echo ${CONF_MEMCACHE}
echo '----------------------------------------------------------------------->>'
cat ${CONF_MEMCACHE}
echo '-----------------------------------------------------------------------<<'
echo ${CONF_MEMCACHE}
echo '-----------------------------------------------------------------------<<'

echo '-------------------------------------------------------------------------'
# Identity service page 20: A centralized server provides authentication and authorization
# services using a RESTful interface

# page 21
DB_PASS=welcome
sudo mysql -uroot -h localhost -e "CREATE DATABASE keystone"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${DB_PASS}';"

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install keystone

# we have to use `|` as seperator
DB_PASS=welcome
CONF_KEYSTONE=/etc/keystone/keystone.conf
sudo sed -i "s|#connection.*|connection = mysql+pymysql://keystone:${DB_PASS}@controller/keystone|g" ${CONF_KEYSTONE}
sudo sed -i "s|#provider.*|provider = fernet|g" ${CONF_KEYSTONE}

# page 22: Populate the Identity service database
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone

echo '----------------------------------------------------------------------->>'
echo ${CONF_KEYSTONE}
echo '----------------------------------------------------------------------->>'
cat ${CONF_KEYSTONE}
echo '-----------------------------------------------------------------------<<'
echo ${CONF_KEYSTONE}
echo '-----------------------------------------------------------------------<<'

# Initialize Fernet key repositories:
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

ADMIN_PASS=welcome
sudo keystone-manage bootstrap --bootstrap-password ${ADMIN_PASS} \
                --bootstrap-admin-url http://controller:35357/v3/ \
                --bootstrap-internal-url http://controller:5000/v3/ \
                --bootstrap-public-url http://controller:5000/v3/ \
                --bootstrap-region-id RegionOne

echo '-------------------------------------------------------------------------'
# page 22 Configure the Apache HTTP server
echo "ServerName controller" | sudo tee -a /etc/apache2/apache2.conf
# Restart the Apache service and remove the default SQLite database
sudo service apache2 restart
sudo rm -f /var/lib/keystone/keystone.db

export OS_USERNAME=admin
export OS_PASSWORD=${ADMIN_PASS}
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

echo '-------------------------------------------------------------------------'
echo '> openstack project list'
echo '-------------------------------------------------------------------------'
openstack project list

echo '-------------------------------------------------------------------------'
# page 23: This guide uses a service project that contains a unique user for each
# service that you add to your environment. Create the service project
openstack project create --domain default --description "Service Project" service

# Regular(non-admin) tasks should use an unprivileged project and user. As an example,
# this guide create the demo project and user with following 4 steps

# create demo project
openstack project create --domain default --description "Demo Project" demo

# create demo user
openstack user create --domain default --password welcome demo

# create user role
openstack role create user

# add role to the demo project and user
openstack role add --project demo --user demo user

echo '-------------------------------------------------------------------------'
echo '> openstack token issue'
echo '-------------------------------------------------------------------------'
openstack token issue

echo '-------------------------------------------------------------------------'
# page 26: Image service
# glance
DB_PASS=welcome
sudo mysql -uroot -h localhost -e "CREATE DATABASE glance"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${DB_PASS}';"

echo '-------------------------------------------------------------------------'
# page 28: To create the service credentials, complete following steps
# 1.create glance user
openstack user create --domain default --password welcome glance
# 2.Add the admin role to the glance user and service project
openstack role add --project service --user glance admin
# 3.create the glance service entity
openstack service create --name glance  --description "OpenStack Image" image

# Create the Image service API endpoints
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292

echo '-------------------------------------------------------------------------'
# page 30 Install packages
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install glance

CONF_GLANCE_API=/etc/glance/glance-api.conf
sudo sed -i "s|#connection.*|connection = mysql+pymysql://glance:${DB_PASS}@controller/glance|g" ${CONF_GLANCE_API}
sudo sed -i "s|#auth_uri.*|auth_uri = http://controller:5000|g" ${CONF_GLANCE_API}
sudo sed -i "/auth_uri = /a auth_url = http://controller:35357" ${CONF_GLANCE_API}
sudo sed -i "s|#memcached_servers.*|memcached_servers = controller:11211|g" ${CONF_GLANCE_API}
sudo sed -i "s|#auth_type.*|auth_type = password|g" ${CONF_GLANCE_API}
sudo sed -i "/auth_type/a project_domain_name=default" ${CONF_GLANCE_API}
sudo sed -i "/auth_type/a user_domain_name = default" ${CONF_GLANCE_API}
sudo sed -i "/auth_type/a project_name = service" ${CONF_GLANCE_API}
sudo sed -i "/auth_type/a username = glance" ${CONF_GLANCE_API}
sudo sed -i "/auth_type/a password = welcome" ${CONF_GLANCE_API}
sudo sed -i "s|#flavor.*|flavor = keystone|g" ${CONF_GLANCE_API}
sudo sed -i "s|#stores.*|stores = file,http|g" ${CONF_GLANCE_API}
sudo sed -i "s|#default_store.*|default_store = file|g" ${CONF_GLANCE_API}
sudo sed -i "s|#filesystem_store_datadir.*|filesystem_store_datadir = /var/lib/glance/images/|g" ${CONF_GLANCE_API}


echo '----------------------------------------------------------------------->>'
echo ${CONF_GLANCE_API}
echo '----------------------------------------------------------------------->>'
cat ${CONF_GLANCE_API}
echo '-----------------------------------------------------------------------<<'
echo ${CONF_GLANCE_API}
echo '-----------------------------------------------------------------------<<'

CONF_GLANCE_REG=/etc/glance/glance-registry.conf
sudo sed -i "s|#connection.*|connection = mysql+pymysql://glance:${DB_PASS}@controller/glance|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#auth_uri.*|auth_uri = http://controller:5000|g" ${CONF_GLANCE_REG}
sudo sed -i "/auth_uri/a auth_url = http://controller:35357" ${CONF_GLANCE_REG}

sudo sed -i "s|#memcached_servers.*|memcached_servers=controller:11211|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#auth_type.*|auth_type = password|g" ${CONF_GLANCE_REG}
sudo sed -i "/auth_type/a project_domain_name=default" ${CONF_GLANCE_REG}
sudo sed -i "/auth_type/a user_domain_name = default" ${CONF_GLANCE_REG}
sudo sed -i "/auth_type/a project_name = service" ${CONF_GLANCE_REG}
sudo sed -i "/auth_type/a username = glance" ${CONF_GLANCE_REG}
sudo sed -i "/auth_type/a password = welcome" ${CONF_GLANCE_REG}
sudo sed -i "s|#flavor.*|flavor = keystone|g" ${CONF_GLANCE_REG}

echo '----------------------------------------------------------------------->>'
echo ${CONF_GLANCE_REG}
echo '----------------------------------------------------------------------->>'
cat ${CONF_GLANCE_REG}
echo '-----------------------------------------------------------------------<<'
echo ${CONF_GLANCE_REG}
echo '-----------------------------------------------------------------------<<'

echo '-------------------------------------------------------------------------'
echo '>sudo su -s /bin/sh -c "glance-manage db_sync" glance'
echo 'Note: Ignore any deprecation messages in this output.'
echo '-------------------------------------------------------------------------'
sudo su -s /bin/sh -c "glance-manage db_sync" glance

echo '-------------------------------------------------------------------------'
echo '> sudo service glance-registry restart'
echo '-------------------------------------------------------------------------'
sudo service glance-registry restart
echo '-------------------------------------------------------------------------'
echo '> sudo service glance-api restart'
echo '-------------------------------------------------------------------------'
sudo service glance-api restart

echo '-------------------------------------------------------------------------'
echo 'sleep for 5 seconds'
echo '-------------------------------------------------------------------------'
sleep 5s

echo '-------------------------------------------------------------------------'
echo '> openstack image create'
echo '-------------------------------------------------------------------------'
# page 31 : Verify operation
openstack image create "cirros" --file /vagrant/cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
echo '-------------------------------------------------------------------------'
echo 'openstack image list'
echo '-------------------------------------------------------------------------'
openstack image list

#
# # Install and configure controller node
# # This section describes how to install and configure the Compute service, code-named nova, on the controller node
#
# # Prerequisites (page 34)
# sudo mysql -uroot -h localhost -e "CREATE DATABASE nova"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${DB_PASS}';"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${DB_PASS}';"
#
# sudo mysql -uroot -h localhost -e "CREATE DATABASE nova_api"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${DB_PASS}';"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${DB_PASS}';"
#
# sudo mysql -uroot -h localhost -e "CREATE DATABASE nova_cell0"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '${DB_PASS}';"
# sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '${DB_PASS}';"
#
# # page 35
# export OS_USERNAME=admin
# export OS_PASSWORD=welcome
# export OS_PROJECT_NAME=admin
# export OS_USER_DOMAIN_NAME=Default
# export OS_PROJECT_DOMAIN_NAME=Default
# export OS_AUTH_URL=http://controller:35357/v3
# export OS_IDENTITY_API_VERSION=3
# export OS_IMAGE_API_VERSION=2
#
# openstack user create --domain default --password welcome nova
# openstack role add --project service --user nova admin
# openstack service create --name nova --description "OpenStack Compute" compute
# openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
# openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
# openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
#
# openstack user create --domain default --password welcome placement
# openstack role add --project service --user placement admin
# openstack service create --name placement --description "Placement API" placement
# openstack endpoint create --region RegionOne placement public http://controller/placement
# openstack endpoint create --region RegionOne placement internal http://controller/placement
# openstack endpoint create --region RegionOne placement admin http://controller/placement
#
# # Install and configure components (page 40)
# sudo apt-get install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api
#
# CONF_NOVA=/etc/nova/nova.conf
# sudo sed -i "s|connection=sqlite:////var/lib/nova/nova.sqlite|connection = mysql+pymysql://nova:welcome@controller/nova_api|g" ${CONF_NOVA}
# sudo sed -i "s|#connection=<None>|connection = mysql+pymysql://nova:welcome@controller/nova|g" ${CONF_NOVA}
# sudo sed -i "s|#transport_url=<None>|transport_url = rabbit://openstack:welcome@controller|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_strategy=keystone|auth_strategy=keystone|g" ${CONF_NOVA}
#
# sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_NOVA}
# sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_NOVA}
# sudo sed -i "s|^#my_ip.*|my_ip = 10.0.0.11|g" ${CONF_NOVA}
# sudo sed -i "s|#use_neutron=true|use_neutron=true|g" ${CONF_NOVA}
# sudo sed -i "s|#firewall_driver=<None>|firewall_driver=nova.virt.firewall.NoopFirewallDriver|g" ${CONF_NOVA}
# sudo sed -i "s|#vncserver_listen=127.0.0.1|vncserver_listen=10.0.0.11|g" ${CONF_NOVA}
# sudo sed -i "s|#vncserver_proxyclient_address=127.0.0.1|vncserver_proxyclient_address=10.0.0.11|g" ${CONF_NOVA}
# sudo sed -i "s|#api_servers=<None>|api_servers= http://controller:9292|g" ${CONF_NOVA}
# sudo sed -i "s|lock_path=/var/lock/nova|lock_path=/var/lock/nova/tmp|g" ${CONF_NOVA}
# sudo sed -i "s|^os_region_name.*|os_region_name = RegionOne|g" ${CONF_NOVA}
# sudo sed -i "s|#project_domain_name=<None>|project_domain_name=Default|g" ${CONF_NOVA}
# sudo sed -i "s|#project_name=<None>|project_name=Default|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_type=<None>|auth_type=password|g" ${CONF_NOVA}
# sudo sed -i "s|#user_domain_name=<None>|user_domain_name=Default|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_url=<None>|auth_url=http://controller:35357/v3|g" ${CONF_NOVA}
# sudo sed -i "s|#username =|username = placement|g" ${CONF_NOVA}
# sudo sed -i "s|#password =|password = welcome|g" ${CONF_NOVA}
#
# sudo su -s /bin/sh -c "nova-manage api_db sync" nova
# sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
#
# sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
# sudo su -s /bin/sh -c "nova-manage db sync" nova
# sudo nova-manage cell_v2 list_cells
#
# sudo service nova-api restart
# sudo service nova-consoleauth restart
# sudo service nova-scheduler restart
# sudo service nova-conductor restart
# sudo service nova-novncproxy restart
