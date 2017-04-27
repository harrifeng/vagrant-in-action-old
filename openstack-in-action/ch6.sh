# update the package we use mirror 163
sudo apt-get update

# change eth3 to eth3 VM network
sudo sed -i "s/iface eth3 inet static/iface eth3 inet manual/g" /etc/network/interfaces
sudo sed -i "s/address 172.16.0.51//g" /etc/network/interfaces
sudo sed -i "s/netmask 255.255.0.0//g" /etc/network/interfaces
sudo ifdown eth3 && sudo ifup eth3

ifconfig eth3

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install vlan bridge-utils

SYSCTL_CONF=/etc/sysctl.conf

echo "
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0" | sudo tee -a ${SYSCTL_CONF}

# enable the changes
sudo sysctl -p

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install openvswitch-switch
sudo lsmod | grep openvswitch

# Configure internal OVS bridge
sudo ovs-vsctl add-br br-int

# Configure external OVS bridge
sudo ovs-vsctl add-br br-ex

# Show the result
sudo ovs-vsctl show

# assign eth3 to br-ex
sudo ovs-vsctl add-port br-ex eth3
sudo ovs-vsctl br-set-external-id br-ex bridge-id br-ex
sudo ovs-vsctl show

sudo DEBIAN_FRONTEND=noninteractive apt-get -y install neutron-plugin-ml2 \
     neutron-plugin-openvswitch-agent \
     neutron-l3-agent \
     neutron-dhcp-agent


SERVICE_TENANT_ID=$(keystone  tenant-list | awk '/\ service\ / {print $2}')
NEUTRON_CONF=/etc/neutron/neutron.conf
echo "
[DEFAULT]
core_plugin = neutron.plugins.ml2.plugin.Ml2Plugin
service_plugins = router,firewall,lbaas,vpnaas,metering
allow_overlapping_ips = True

verbose = True
auth_strategy = keystone
rpc_backend = neutron.openstack.common.rpc.impl_kombu
rabbit_host = 192.168.2.50
rabbit_password = guest

nova_url = http://127.0.0.1:8774/v2
nova_admin_username = admin
nova_admin_password = openstack1
nova_admin_tenant_id = ${SERVICE_TENANT_ID}
nova_admin_auth_url = http://10.33.2.50:35357/v2.0

[keystone_authtoken]
auth_url =  http://10.33.2.50:35357/v2.0
admin_tenant_name = service
admin_password = openstack1
auth_protocol = http
admin_user = neutron
[database]
connection = mysql://neutron_dbu:openstack1@192.168.2.50/neutron" | sudo tee -a ${NEUTRON_CONF}


ML2_CONF=/etc/neutron/plugins/ml2/ml2_conf.ini
echo "
[ml2]
type_drivers = gre
tenant_network_types = gre
mechanism_drivers = openvswitch
[ml2_type_gre]
tunnel_id_ranges = 1:1000
[ovs]
local_ip = 192.168.2.51
tunnel_type = gre
enable_tunneling = True
[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True" | sudo tee -a ${ML2_CONF}

sudo service neutron-plugin-openvswitch-agent restart


L3_CONF=/etc/neutron/l3_agent.ini
echo "
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
use_namespaces = True
verbose = True" | sudo tee -a ${L3_CONF}

sudo service neutron-l3-agent restart

DHCP_CONF=/etc/neutron/dhcp_agent.ini
echo "
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
use_namespaces = True" | sudo tee -a ${DHCP_CONF}

sudo service neutron-dhcp-agent restart


METADATA_CONF=/etc/neutron/metadata_agent.ini
echo "
[DEFAULT]
auth_url =  http://10.33.2.50:35357/v2.0
auth_region = RegionOne
admin_tenant_name = service
admin_password = openstack1
auth_protocol = http
admin_user = neutron
nova_metadata_ip = 192.168.2.50
metadata_proxy_shared_secret = openstack1" | sudo tee -a ${METADATA_CONF}

sudo service neutron-metadata-agent restart

export OS_USERNAME=admin
export OS_PASSWORD=openstack1
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://10.33.2.50:5000/v2.0

SERVICE_TENANT_ID=$(keystone  tenant-list | awk '/\ service\ / {print $2}')
neutron net-create --tenant-id=${SERVICE_TENANT_ID} INTERNAL_NETWORK

neutron subnet-create --tenant-id=${SERVICE_TENANT_ID} INTERNAL_NETWORK 172.16.0.0/24

neutron router-create --tenant-id=${SERVICE_TENANT_ID} ADMIN_ROUTER

SUBNET_ID=$(neutron subnet-list | awk '/172/ {print $2}')
ROUTER_ID=$(neutron router-list | awk '/ADMIN_ROUTER/ {print $2}')

neutron router-interface-add ${ROUTER_ID} ${SUBNET_ID}

# create external network
neutron net-create PUBLIC_NETWORK --router:external=True

# create external subnet
neutron subnet-create \
        --gateway 192.168.12.1 \
        --allocation-pool start=192.168.12.100,end=192.168.12.250 \
        PUBLIC_NETWORK \
        192.168.12.0/24 \
        --enable_dhcp=False

SUBNET_192_ID=$(neutron subnet-list | awk '/192/ {print $2}')
NET_ID=$(neutron net-list | awk '/PUBLIC_NETWORK/ {print $2}')

neutron router-gateway-set ${ROUTER_ID} ${NET_ID}
