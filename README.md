logserver
=========

Logserver with logstash / redis / elasticsearch / kibana, set up with puppet in a vagrant box

logstash (shipper) -> redis -> logstash (indexer) -> elasticsearch -> kibana

Requirements
------------

- Virtuabox >= 4.2.12
- Vagrant >= 1.2.2

Usage
-----

* Boot up vagrant (take some time the first time !)
	```sh
	cd vagrant
	vagrant up
	```

* Log in the VM
	```sh
	vagrant ssh
	```
(or on windows with a ssh client; ie. Putty)
	```sh
	ssh -l vagrant 192.168.33.7
	 pwd: vagrant
	```

* Launch a logstash agent for testing
	```sh
	cd /vagrant/logstash
	java -jar /opt/logstash/logstash-1.1.13-flatjar.jar agent -f logstash-shipper.conf
	```

Check the result
----------------

* Elasticsearch (Indexer)
	> http://192.168.33.7:9200/_plugin/head

* Kibana (Viewer)
	> http://192.168.33.7/kibana/index.html#/dashboard

* Redis (Message Queue)
	```sh
	redis-cli
	llen logstash (nb pending messages)
	lrange logstash 0 -1 (pending messages)
	```