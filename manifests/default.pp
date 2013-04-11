# LAMP Puppet manifest

Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

class system-update 
{
    file { "/etc/apt/sources.list.d/dotdeb.list":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/puppet/conf/apt/dotdeb.list",
    }

    exec { 'dotdeb-apt-key':
        cwd     => '/tmp',
        command => "wget http://www.dotdeb.org/dotdeb.gpg -O dotdeb.gpg && cat dotdeb.gpg | apt-key add -",
        unless  => 'apt-key list | grep dotdeb',
        require => File['/etc/apt/sources.list.d/dotdeb.list'],
        notify  => Exec['apt_update'],
    }

	exec { 'apt-get update':
		command => 'apt-get update',
	}

	$sysPackages = [ "build-essential" ]
  
	package { $sysPackages:
		ensure => "installed",
		require => Exec['apt-get update'],
	}			
}

class setup-development
{
	$devPackages = [ "curl", "git" ]

	package { $devPackages:
		ensure => "installed",
		require => Exec['apt-get update'],
	}
}

class setup-apache
{
	include apache
	
	a2mod { 'rewrite': ensure => present; }
	
	apache::vhost { $fqdn :
		priority => '20',
		port => '80',
		docroot => $docroot,
		configure_firewall => false,
		override => 'FileInfo',

	}
}

class setup-mysql
{
	class { 'mysql':
		root_password => 'password',
		port => 3306
	}
}

class setup-mongodb
{
	class { 'mongodb': }

	exec { 'allow remote mongo connections':
		command => "/usr/bin/sudo sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/g' /etc/mongodb.conf",
		notify  => Service['mongodb'],
		onlyif  => '/bin/grep -qx  "bind_ip = 127.0.0.1" /etc/mongodb.conf',
	}
}

class setup-php
{
	#include php
	
	class { 'php':
		module_prefix => 'php-'
	}
			
	class {'apache::mod::php': }
		
	$extensions = ['xdebug', 'mysql', 'curl', 'gd']
	
	php::module { $extensions : 
		notify => Service['httpd'],
		module_prefix => 'php5-'
	}
	
	php::module { 'pear':
		module_prefix => 'php-'
	}

	exec { 'pecl-mongo-install':
        command => 'pecl install mongo',
        unless => 'pecl info mongo',
        notify => Service['httpd'],
        require => Package['php-pear'],
    }
	
	file { '/etc/php5/conf.d/mongo.ini':
        owner  => root,
        group  => root,
        mode   => 664,
        source => '/vagrant/puppet/conf/mongo.ini',
        require => Package['php'],
        notify => Service['httpd'],
    }
}

class { 'apt':
  always_apt_update => true
}

Exec["apt-get update"] -> Package <| |>

include system-update
include setup-development

include setup-apache
include setup-mysql
include setup-mongodb
include setup-php