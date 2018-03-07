#!/bin/bash

mountpoint /mnt >& /dev/null
if [ $? -ne 0 ] ; then
	echo "If you haven't already, make sure you have this line in fstab:"
	echo "/etc/glusterfs/dockerstore.vol /mnt glusterfs rw,noauto 0 0"
	echo "and also have the file /etc/glusterfs/dockerstore.vol with the contents:"
	cat <<EOF
volume remote1
type protocol/client
option transport-type tcp
option remote-host 172.18.0.3
option remote-subvolume /data/glusterfs/store/dockerstore
end-volume

volume remote2
type protocol/client
option transport-type tcp
option remote-host 172.18.0.4
option remote-subvolume /data/glusterfs/store/dockerstore
end-volume

volume remote3
type protocol/client
option transport-type tcp
option remote-host 172.18.0.2
option remote-subvolume /data/glusterfs/store/dockerstore
end-volume

volume replicate
type cluster/replicate
subvolumes remote1 remote2 remote3
end-volume
EOF
	echo "Mounting gluster in /mnt"
	sudo mount /mnt
fi

echo "force test container to be nice and fresh."
docker build -t sqlite_test_container .

SERVER_VERSION=$(docker exec gluster_node-1_1 gluster --version | head -1)
CLIENT_VERSION=$(docker run --rm sqlite_test_container glusterfs --version | head -1)

echo "Gluster server version: $SERVER_VERSION"
echo "Gluster client version: $CLIENT_VERSION"

echo "Remove db and lock file:"
sudo rm -rf /mnt/testfile.db /mnt/testfile.db.lock
# echo "truncate db file to size 0:"
# sudo truncate --size=0 /mnt/glusterfs/testfile.db 
sync 
echo "sleep 2"
sleep 2

# let the first one get the db setup - we're not trying
# to fix creation time races at the moment
sleepytime=1
for i in $(seq 0 9)
do
	./test_one.sh $i &
	sleep $sleepytime
	sleepytime=0
done
wait

sqlite3 /mnt/testfile.db 'PRAGMA integrity_check'

result=$(sqlite3 /mnt/testfile.db 'PRAGMA integrity_check')
if [ "$result" = "ok" ] ; then
	echo "yay, database checks out as ok!"
	exit 0
else
	echo "uh oh, bad database!!!"
	exit 1
fi
