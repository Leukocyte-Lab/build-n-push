#!/bin/sh

# Add Prviate Key
add_ssh_key() {
  mkdir -p ~/.ssh/
  echo $INPUT_SSH_PRIVATE_KEY > ~/.ssh/id_rsa
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
  if [ -n $INPUT_USERNAME ] && [ -n $INPUT_PASSWORD ]
  then 
    if [ -n $INPUT_REGISTRY ]
    then
      echo $INPUT_PASSWORD | docker login $INPUT_REGISTRY -u $INPUT_USERNAME --password-stdin
    else
      echo $INPUT_PASSWORD | docker login -u $INPUT_USERNAME --password-stdin
    fi
  else
    exit 1
  fi
}

# Docker build
docker_build() {
  docker build $PATH/Dockerfile
}

add_ssh_key
start_up_ssh_agent
docker_login
docker_build