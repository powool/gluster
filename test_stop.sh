#!/bin/bash
docker stop $(docker ps | egrep -v 'gluster|NAMES' |awk '{print $NF;}')

