class { 'openshift_origin' :
      roles => ['node'],

      named_ip_addr              => '{{broker_internal_ip}}',
      bind_key                   => '{{bind_key}}',
      domain                     => '{{domain}}',
      register_host_with_named   => true,

      broker_hostname            => '{{broker_internal}}',
      activemq_hostname          => '{{broker_internal}}',
      node_hostname              => 'node{{i}}.{{domain}}',
      node_ip_addr               => '{{node_ip}}',

      install_method             => 'yum',
      repos_base                 => 'https://mirror.openshift.com/pub/origin-server/release/3/rhel-6',
      jenkins_repo_base          => 'http://pkg.jenkins-ci.org/redhat',

      development_mode           => true
}
