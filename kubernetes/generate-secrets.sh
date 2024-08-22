#!/bin/bash

# Generate a random SECRET_KEY
SECRET_KEY=$(openssl rand -hex 32)

# Prompt for MONGODB_URI
read -p "Enter MONGODB_URI: " MONGODB_URI

# Create the secret
kubectl create secret generic wiz-app-secrets \
  --from-literal=mongodb-uri=$MONGODB_URI \
  --from-literal=secret-key=$SECRET_KEY