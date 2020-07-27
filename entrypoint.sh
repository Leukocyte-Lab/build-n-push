#!/bin/sh

# Add Prviate Key
add_ssh_key() {
	mkdir -p ~/.ssh/
	echo -e "$INPUT_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
	chmod 600 ~/.ssh/id_rsa
	echo "SSH Key Installed"
}

# Start Up ssh-agent
start_up_ssh_agent() {
	eval `ssh-agent`
	ssh-add ~/.ssh/id_rsa
}

# Docker login
docker_login() {
	if [ -n "$INPUT_USERNAME" ] && [ -n "$INPUT_PASSWORD" ]
	then 
		if [ -n "$INPUT_REGISTRY" ]
		then
			echo "$INPUT_PASSWORD" | docker login "$INPUT_REGISTRY" -u "$INPUT_USERNAME" --password-stdin
		else
			echo "$INPUT_PASSWORD" | docker login -u "$INPUT_USERNAME" --password-stdin
		fi
	else
		exit 1
	fi
}

# Docker build
docker_build() {
	docker build $OPTION $INPUT_PATH
	if [ "$INPUT_PUSH" = true ]
	then
		if [ -n "$INPUT_REGISTRY" ]
		then
			if [ -n "$INPUT_TAGS" ]
			then
				echo $INPUT_TAGS | tr "," "\n" | while read TAG; do
					docker push "$INPUT_REGISTRY/$INPUT_REPOSITORY:$TAG"
				done
			else
				docker push "$INPUT_REGISTRY/$INPUT_REPOSITORY"
			fi
		else
			if [ -n "$INPUT_TAGS" ]
			then
				echo $INPUT_TAGS | tr "," "\n" | while read TAG; do
					docker push "$INPUT_REPOSITORY:$TAG"
				done
			else
				docker push "$INPUT_REPOSITORY"
			fi
		fi
	fi
}

# Option builder
opt_builder() {
	if [ -n "$INPUT_TAGS" ]
	then
		for TAG in $(echo $INPUT_TAGS | tr "," "\n"); do
			if [ -n "$INPUT_REGISTRY" ]
			then
				OPTION="$OPTION -t $INPUT_REGISTRY/$INPUT_REPOSITORY:$TAG"
			else
				OPTION="$OPTION -t $INPUT_REPOSITORY:$TAG"
			fi
		done
	fi 
	if [ -n "$INPUT_DOCKERFILE" ]
	then
		OPTION="$OPTION -f $INPUT_DOCKERFILE"
	fi
	if [ "$INPUT_SSH" = true ]
	then
		OPTION="--ssh default $OPTION"
	fi
}

if [ -n "$INPUT_SSH_PRIVATE_KEY" ]
then
	add_ssh_key
	start_up_ssh_agent
fi
docker_login
opt_builder
docker_build
