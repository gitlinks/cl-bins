#!/usr/bin/env bash

echo
echo "Installing Gitlinks CLI, Hermes"

INSTALL_FOLDER=~/.gitlinks

current_dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

if [ ! -d "$INSTALL_FOLDER" ]; then
	mkdir $INSTALL_FOLDER
fi

cd "$INSTALL_FOLDER"
curl -OsSf https://gitlinks.github.io/cl-bins/latest/hermes-cl.tar.gz
tar -xzf $INSTALL_FOLDER/hermes-cl.tar.gz
cd $current_dir

echo
echo "Retrieving system info:"
echo
echo "os-release:"
for i in $(ls /etc/*release); do echo ===$i===; cat $i; done || true
echo
echo "ostype:"
echo ${OSTYPE}
echo
echo
echo "/etc/issue:"
cat /etc/issue || true
echo
echo "hostnamectl:"
hostnamectl || true
echo
echo "lsb_release:"
lsb_release -a || true
echo
echo "uname:"
uname -a || true
echo
echo "ldd:"
ldd $INSTALL_FOLDER"/hermes-rust-ci" || true
echo
echo "ldconfig:"
ldconfig -p | grep libssl || true
ldconfig -p | grep libz || true
echo

echo
echo "Done!"
echo
echo "Run with: $INSTALL_FOLDER/hermes-rust-ci"
echo
