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
server controller iburst
" | sudo tee -a /etc/chrony/chrony.conf

sudo service chrony restart

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y cloud-archive:ocata

sudo apt update
sudo apt-get install -y python-openstackclient


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
openstack endpoint create --region RegionOne placement public http://controller/  placement
openstack endpoint create --region RegionOne placement internal http://controller/ placement
openstack endpoint create --region RegionOne placement admin http://controller/  placement

sudo apt-get install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api
