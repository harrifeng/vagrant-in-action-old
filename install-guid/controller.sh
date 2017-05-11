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

# Add the etc host
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

# NTP implementation Chrony
echo '----------------------------'
sudo apt-get install -y chrony
echo "
allow 10.0.0.0/24
" | sudo tee -a /etc/chrony/chrony.conf
sudo service chrony restart

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y cloud-archive:ocata

sudo apt-get update
sudo apt-get install -y python-openstackclient
sudo apt-get install -y mariadb-server python-pymysql

echo "
[mysqld]
bind-address = 10.0.0.11
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" | sudo tee -a /etc/mysql/mariadb.conf.d/99-openstack.cnf
sudo service mysql restart
sudo mysql -uroot -h localhost -e "SHOW DATABASES"

sudo apt-get install -y rabbitmq-server
sudo rabbitmqctl add_user openstack welcome
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sudo apt-get install -y memcached python-memcache

sudo sed -i "s/-l 127.0.0.1/-l 10.0.0.11/g" /etc/memcached.conf
sudo service memcached restart

sudo mysql -uroot -h localhost -e "CREATE DATABASE keystone"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'welcome';"
sudo apt-get install -y keystone

# try sed here


# we have to use `|` as seperator
sudo sed -i "s|#connection = <None>|connection = mysql+pymysql://keystone:welcome@controller/keystone|g" /etc/keystone/keystone.conf
sudo sed -i "s|#provider = fernet|provider = fernet|g" /etc/keystone/keystone.conf

sudo su -s /bin/sh -c "keystone-manage db_sync" keystone
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

sudo keystone-manage bootstrap --bootstrap-password welcome \
                --bootstrap-admin-url http://controller:35357/v3/ \
                --bootstrap-internal-url http://controller:5000/v3/ \
                --bootstrap-public-url http://controller:5000/v3/ \
                --bootstrap-region-id RegionOne

echo "ServerName controller" | sudo tee -a /etc/apache2/apache2.conf
sudo service apache2 restart
sudo rm -f /var/lib/keystone/keystone.db

export OS_USERNAME=admin
export OS_PASSWORD=welcome
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack project list
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password welcome demo
openstack role create user
openstack role add --project demo --user demo user

export OS_USERNAME=demo
export OS_PASSWORD=welcome
export OS_PROJECT_NAME=demo
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack token issue

# glance
sudo mysql -uroot -h localhost -e "CREATE DATABASE glance"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'welcome';"


export OS_USERNAME=admin
export OS_PASSWORD=welcome
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack user create --domain default --password welcome glance
openstack role add --project service --user glance admin
openstack service create --name glance  --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292

sudo apt-get install -y glance

CONF_GLANCE_API=/etc/glance/glance-api.conf
sudo sed -i "s|#connection = <None>|connection = mysql+pymysql://glance:welcome@controller/glance|g" ${CONF_GLANCE_API}
sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_GLANCE_API}
sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_GLANCE_API}
sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_GLANCE_API}
sudo sed -i "s|#flavor = keystone|flavor = keystone|g" ${CONF_GLANCE_API}
sudo sed -i "s|#stores = file,http|stores = file,http|g" ${CONF_GLANCE_API}
sudo sed -i "s|#default_store = file|default_store = file|g" ${CONF_GLANCE_API}
sudo sed -i "s|#filesystem_store_datadir = /var/lib/glance/images|filesystem_store_datadir = /var/lib/glance/images/|g" ${CONF_GLANCE_API}


CONF_GLANCE_REG=/etc/glance/glance-registry.conf
sudo sed -i "s|#connection = <None>|connection = mysql+pymysql://glance:welcome@controller/glance|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_GLANCE_REG}
sudo sed -i "s|#flavor = keystone|flavor = keystone|g" ${CONF_GLANCE_REG}

sudo su -s /bin/sh -c "glance-manage db_sync" glance
sudo service glance-registry restart
sudo service glance-api restart

openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

# Install and configure controller node
# This section describes how to install and configure the Compute service, code-named nova, on the controller node

# Prerequisites (page 34)
sudo mysql -uroot -h localhost -e "CREATE DATABASE nova"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'welcome';"

sudo mysql -uroot -h localhost -e "CREATE DATABASE nova_api"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'welcome';"

sudo mysql -uroot -h localhost -e "CREATE DATABASE nova_cell0"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'welcome';"

# page 35
export OS_USERNAME=admin
export OS_PASSWORD=welcome
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

openstack user create --domain default --password welcome nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1

openstack user create --domain default --password welcome placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller/placement
openstack endpoint create --region RegionOne placement internal http://controller/placement
openstack endpoint create --region RegionOne placement admin http://controller/placement

# Install and configure components (page 40)
sudo apt-get install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api

CONF_NOVA=/etc/nova/nova.conf
sudo sed -i "s|connection=sqlite:////var/lib/nova/nova.sqlite|connection = mysql+pymysql://nova:welcome@controller/nova_api|g" ${CONF_NOVA}
sudo sed -i "s|#connection=<None>|connection = mysql+pymysql://nova:welcome@controller/nova|g" ${CONF_NOVA}
sudo sed -i "s|#transport_url=<None>|transport_url = rabbit://openstack:welcome@controller|g" ${CONF_NOVA}
sudo sed -i "s|#auth_strategy=keystone|auth_strategy=keystone|g" ${CONF_NOVA}

sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_NOVA}
sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_NOVA}
sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_NOVA}
sudo sed -i "s|^#my_ip.*|my_ip = 10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#use_neutron=true|use_neutron=true|g" ${CONF_NOVA}
sudo sed -i "s|#firewall_driver=<None>|firewall_driver=nova.virt.firewall.NoopFirewallDriver|g" ${CONF_NOVA}
sudo sed -i "s|#vncserver_listen=127.0.0.1|vncserver_listen=10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#vncserver_proxyclient_address=127.0.0.1|vncserver_proxyclient_address=10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#api_servers=<None>|api_servers= http://controller:9292|g" ${CONF_NOVA}
sudo sed -i "s|lock_path=/var/lock/nova|lock_path=/var/lock/nova/tmp|g" ${CONF_NOVA}
sudo sed -i "s|^os_region_name.*|os_region_name = RegionOne|g" ${CONF_NOVA}
sudo sed -i "s|#project_domain_name=<None>|project_domain_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#project_name=<None>|project_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#auth_type=<None>|auth_type=password|g" ${CONF_NOVA}
sudo sed -i "s|#user_domain_name=<None>|user_domain_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#auth_url=<None>|auth_url=http://controller:35357/v3|g" ${CONF_NOVA}
sudo sed -i "s|#username =|username = placement|g" ${CONF_NOVA}
sudo sed -i "s|#password =|password = welcome|g" ${CONF_NOVA}

sudo su -s /bin/sh -c "nova-manage api_db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova

sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
sudo su -s /bin/sh -c "nova-manage db sync" nova
sudo nova-manage cell_v2 list_cells

sudo service nova-api restart
sudo service nova-consoleauth restart
sudo service nova-scheduler restart
sudo service nova-conductor restart
sudo service nova-novncproxy restart
