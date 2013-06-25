### Configuration globale
Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/", "/opt/ruby/bin/" ] }

File { 	owner  => 'root',
		group => 'root',
		mode  => 644 
	 }
###

node default {

	$hostaddress = '192.168.33.7'
	$java_package = 'openjdk-7-jre-headless'
	$elasticsearch_deb = 'elasticsearch-0.90.1.deb'
	$logstash_jar = 'logstash-1.1.13-flatjar.jar'

	apt::source { 'puppetlabs':
	  location   => 'http://apt.puppetlabs.com',
	  repos      => 'main',
	  key        => '4BD6EC30',
	  key_server => 'pgp.mit.edu',
	}
	
	apt::ppa { "ppa:webupd8team/java": }

	class { 'apt':
	  always_apt_update    => true,
	}
	
	package { "${java_package}":
      ensure  => present
    }
	
	wget::fetch { 'download:elasticsearch':
	  source      => "https://download.elasticsearch.org/elasticsearch/elasticsearch/${elasticsearch_deb}",
	  destination => "/tmp/${elasticsearch_deb}",
	  timeout     => 0,
	  verbose     => true,
	}
	
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
	
	exec { 'install_plugin_head':
	  command => "/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head",
	  require => [ Package["elasticsearch"] ]
	}
	
	file { '/var/www':
	  ensure => directory,
	  recurse => true
	}
	
	class { 'nginx': }
	
	nginx::resource::vhost { 'logserver':
       ensure   => present,
       #proxy  => 'http://logserver.blog.fr',
	   www_root => '/var/www',
	   require => File['/var/www']
    }
	
	# nginx::resource::upstream { 'logserver.blog.fr':
	   # ensure  => present,
	   # members => [
         # "${hostaddress}:9200",
       # ],
    # }
	
	wget::fetch { 'download:kibana':
	  source      => "https://github.com/elasticsearch/kibana/archive/master.tar.gz",
	  destination => "/tmp/master.tar.gz",
	  timeout     => 0,
	  verbose     => true,
	}
	
	file { '/opt/kibana':
	  ensure => directory,
	  recurse => true
	}
	
	archive { '/tmp/master.tar.gz':
      ensure => unpacked,
	  compression => 'gz',
	  source => [],
	  cwd => '/opt/kibana',
      creates => '/opt/kibana/master.tar.gz.unpacked',
	  require => [ File['/opt/kibana'], Exec['wget-download:kibana'] ]
    }
	
	file { '/var/www/kibana':
	  ensure => link,
	  target => '/opt/kibana/kibana-master',
	  require => Archive['/tmp/master.tar.gz']
	}
	
	class { 'redis': version => '2.6.14' } 
	
	file { '/opt/logstash':
	  ensure => directory, # so make this a directory
	  recurse => true, # enable recursive directory management
	}
	
	wget::fetch { "download:logstash":
	  source      => "https://logstash.objects.dreamhost.com/release/${logstash_jar}",
	  destination => "/opt/logstash/${logstash_jar}",
	  timeout     => 0,
	  verbose     => true,
	  require     => File['/opt/logstash']
	}
	
	file { '/etc/logstash':
	  ensure => directory
	}
	
	file { '/var/log/logstash':
	  ensure => directory
	}
	
	file { '/etc/default/logstash-logstash::service':
	  ensure => file,
	  content => 
	  "START=true\nNICE=0"
	}
	
	class { 'logstash':
      multi_instance => false,
	  provider => 'custom',
	  jarfile => "/opt/logstash/${logstash_jar}",
	  require => [ Exec['wget-download:logstash'], Package["${java_package}"], File['/etc/default/logstash-logstash::service'] ]
    }
	
	file { '/etc/logstash/conf.d/indexer.conf':
	  ensure => file,
	  source  => "puppet:///files/logstash/logstash-indexer.conf",
	  require => File['/etc/logstash/conf.d'],
	  notify => Service['logstash']
	}
	
	
}


