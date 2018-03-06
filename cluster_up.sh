#!/bin/bash

# this script assumes we're in a directory named gluster, as docker-compose
# names nodes using this directory name.
wait_for_node() {
	NODE=$1
	while [ "$(docker ps | grep $1)" == "" ] ; do
		sleep 1
		echo "waiting for docker container $NODE"
	done

	while [ -z "$(docker exec $NODE /bin/bash -c 'ps -ax|grep glusterfsd')" ] ; do
			sleep 1
			echo "waiting for docker container $NODE glusterfsd"
	done

	echo "Yay! $1 is up!"
}

# example usage: is_volume_present dockerstore gluster_node-1-1
is_volume_present() {
	VOLUME=$1
	NODE=$2
	# this command omits the exec -it param because it causes stdio problems
	RESULT=$(docker exec $NODE /bin/bash -c "gluster volume status $VOLUME 2>&1")
	if [ -n $(echo "$RESULT" | grep "Volume $VOLUME does not exist") ] ; then echo "true" ; else echo "false" ; fi
}

docker-compose up >& docker_cluster.log &

wait_for_node gluster_node-1_1
wait_for_node gluster_node-2_1
wait_for_node gluster_node-3_1

# images are loaded, containers started, give them a teeny bit of time to finish starting
echo "sleeping to let gluster server containers start."
sleep 10

# at this point, we assume each gluster container is up, and that we can issue gluster control commands

# Init gluster nodes
docker exec gluster_node-1_1 /bin/bash -c 'gluster peer probe node-2 && gluster peer probe node-3 &&  gluster peer status'
docker exec gluster_node-2_1 /bin/bash -c 'gluster peer probe node-1 && gluster peer probe node-3 &&  gluster peer status'
docker exec gluster_node-3_1 /bin/bash -c 'gluster peer probe node-1 && gluster peer probe node-2 &&  gluster peer status'

# Get node IPs
NODE1=$(docker inspect gluster_node-1_1 | grep '"IPAddress"' | egrep -o "[0-9+\.]+")
NODE2=$(docker inspect gluster_node-2_1 | grep '"IPAddress"' | egrep -o "[0-9+\.]+")
NODE3=$(docker inspect gluster_node-3_1 | grep '"IPAddress"' | egrep -o "[0-9+\.]+")

if [ "$(is_volume_present dockerstore gluster_node-1_1)" = "false" ] ; then
	# Init dockerstore volume
	docker exec gluster_node-1_1 /bin/bash -c \
	"gluster volume create dockerstore replica 3 $NODE1:/data/glusterfs/store/dockerstore $NODE2:/data/glusterfs/store/dockerstore $NODE3:/data/glusterfs/store/dockerstore"

	# Set mandatory optimal locks
	docker exec gluster_node-1_1 /bin/bash -c "gluster volume set dockerstore locks.mandatory-locking optimal"

	# this is critical to prevent flush from returning before it is done:
	docker exec gluster_node-1_1 /bin/bash -c "gluster volume set dockerstore performance.flush-behind off "

	# prevent writes from being cached:
	docker exec gluster_node-1_1 /bin/bash -c "gluster volume set dockerstore performance.write-behind off "

	# Start volume
	docker exec gluster_node-1_1 /bin/bash -c 'gluster volume start dockerstore'
	docker exec gluster_node-1_1 /bin/bash -c 'gluster volume info && gluster volume status'
fi

# Install plugin if not already installed.
# (NB: If things are messed up, remove the plugin volume, and disable, then remove the plugin.)
if [ -z "$(docker plugin ls|grep sapk/plugin-gluster)" ] ; then
	echo "Installing and enabling sapk/plugin-gluster plugin."
	docker plugin install --grant-all-permissions sapk/plugin-gluster
fi
# only enable if installed
if [ -n "$(docker plugin ls|egrep 'sapk/plugin-gluster.*false')" ] ; then
	echo "Enabling sapk/plugin-gluster plugin"
	docker plugin enable sapk/plugin-gluster
fi
# create if not already created
if [ -z "$(docker volume ls | grep dockerstore)" ] ; then
	echo "Creating dockerstore plugin volume."
	docker volume create --driver sapk/plugin-gluster --opt voluri="$NODE1,$NODE2,$NODE3:dockerstore" --name dockerstore
fi
