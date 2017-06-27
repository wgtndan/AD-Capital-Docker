#! /bin/bash

# Docker container version
if [ -z "$1" ]; then
        export VERSION="latest";
else
        export VERSION=$1;
fi
echo "Using version: $VERSION"

if [ -z "$APP_NAME" ]; then
  echo "Environment variable: APP_NAME must be set"
else 
  echo "Application Name: $APP_NAME"
fi

echo -n "adcapitaldb: "; docker run --name adcapitaldb -e MYSQL_ROOT_PASSWORD=welcome1 -p 3306:3306 -d mysql
echo -n "rabbitmq: "; docker run -d --name rabbitmq -e RABBITMQ_DEFAULT_USER=guest -e RABBITMQ_DEFAULT_PASS=guest \
        -p 5672:5672 -p 15672:15672 rabbitmq:3.5.4-management
sleep 10

echo -n "rest: "; docker run --name rest -h ${APP_NAME}-rest -e create_schema=true -e rest=true -p 8081:8080\
	-e ACCOUNT_NAME=${ACCOUNT_NAME} -e ACCESS_KEY=${ACCESS_KEY} -e EVENT_ENDPOINT=${EVENT_ENDPOINT} \
	-e CONTROLLER=${CONTR_HOST} -e APPD_PORT=${CONTR_PORT} \
	-e APP_NAME=${APP_NAME} -e NODE_NAME=${APP_NAME}_REST_NODE -e TIER_NAME=Authentication-Services \
	--link adcapitaldb:adcapitaldb -d appdynamics/adcapital-tomcat:$VERSION
sleep 10

echo -n "portal: "; docker run --name portal -h ${APP_NAME}-portal -e portal=true -p 8082:8080\
	-e ACCOUNT_NAME=${ACCOUNT_NAME} -e ACCESS_KEY=${ACCESS_KEY} \
	-e CONTROLLER=${CONTR_HOST} -e APPD_PORT=${CONTR_PORT} -e EVENT_ENDPOINT=${EVENT_ENDPOINT} \
	-e APP_NAME=${APP_NAME} -e NODE_NAME=${APP_NAME}_PORTAL_NODE -e TIER_NAME=Portal-Services \
	--link rest:rest --link rabbitmq:rabbitmq -d appdynamics/adcapital-tomcat:$VERSION
sleep 10

echo -n "verification: "; docker run --name verification -h ${APP_NAME}-verification -p 8083:8080\
	-e ACCOUNT_NAME=${ACCOUNT_NAME} -e ACCESS_KEY=${ACCESS_KEY} \
	-e CONTROLLER=${CONTR_HOST} -e APPD_PORT=${CONTR_PORT} -e EVENT_ENDPOINT=${EVENT_ENDPOINT} \
	-e APP_NAME=${APP_NAME} -e NODE_NAME=${APP_NAME}_VERIFICATION_NODE -e TIER_NAME=ApplicationProcessor-Services \
	--link adcapitaldb:adcapitaldb --link rabbitmq:rabbitmq -d appdynamics/adcapital-applicationprocessor:$VERSION
sleep 10

echo -n "processor: "; docker run --name processor -h ${APP_NAME}-processor -e processor=true -p 8084:8080\
	-e ACCOUNT_NAME=${ACCOUNT_NAME} -e ACCESS_KEY=${ACCESS_KEY} \
	-e CONTROLLER=${CONTR_HOST} -e APPD_PORT=${CONTR_PORT} -e EVENT_ENDPOINT=${EVENT_ENDPOINT} \
	-e APP_NAME=${APP_NAME} -e NODE_NAME=${APP_NAME}_PROCESSOR_NODE -e TIER_NAME=LoanProcessor-Services \
	--link adcapitaldb:adcapitaldb --link rabbitmq:rabbitmq -d appdynamics/adcapital-tomcat:$VERSION
sleep 10

echo -n "queuereader: "; docker run --name queuereader -h ${APP_NAME}-queuereader -p 8085:8080\
  	-e ACCOUNT_NAME=${ACCOUNT_NAME} -e ACCESS_KEY=${ACCESS_KEY} \
  	-e CONTROLLER=${CONTR_HOST} -e APPD_PORT=${CONTR_PORT} -e EVENT_ENDPOINT=${EVENT_ENDPOINT} \
  	-e APP_NAME=${APP_NAME} -e NODE_NAME=${APP_NAME}_QUEUEREADER_NODE -e TIER_NAME=QueueReader-Services \
  	--link rabbitmq:rabbitmq -d appdynamics/adcapital-queuereader:$VERSION
	sleep 10

echo -n "adcapitalload: "; docker run --name=adcapitalload --link portal:portal --link processor:processor -d appdynamics/adcapital-load

echo -n "monitor: "; docker run --name=monitor -h ${APP_NAME}-monitor -p 9090:9090 \
        --volume=/:/hostroot:ro -v /var/run/docker.sock:/var/run/docker.sock \
        -e APPD_ACCOUNT_NAME=${APPD_ACCOUNT_NAME} -e APPD_ACCESS_KEY=${APPD_ACCESS_KEY} \
        -e APPD_HOST=${APPD_HOST} -e APPD_PORT=${APPD_PORT} -e APPD_SSL_ENABLED=${APPD_SSL_ENABLED} \
        -d appdynamics/adcapital-monitor:$VERSION
