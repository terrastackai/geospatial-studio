#!/bin/bash

# Backward compatibility wrapper - calls unified deploy_studio.sh with k8s platform
export PLATFORM=k8s
exec ./deploy_studio.sh
