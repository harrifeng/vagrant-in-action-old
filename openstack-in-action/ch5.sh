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
         --pass=openstack2 \
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
         --pass="openstack3" \
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



glance --os-username=admin --os-password openstack2 \
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
