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

sudo  /bin/sh -c "keystone-manage db_sync" keystone
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

openstack project list
