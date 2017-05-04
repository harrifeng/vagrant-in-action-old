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

sudo apt update
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
rabbitmqctl add_user openstack welcome
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sudo apt-get install -y memcached python-memcache

sudo sed -i "s/-l 127.0.0.1/-l 10.0.0.11/g" /etc/memcached.conf
sudo service memcached restart

sudo mysql -uroot -h localhost -e "CREATE DATABASE keystone"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'welcome';"
sudo mysql -uroot -h localhost -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'welcome';"
sudo apt-get install -y keystone

KEYSTONE_CONF=/etc/keystone/keystone.conf
sudo sed -i "s#^connection.*#connection=mysql+pymysql://keystone:welcome@controller/keystone#" ${KEYSTONE_CONF}
# sudo sed -i 's/^#admin_token.*/admin_token = ADMIN/' ${KEYSTONE_CONF}
# sudo sed -i 's,^#log_dir.*,log_dir = /var/log/keystone,' ${KEYSTONE_CONF}
# sudo service keystone restart
