class { 'openshift_origin' :
      roles => ['broker','named','activemq','datastore','node'],

      broker_hostname            => '{{broker_internal}}',
      named_hostname             => '{{broker_internal}}',
      datastore_hostname         => '{{broker_internal}}',
      activemq_hostname          => '{{broker_internal}}',
      node_hostname              => 'broker.{{domain}}',
      node_ip_addr               => '{{broker_ip}}',

      bind_key                   => '{{bind_key}}',
      domain                     => '{{domain}}',
      register_host_with_named   => false,
      conf_named_upstream_dns    => ['172.31.0.2'], # fixed VPC DNS

      broker_auth_plugin         => 'htpasswd',
      openshift_user1            => 'openshift',
      openshift_password1        => 'password',

      install_method             => 'yum',
      repos_base                 => 'https://mirror.openshift.com/pub/origin-server/release/3/rhel-6',
      jenkins_repo_base          => 'http://pkg.jenkins-ci.org/redhat',

      development_mode           => true
}
