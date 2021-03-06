#!/bin/bash


# This script builds Docker-images for several Docker-files and creates a docker-compose.yml file for starting a complete dockerized test-environment
# The test-environment will be set up completly from scratch every time a new Dockerfile is added to the Git Repo

# create fresh docker-compose.yml file, containing just the inspectIT cmr
cp compose/compose-base.yml compose/docker-compose.yml

# Hostport which will be mapped to the port 8080 inside the created containers (incremented in loop)
HOST_HTTP_PORT=6780
JMETER_CONTAINER_LINKS="  links:"

# for-loop iterating over all "Dockerfile_<Appserver>" files (e.g. Dockerfile_jboss, Dockerfile_tomcat,...) in the current directory
# each found app-server specific Dockerfile will be copied to a file called just Dockerfile
# then a Dockerimage is created for the current Dockerfile and the image is added to a docker-compose.yml file
for i in $( ls | grep Dockerfile_ );
    do
	# get name of current app-server (needed for tagging the Image)
	APP_SERVER=${i#*_}
	echo -e "\nBuilding Dockerfile for: $APP_SERVER"

	# append current app-server to the links-section of jmeter container (docker-compose.yml skript)
	JMETER_CONTAINER_LINKS="${JMETER_CONTAINER_LINKS}\n   - ${APP_SERVER}"

	# copy the app-server specific Dockerfile (e.g. Dockerfile_jboss) to Dockerfile.
	# necessary, because Docker can only build images from files exactly called "Dockerfile"
        cp $i Dockerfile
	
        # build Docker-image
	echo Executing Command: docker build --tag=sbe/ticket-monster_$APP_SERVER:v$BUILD_NUMBER .
	docker build --tag=sbe/ticket-monster_$APP_SERVER:v$BUILD_NUMBER .
	# start Docker-container for current image
	#echo Executing Command: docker run -d -P --name ticket-monster_$APP_SERVER\_v$BUILD_NUMBER sbe/ticket-monster_$APP_SERVER:v$BUILD_NUMBER
	#docker run -d -P --name ticket-monster_$APP_SERVER\_v$BUILD_NUMBER sbe/ticket-monster_$APP_SERVER:v$BUILD_NUMBER


	# appending an entry in the docker-compose.yml file for the current image
        read -d '' COMPOSE_ENTRY <<- EOF
        $APP_SERVER:
	  image: sbe/ticket-monster_$APP_SERVER:v$BUILD_NUMBER
	  links:
	   - cmr
	  ports:
	   - \"$HOST_HTTP_PORT:8080\"
	  environment:
	   - AGENT_NAME=$APP_SERVER
	EOF
        echo -e "\n$COMPOSE_ENTRY" >> compose/docker-compose.yml


	# create JMeter test for each app-server from Template
        cp jmeter-tests/TEMPLATE.jmx jmeter-tests/http-requests_${APP_SERVER}.jmx
        sed -i -- "s/containerHostname/${APP_SERVER}/g" jmeter-tests/http-requests_${APP_SERVER}.jmx
        

	((HOST_HTTP_PORT++))

done

# build JMeter loadtest container
echo -e "\nBuilding Dockerfile for: JMeter container"
cp JMeter_Dockerfile Dockerfile
docker build --tag=sbe/jmeter:v$BUILD_NUMBER .

# appending an entry in the docker-compose.yml file for the JMeter image
# the above created JMeter tests are passed into this container as a volume
read -d '' COMPOSE_ENTRY <<- EOF
jmeter:
  image: sbe/jmeter:v$BUILD_NUMBER
  volumes:
   - /var/lib/jenkins/workspace/Docker_test-environment_set_up/jmeter-tests/:/jmeter-tests/
EOF
echo -e "\n$COMPOSE_ENTRY\n${JMETER_CONTAINER_LINKS}" >> compose/docker-compose.yml


# cleanup the created Dockerfile
rm Dockerfile



