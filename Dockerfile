FROM php:cli
RUN apt-get update
RUN apt-get --assume-yes install glusterfs-client
RUN apt-get --assume-yes install iputils-ping
RUN apt-get --assume-yes install iproute2
RUN apt-get --assume-yes install strace
# RUN apt-get --assume-yes install fuse
RUN mkdir -v /etc/glusterfs
COPY fstab /etc/fstab
COPY dockerstore.vol /etc/glusterfs
COPY sqlite_tester_flock.php /usr/bin
