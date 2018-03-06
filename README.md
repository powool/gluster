As committed, this test works. If you remove the flock flag from test_one.sh, it
will rely on sqlite3 built in record locking. In this case, it works most of the time,
but still fails infrequently.

	Requirements: up to date docker and docker-compose - I had to build from source to update
	my Ubuntu 17.10 machine.

	To bring the 3 gluster servers up:

	./cluster_up.sh

	Once up, you can test a single sqlite run by doing this:

	./test_one.sh 1

	To test a series of sqlite test scripts, do this:

	./test.sh

	On my laptop, it takes about 30 seconds to run.

	Between tests, you can tweak the volume settings like this:

	docker exec gluster_node-1_1 /bin/bash -c "gluster volume set dockerstore performance.flush-behind off "

	To shut down the cluster, do this:

	./cluster_down.sh


The above by default runs with a file level lock (flock) that gates a set of transactions
to the shared database. To disable this, and allow sqlite3 to do its own locking, edit
the file test_one.sh and uncomment the line '# FILE_LOCK='

The expected result is that the php code will not issue any warnings or errors. You have to
watch the test to ensure this (I need to check returns from the queries - I will add this).

If you enable write-behind, it will frequently report that the database is mal-formed. It won't necessarily
do it every time, so increase the number of clients to stress it harder.
