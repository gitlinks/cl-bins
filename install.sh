#!/usr/bin/env bash

echo
echo "* Installing Gitlinks CLI, Hermes"
echo

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

is_debian_based() {
    command -v dpkg >/dev/null 2>&1
    CHECK_DPKG=$?

    command -v apt-get >/dev/null 2>&1
    CHECK_APT_GET=$?

    if [ "${CHECK_DPKG}" -eq 0 ] && [ "${CHECK_APT_GET}" -eq 0 ]
    then
        echo true
    else
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
    cd /tmp

    sudo apt-get update

    echo "* Removing old hermes-rust-ci installations"
    sudo apt-get remove -y hermes-rust-ci

    dpkg-query --list libssl1.0.0
    CHECK_LIBSSL=$?

    echo "* Verifying libssl installation"
    if (( ${CHECK_LIBSSL} == 1 ))
    then
        echo "* libssl is not installed"

        ARCH_SPEC=$(get_architecture_specifier)
        LIBSSL_DEB_NAME=libssl1.0.0_1.0.1t-1+deb8u6_${ARCH_SPEC}.deb

        echo "* Downloading libssl"
        curl -OsSf http://http.us.debian.org/debian/pool/main/o/openssl/"${LIBSSL_DEB_NAME}"

        echo "* Installing libssl"
        sudo dpkg -i "${LIBSSL_DEB_NAME}"
    else
        echo "* libssl is already installed"
    fi

    ARCH_X_SPEC=$(get_architecture_x_specifier)
    DEB_NAME=hermes-rust-ci_latest_${ARCH_X_SPEC}.deb

    echo "* Downloading hermes-rust-ci"
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/"${DEB_NAME}"

    echo "* Installing hermes-rust-ci"
    sudo dpkg -i "${DEB_NAME}"

    echo "* Installing other hermes-rust-ci dependencies"
    sudo apt-get -fy install
}

install_rpm() {
    cd /tmp

    ARCH_X_SPEC=$(get_architecture_x_specifier)
    RPM_NAME=hermes-rust-ci_latest_${ARCH_X_SPEC}.rpm

    echo "* Downloading hermes-rust-ci"
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/"${RPM_NAME}"

    echo "* Removing old hermes-rust-ci installations"
    sudo yum remove -y hermes-rust-ci

    echo "* Installing hermes-rust-ci"
    sudo yum install --nogpgcheck -y "${RPM_NAME}"
}

get_architecture() {
    echo $(uname -m)
}

get_architecture_x_specifier() {
    if [ $(get_architecture) == "x86_64" ]
    then
        echo "x64"
    else
        echo "x32"
    fi
}

get_architecture_specifier() {
    if [ $(get_architecture) == "x86_64" ]
    then
        echo "amd64"
    else
        echo "i386"
    fi
}

check_installation() {
    if [ ! -f /opt/gitlinks/hermes-rust-ci ]; then
        echo "* hermes-rust-ci was not installed in /opt/gitlinks !"
        exit 0
    fi
}

# os info output, for analysing os-related issues
os_debug () {
    echo
    echo "* * Retrieving operating system info:"
    echo

    echo
    echo "* whoami:"
    whoami || true
    echo

    echo
    echo "* os-release:"
    for i in $(ls /etc/*release); do echo ===$i===; cat $i; done || true
    echo

    echo
    echo "* ostype:"
    echo ${OSTYPE}
    echo

    echo
    echo "* /etc/issue:"
    cat /etc/issue || true
    echo

    echo
    echo "* hostnamectl:"
    hostnamectl || true
    echo

    echo
    echo "* lsb_release:"
    lsb_release -a || true
    echo

    echo
    echo "* uname:"
    uname -a || true
    echo

    echo
    echo "* yum:"
    yum --version || true
    echo

    echo
    echo "* apt-get:"
    apt-get --version || true
    echo

    echo
    echo "* dpkg:"
    dpkg --version || true
    echo

    echo
    echo "* ldd hermes-rust-ci:"
    ldd /opt/gitlinks/hermes-rust-ci || true
    echo

    echo
    echo "* openssl:"
    openssl version || true
    echo

    echo
    echo "* ldconfig libssl:"
    ldconfig -p | grep libssl || true
    echo

    echo
    echo "* dpkg-query --list libssl:"
    dpkg-query --list | grep libssl || true
    echo

    echo
    echo "* libc:"
    ldd --version || true
    echo

    echo
    echo "* dpkg-query --list libc6:"
    dpkg-query --list | grep libc6 || true
    echo

    echo
    echo "* ldconfig libz:"
    ldconfig -p | grep libz || true
    echo

    echo
    echo "* dpkg-query --list zlib:"
    dpkg-query --list | grep zlib || true
    echo
}

if [ $(is_debian_based) = true ]
then
    echo "* Detected debian-based OS. Installing using dpkg and apt-get"
    install_deb
elif [ $(is_redhat_based) = true ]
then
    echo "* Detected redhat-based OS. Installing using yum"
    install_rpm
else
    >&2 echo "* Failed to determine OS type!"
    >&2 echo "* Expected dpkg and apt-get for 'debian-based' systems"
    >&2 echo "* Expected yum (or dnf) for 'redhat-based' systems"
    exit 1
fi

if [[ ${GITLINKS_DEBUG} -eq 1 ]]
then
    os_debug
fi

check_installation