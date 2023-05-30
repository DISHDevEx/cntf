#!/bin/bash

kubectl -n openverso exec -ti deployment/ueransim-gnb-ues -- /bin/bash
echo ip addr
ping -I uesimtun6 google.com
traceroute -i uesimtun6 google.com
curl --interface uesimtun6 https://www.google.com

if  [ $? -eq 0 ]
then
   echo "successful test"
   exit
else
   echo "test failed" 
fi

