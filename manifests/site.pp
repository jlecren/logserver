####################################################################################
# 
# Logserver 
#
# This node contains a simple stack for a centralized log server :
# - Redis (message queue)
# - Elasticsearch(search / storage)
# - Logstash (agent / indexer)
# - Kibana (Viewer)
#
####################################################################################

### Global settings

# Define the PATH for the execution of puppet
Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/", "/opt/ruby/bin/" ] }

# Set the default user used to install those components
File {
  owner  => 'root',
  group => 'root',
  mode  => 644 
}
     
### Node logserver

node logserver {

  ## Sets some custom parameters
  $hostaddress       = '192.168.33.7'                # Ip set in vagrant (maybe set by facter as well)
  $java_package      = 'openjdk-7-jre-headless'      # Java package
  $elasticsearch_deb = 'elasticsearch-0.90.1.deb'    # Elasticsearch package
  $logstash_jar      = 'logstash-1.1.13-flatjar.jar' # Logstash library

  ## Configures APT ##
  
  # Sets the Puppet repository
  apt::source { 'puppetlabs':
    location   => 'http://apt.puppetlabs.com',
    repos      => 'main',
    key        => '4BD6EC30',
    key_server => 'pgp.mit.edu',
  }
    
  # Adds the repository for the JDK
  apt::ppa { "ppa:webupd8team/java": }

  # Sets APT to refresh its base at each launch
  class { 'apt':
    always_apt_update    => true,
  }
  
  # Gets the Java runtime
  package { "${java_package}":
    ensure  => present
  }
    
  ## Elasticsearch ##
  
  # Downloads elasticsearch
  wget::fetch { 'download:elasticsearch':
    source      => "https://download.elasticsearch.org/elasticsearch/elasticsearch/${elasticsearch_deb}",
    destination => "/tmp/${elasticsearch_deb}",
    timeout     => 0,
    verbose     => true,
  }
  
  # Installs and sets up elasticsearch
  class { 'elasticsearch':
    version => 'latest',
    pkg_source => "/tmp/${elasticsearch_deb}",
    config                   => {
      'node'                 => {
        'name'               => 'logserver1'
      },
      'index'                => {
        'number_of_replicas' => '0',
        'number_of_shards'   => '5'
      },
      'network'              => {
        'host'               => "${hostaddress}"
      },
      'cluster'              => {
        'name'               => "centrallog"
      }
    },
    require => [ Exec['wget-download:elasticsearch'], Package["${java_package}"] ]
  }
    
  # Installs the elasticsearch UI plugin : head
  exec { 'install_plugin_head':
    command => "/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head",
    require => [ Package["elasticsearch"] ]
  }
    
  ## Kibana ##
  
  # Prepares the folder for the web server
  file { '/var/www':
    ensure => directory,
    recurse => true
  }
  
  # Installs the web server
  class { 'nginx': }
  
  # Creates a virtual host for the logserver
  nginx::resource::vhost { 'logserver':
    ensure   => present,
    #proxy  => 'http://logserver.blog.fr',
    www_root => '/var/www',
    require => File['/var/www']
  }
    
  # Creates a proxy for elasticsearch
  # nginx::resource::upstream { 'logserver.blog.fr':
    # ensure  => present,
    # members => [
      # "${hostaddress}:9200",
    # ],
  # }
    
  # Downloads kibana
  wget::fetch { 'download:kibana':
    source      => "https://github.com/elasticsearch/kibana/archive/master.tar.gz",
    destination => "/tmp/master.tar.gz",
    timeout     => 0,
    verbose     => true,
  }
    
  # Prepares the installation folder for Kibana
  file { '/opt/kibana':
    ensure => directory,
    recurse => true
  }
    
  # Unpacks the archive
  archive { '/tmp/master.tar.gz':
    ensure => unpacked,
    compression => 'gz',
    source => [],
    cwd => '/opt/kibana',
    creates => '/opt/kibana/master.tar.gz.unpacked',
    require => [ File['/opt/kibana'], Exec['wget-download:kibana'] ]
  }
    
  # Creates a link 'kibana' on the folder previously unpacked archive
  file { '/var/www/kibana':
    ensure => link,
    target => '/opt/kibana/kibana-master',
    require => Archive['/tmp/master.tar.gz']
  }
    
  ## Redis ##
  
  # Installs redis
  class { 'redis': version => '2.6.14' } 
  
  ## Logstash ##
    
  # Prepares the installation folder for logstash
  file { '/opt/logstash':
    ensure => directory,
    recurse => true,
  }
    
  # Downloads Logstash
  wget::fetch { "download:logstash":
    source      => "https://logstash.objects.dreamhost.com/release/${logstash_jar}",
    destination => "/opt/logstash/${logstash_jar}",
    timeout     => 0,
    verbose     => true,
    require     => File['/opt/logstash']
  }
    
  # Ensures the configuration folder is created
  file { '/etc/logstash':
    ensure => directory
  }
    
  # Ensures the log folder is created
  file { '/var/log/logstash':
    ensure => directory
  }
    
  # Sets the defaults for the indexer daemon
  file { '/etc/default/logstash-logstash::service':
    ensure => file,
    content => 
    "START=true\nNICE=0" # Start the indexer daemon and the its priority to high (0)
  }
    
  # Installs the logstash daemon
  class { 'logstash':
    multi_instance => false,
    provider => 'custom',
    jarfile => "/opt/logstash/${logstash_jar}",
    require => [ Exec['wget-download:logstash'], Package["${java_package}"], File['/etc/default/logstash-logstash::service'] ]
  }
    
  # Set the indexer configuration file and restarts the daemon
  file { '/etc/logstash/conf.d/indexer.conf':
    ensure => file,
    source  => "puppet:///files/logstash/logstash-indexer.conf",
    require => File['/etc/logstash/conf.d'],
    notify => Service['logstash']
  }
}


