#!/bin/bash

# SYpanel installer
SY_VERSION="0.0.1" 

OS_NAME=$(lsb_release -si)
clear

echo "SYpanel $SY_VERSION";

echo 
# check if is ubuntu
if [ ${OS_NAME,,} != 'ubuntu' ]; then
	echo "SYpanel must be installed on Ubuntu only!";
	exit;
fi

echo "Installing..."