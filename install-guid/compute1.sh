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


CONF_NOVA=/etc/nova/nova.conf
sudo sed -i "s|connection=sqlite:////var/lib/nova/nova.sqlite|connection = mysql+pymysql://nova:welcome@controller/nova|g" ${CONF_NOVA}
sudo sed -i "s|#connection=<None>|connection = mysql+pymysql://nova:welcome@controller/nova|g" ${CONF_NOVA}
sudo sed -i "s|#transport_url=<None>|#transport_url = rabbit://openstack:welcome@controller/nova|g" ${CONF_NOVA}
sudo sed -i "s|#auth_strategy=keystone|auth_strategy=keystone|g" ${CONF_NOVA}

sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_NOVA}
sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_NOVA}
sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_NOVA}
sudo sed -i "s|^#my_ip.*|my_ip = 10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#use_neutron=true|use_neutron=true|g" ${CONF_NOVA}
sudo sed -i "s|#firewall_driver=<None>|firewall_driver=nova.virt.firewall.NoopFirewallDriver|g" ${CONF_NOVA}
sudo sed -i "s|#vncserver_listen=127.0.0.1|vncserver_listen=10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#vncserver_proxyclient_address=127.0.0.1|vncserver_proxyclient_address=10.0.0.11|g" ${CONF_NOVA}
sudo sed -i "s|#api_servers=<None>|#api_servers= http://controller:9292|g" ${CONF_NOVA}
sudo sed -i "s|lock_path=/var/lock/nova|lock_path=/var/lock/nova/tmp|g" ${CONF_NOVA}
sudo sed -i "s|^os_region_name.*|os_region_name = RegionOne|g" ${CONF_NOVA}
sudo sed -i "s|#project_domain_name=<None>|project_domain_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#project_name=<None>|project_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#auth_type=<None>|auth_type=password|g" ${CONF_NOVA}
sudo sed -i "s|#user_domain_name=<None>|user_domain_name=Default|g" ${CONF_NOVA}
sudo sed -i "s|#auth_url=<None>|auth_url=http://controller:35357/v3|g" ${CONF_NOVA}
sudo sed -i "s|#username =|username = placement|g" ${CONF_NOVA}
sudo sed -i "s|#password =|password = welcome|g" ${CONF_NOVA}

sudo /bin/sh -c "nova-manage api_db sync" nova
sudo /bin/sh -c "nova-manage cell_v2 map_cell0" nova

sudo /bin/sh -c "nova-manage cell_v2 create_cell --name=cell 1 --verbose" nova 109e1d4b-536a-40d0-83c6-5f121b82b650
sudo /bin/sh -c "nova-manage db sync" nova
sudo nova-manage cell_v2 list_cells

sudo service nova-api restart
sudo service nova-consoleauth restart
sudo service nova-scheduler restart
sudo service nova-conductor restart
sudo service nova-novncproxy restart
