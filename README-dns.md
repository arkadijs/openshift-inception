By default DNS is disabled in Cloud-in-a-Box. One of the downsides is that Eucalyptus DHCP server will push 127.0.0.1 (why-why-why?) as first nameserver to VMs and that will make SSH slow.

Enable instance DNS and DNS delegation so it looks more like real AWS. For example, assuming 192.168.100.2 is an IP of Cloud-in-a-Box:

    euca-modify-property -p system.dns.nameserveraddress=192.168.100.2
    euca-modify-property -p system.dns.dnsdomain=cloud.lan
    euca-modify-property -p bootstrap.webservices.use_instance_dns=true
    euca-modify-property -p bootstrap.webservices.use_dns_delegation=true

Configure your local nameserver to delegate `cloud.lan` subdomain resolution to Cloud Controller DNS service - add `address=/cloud.lan/192.168.100.2` to your workstation `dnsmasq.conf`:

    $ cat >/etc/NetworkManager/dnsmasq.d/cloud.lan
    server=/cloud.lan/192.168.11.10
    ^D
    $

There are however potential problems:

1. Some old dnsmasq versions, like those shipped with DD-WRT may cause problems. Use your workstation dnsmasq or bind, unbound, etc. For dnsmasq add `listen-address=<eth0 IP>` to `/etc/NetworkManager/dnsmasq.d/`.
2. Eucalyptus recursive DNS server is broken and may cause random DNS resolution failures in VMs, doing `yum install` for example. So set `system.dns.nameserveraddress` to a proper DNS server that knows how to forward `cloud.lan` to Eucalyptus, and perform recursive resolution on it's own.

Also, edit `broker.pp` and `set conf_named_upstream_dns` to the same IP.

For details consult [Eucalyptus manual](https://www.eucalyptus.com/docs/eucalyptus/3.4/index.html#shared/setting_up_dns.html).
