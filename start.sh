#!/bin/bash
export PATH=$PATH:/usr/local/openjdk-8/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
java -version
mvn -version
ls -al /apps
java -jar /apps/application.jar
