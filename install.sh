#!/bin/sh

SCRIPT_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

LATEST_VERSION=$(curl -sS https://gitlinks.github.io/cl-bins/latest/version)

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

    if [ "${CHECK_YUM}" -eq 0 ]
    then
        echo true
    else
        echo false
    fi
}

handle_deb() {
    echo "* Checking current hermes-rust-ci installation"
    dpkg-query --show hermes-rust-ci >/dev/null 2>&1
    CHECK_INSTALLED=$?

    if [ "${CHECK_INSTALLED}" -eq 0 ]
    then
        CURRENT_VERSION=$(dpkg-query --show hermes-rust-ci | cut -f2)
        echo "* hermes-rust-ci is installed in version '${CURRENT_VERSION}' (latest = '${LATEST_VERSION}')"

        if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]
        then
            echo "* hermes-rust-ci is already installed in the latest version"
        else
            echo "* hermes-rust-ci will be updated to the latest version"
            install_deb
        fi
    else
        echo "* hermes-rust-ci is not installed"
        install_deb
    fi
}

install_deb() {
    cd /tmp

    sudo apt-get -qq update

    echo "* Verifying libssl installation"
    dpkg-query --show libssl1.0.0 >/dev/null 2>&1
    CHECK_LIBSSL=$?

    if [ "${CHECK_LIBSSL}" -eq 1 ]
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
    sudo dpkg -i "${DEB_NAME}" >/dev/null

    echo "* Installing other hermes-rust-ci dependencies"
    sudo apt-get -fyqq install
}

handle_rpm() {
    echo "* Checking current hermes-rust-ci installation"

    rpm -q --queryformat "%{VERSION}" hermes-rust-ci >/dev/null 2>&1
    CHECK_INSTALLED=$?

    if [ "${CHECK_INSTALLED}" -eq 0 ]
    then
        CURRENT_VERSION=$(rpm -q --queryformat "%{VERSION}" hermes-rust-ci)
        echo "* hermes-rust-ci is installed in version '${CURRENT_VERSION}' (latest = '${LATEST_VERSION}')"

        if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]
        then
            echo "* hermes-rust-ci is already installed in the latest version"
        else
            echo "* hermes-rust-ci will be updated to the latest version"
            install_rpm
        fi
    else
        echo "* hermes-rust-ci is not installed"
        install_rpm
    fi
}

install_rpm() {
    cd /tmp

    ARCH_X_SPEC=$(get_architecture_x_specifier)
    RPM_NAME=hermes-rust-ci_latest_${ARCH_X_SPEC}.rpm

    echo "* Downloading hermes-rust-ci"
    curl -OsSf https://gitlinks.github.io/cl-bins/latest/"${RPM_NAME}"

    echo "* Installing hermes-rust-ci"
    sudo yum install --nogpgcheck -qy "${RPM_NAME}"
}

get_architecture() {
    echo $(uname -m)
}

get_architecture_x_specifier() {
    if [ $(get_architecture) = "x86_64" ]
    then
        echo "x64"
    else
        echo "x32"
    fi
}

get_architecture_specifier() {
    if [ $(get_architecture) = "x86_64" ]
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

echo
echo "*"
echo "*" "Installing Gitlinks CLI, Hermes"
echo "*"
echo

if [ $(is_debian_based) = true ]
then
    echo "* Detected debian-based OS"
    handle_deb
elif [ $(is_redhat_based) = true ]
then
    echo "* Detected redhat-based OS"
    handle_rpm
else
    >&2 echo "* Failed to determine OS type!"
    >&2 echo "* Expected dpkg and apt-get for 'debian-based' systems"
    >&2 echo "* Expected yum (or dnf) for 'redhat-based' systems"
    exit 1
fi

DEBUG_VALUE=${GITLINKS_DEBUG:-0}
if [ "${DEBUG_VALUE}" -eq 1 ]
then
    os_debug
fi

check_installation

echo
echo "*"
echo "*" "Installation finished"
echo "*"
echo
