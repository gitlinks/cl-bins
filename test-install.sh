#!/usr/bin/env bash

echo
echo "Installing Gitlinks CLI, Hermes"
echo

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

is_debian_based() {
    command -v dpkg >/dev/null 2>&1
    CHECK_DPKG=$?

    command -v apt-get >/dev/null 2>&1
    CHECK_APT_GET=$?

    if [ "${CHECK_DPKG}" -eq 0 ] && [ "${CHECK_APT_GET}" -eq 0 ]
    then
        >&2 echo "echoing true"
        echo true
    else
        >&2 echo "echoing false"
        echo false
    fi
}

is_redhat_based() {
    command -v yum >/dev/null 2>&1
    CHECK_YUM=$?

    if (( ${CHECK_YUM} == 0 ))
    then
        echo true
    else
        echo false
    fi
}

install_deb() {
    ARCH=$(get_architecture_specifier)
    DEB_NAME=hermes-rust-ci_latest_${ARCH}.deb

    cd /tmp
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/${DEB_NAME}

    sudo apt-get update
    sudo apt-get remove -y hermes-rust-ci || true
    sudo dpkg -i "${DEB_NAME}"
    sudo apt-get -fyq install
}

install_rpm() {
    ARCH=$(get_architecture_specifier)
    RPM_NAME=hermes-rust-ci_latest_${ARCH}.rpm

    cd /tmp
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/${RPM_NAME}

    sudo yum remove -y hermes-rust-ci
    sudo yum install -y "${RPM_NAME}"
}

get_architecture_specifier() {
    if [ $(uname -m) = "x86_64" ]
    then
        echo "x64"
    else
        echo "x32"
    fi
}

check_installation() {
    if [ ! -f /opt/gitlinks/hermes-rust-ci ]; then
        echo "hermes-rust-ci was not installed in /opt/gitlinks !"
        exit 0
    fi
}

# os info output, for analysing os-related issues
os_debug () {
    echo
    echo "* Retrieving operating system info:"
    echo

    echo
    echo "whoami:"
    whoami || true
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
    yum --version || true
    echo

    echo
    echo "apt-get:"
    apt-get --version || true
    echo

    echo
    echo "dpkg:"
    dpkg --version || true
    echo

    echo
    echo "openssl:"
    openssl version || true
    echo

    echo
    echo "libc:"
    ldd --version || true
    echo

    echo
    echo "ldd hermes-rust-ci:"
    ldd /opt/gitlinks/hermes-rust-ci || true
    echo

    echo
    echo "ldconfig libssl:"
    ldconfig -p | grep libssl || true
    echo

    echo
    echo "ldconfig libz:"
    ldconfig -p | grep libz || true
    echo
}

if [ $(is_debian_based) = true ]
then
    echo "Detected debian-based OS. Installing using dpkg and apt-get"
    install_deb
elif [ $(is_redhat_based) = true ]
then
    echo "Detected redhat-based OS. Installing using yum"
    install_rpm
else
    >&2 echo "Failed to determine OS type!"
    >&2 echo "Expected dpkg and apt-get for 'debian-based' systems"
    >&2 echo "Expected yum (or dnf) for 'redhat-based' systems"
    exit 1
fi

os_debug
check_installation