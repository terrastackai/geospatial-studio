#!/bin/bash

# Backward compatibility wrapper - calls unified deploy_studio.sh with ocp platform
export PLATFORM=ocp
exec ./deploy_studio.sh
