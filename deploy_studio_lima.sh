#!/bin/bash

# Backward compatibility wrapper - calls unified deploy_studio.sh with lima platform
export PLATFORM=lima
exec ./deploy_studio.sh
