#!/bin/bash
QUERY_COUNT=30

# set to -f to add flock() wrapper around all db connections:
FILE_LOCK=-f
# FILE_LOCK=

INSTANCE_NUMBER=${1:-1}

# set to strace -f to see full call trace:
STRACE=

docker run --privileged --network gluster_netgluster --rm -i sqlite_test_container /bin/bash -c "mount /mnt && sleep 1 && $STRACE php /usr/bin/sqlite_tester_flock.php $FILE_LOCK -i $INSTANCE_NUMBER -n $QUERY_COUNT && umount /mnt"
