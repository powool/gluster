# you can also use 'FROM debian'
FROM php:cli
# use up to date gluster.org built packages
RUN apt-get update

# this is key - you can't install gluster packages without it:
RUN apt-get --assume-yes install apt-transport-https
RUN apt-get --assume-yes install wget gnupg gnupg1 gnupg2
RUN wget -O - http://download.gluster.org/pub/gluster/glusterfs/3.13/rsa.pub | apt-key add -
RUN echo deb [arch=amd64] https://download.gluster.org/pub/gluster/glusterfs/3.13/LATEST/Debian/stretch/amd64/apt stretch main > /etc/apt/sources.list.d/gluster.list
RUN apt-get update

# now install gluster fs client code and a few other fun things
RUN apt-get --assume-yes install glusterfs-client
RUN apt-get --assume-yes install iputils-ping
RUN apt-get --assume-yes install iproute2
RUN apt-get --assume-yes install strace

# setup to mount gluster fs
RUN mkdir -pv /etc/glusterfs
COPY fstab /etc/fstab
COPY dockerstore.vol /etc/glusterfs

# copy our test php file in
COPY sqlite_tester_flock.php /usr/bin
