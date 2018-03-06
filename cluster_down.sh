#!/bin/bash

# non-destructive removal of temporary containers:
docker-compose down

# disable plug-in to get a clean reset
echo "Removing dockerstore plugin - ignore up to two errors."
docker volume rm dockerstore 
docker plugin disable sapk/plugin-gluster:latest 
# don't remove the plugin, as re-install hits the network for 50-60MB
echo "Done removing and disasbling dockerstore plugin."

#
# optional: remove backing store:
if [ "$1" == "all" ] ; then
	read -p "Remove gluster filesystem data? [y|N] " REMOVE
	case "$REMOVE" in
		y|Y|yes|YES)
			sudo rm -rvf /data/docker/gluster-node*
			;;
		*)
			echo "Not removing fileserver data."
			;;
	esac
fi

echo "Done cleaning."
