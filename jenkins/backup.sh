#!/bin/bash

# ./backup.sh AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY S3_BUCKET

NAME=jenkins-backup-$(date +"%Y%m%d_%H%M%S").tar

tar -cvf $NAME -C /home/ironjab/jenkins/jenkins_home .
AWS_ACCESS_KEY_ID=$1 AWS_SECRET_ACCESS_KEY=$2 aws s3 cp $NAME s3://$3/
rm -rf $NAME
