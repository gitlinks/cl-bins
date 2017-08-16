#!/usr/bin/env bash


INSTALL_FOLDER=~/.gitlinks
CURRENT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

IMAGE_TGZ_NAME=hermes-cl.tar.gz

IMAGE_BINARY_NAME=hermes-rust-ci
IMAGE_BINARY_PATH=${INSTALL_FOLDER}/${IMAGE_BINARY_NAME}


# os info output, for analysing os-related issues
os_debug () {
    echo
    echo "* Retrieving operating system info:"
    echo

    echo
    echo "os-release:"
    for i in $(ls /etc/*release); do echo ===$i===; cat $i; done || true
    echo

    echo
    echo "ostype:"
    echo ${OSTYPE}
    echo

    echo
    echo "/etc/issue:"
    cat /etc/issue || true
    echo

    echo
    echo "hostnamectl:"
    hostnamectl || true
    echo

    echo
    echo "lsb_release:"
    lsb_release -a || true
    echo

    echo
    echo "uname:"
    uname -a || true
    echo

    echo
    echo "yum:"
    yum version || true
    echo

    echo
    echo "dpkg:"
    dpkg --version || true
    echo

    echo
    echo "ldd:"
    ldd "${INSTALL_FOLDER}""/hermes-rust-ci" || true
    echo

    echo
    echo "ldconfig libssl:"
    ldconfig -p | grep libssl || true
    echo

    echo
    echo "ldconfig libz:"
    ldconfig -p | grep libz || true
    echo

    echo
    echo "openssl:"
    openssl version || true
    echo
}

# install binary
install () {
    echo
    echo "* Installing Gitlinks CLI, Hermes"
    echo

    PREVIOUS_DIR=$(pwd)

    rm -rf "${INSTALL_FOLDER}"
    mkdir "${INSTALL_FOLDER}"

    cd "${INSTALL_FOLDER}"
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/${IMAGE_TGZ_NAME}
    tar -xzf "${INSTALL_FOLDER}"/${IMAGE_TGZ_NAME}
    rm "${INSTALL_FOLDER}"/${IMAGE_TGZ_NAME}

    cd "${PREVIOUS_DIR}"
}

# run installed binary
run () {
    echo
    echo "* Running Gitlinks CLI, Hermes"
    echo

    ${IMAGE_BINARY_PATH}
}

os_debug
install
run