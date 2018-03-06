#!/bin/bash
echo "force test container to be nice and fresh."
docker build -t sqlite_test_container .

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
if [ "$result" != "ok" ] ; then
	echo "uh oh, bad database!!!" | lolcat
fi
