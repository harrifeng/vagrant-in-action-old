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
MYSQL_KEYSTONE_PASS=openstack1

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install keystone
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone_dbu'@'localhost' IDENTIFIED BY '$MYSQL_KEYSTONE_PASS';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone_dbu'@'%' IDENTIFIED BY '$MYSQL_KEYSTONE_PASS';"

KEYSTONE_CONF=/etc/keystone/keystone.conf
sudo sed -i "s#^connection.*#connection = mysql://keystone_dbu:openstack1@localhost:3306/keystone#" ${KEYSTONE_CONF}
# sudo sed -i 's/^#admin_token.*/admin_token = ADMIN/' ${KEYSTONE_CONF}
sudo sed -i 's,^#log_dir.*,log_dir = /var/log/keystone,' ${KEYSTONE_CONF}
sudo service keystone restart

keystone-manage bootstrap \
    --bootstrap-password s3cr3t \
    --bootstrap-username admin \
    --bootstrap-project-name admin \
    --bootstrap-role-name admin \
    --bootstrap-service-name keystone \
    --bootstrap-region-id RegionOne \
    --bootstrap-admin-url http://localhost:35357 \
    --bootstrap-public-url http://localhost:5000 \
    --bootstrap-internal-url http://localhost:5000
# sudo keystone-manage db_sync


#     glance \
#     glance-api \
#     glance-registry \
#     glance-common \
#     python-glanceclient \
#     cinder-api \
#     cinder-scheduler \
#     neutron-server \
#     nova-api \
#     nova-cert \
#     nova-conductor \
#     nova-consoleauth \
#     nova-novncproxy \
#     nova-scheduler \
#     python-novaclient \
#     openstack-dashboard \
#     memcached \
#     python-memcache \
#     mysql-server
# # Optionally, you can remove the Ubuntu theme, which has been reported to cause problems with some modules:
# sudo apt-get -y remove --purge openstack-dashboard-ubuntu-theme
# sudo rabbitmqctl change_password guest openstack1
# echo 'rabbitmq status------------------->'
# sudo rabbitmqctl status
# sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
# sudo service mysql restart
# echo 'mysql status---------------------->'
# sudo service mysql status
# echo 'keystone status---------------------->'
# id keystone
