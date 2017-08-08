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
cat /etc/os-release || true
echo
echo "ostype:"
echo ${OSTYPE}
echo
echo "uname:"
uname -a
echo
echo "ldd:"
ldd $INSTALL_FOLDER"/hermes-rust-ci"
echo
echo "ldconfig:"
ldconfig -p | grep libssl
ldconfig -p | grep libz
echo

echo
echo "Done!"
echo
echo "Run with: $INSTALL_FOLDER/hermes-rust-ci"
echo
