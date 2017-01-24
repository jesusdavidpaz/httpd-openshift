#!/bin/bash

# setup directory for data
mkdir -p /data
chown -R httpd:0 /data
chmod g+w -R /data
chown -R httpd:0 /usr
chown -R httpd:0 /var

chgrp -R 0 /usr
chmod -R g+rw /usr
find /usr -type d -exec chmod g+x {} +

chgrp -R 0 /var
chmod -R g+rw /var
find /var -type d -exec chmod g+x {} +

