This script deploys 2-node [OpenShift Origin] on Fedora 19 to Amazon WS via [Puppet](http://openshift.github.io/documentation/oo_deployment_guide_puppet.html).

You must have Bash and Perl installed. Perl is for Timkay's [AWS tool](https://github.com/timkay/aws).

CentOS 6 script lives in [centos](https://github.com/arkadijs/openshift-inception/tree/centos) branch. The PHP, Ruby runtimes supplied in EL are noticeable older than those provided by Fedora, thus some quickstarts won't work. Also, no JBoss.

[OpenShift Origin]: http://openshift.github.io/documentation/
