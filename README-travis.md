Our install script will use your OS package manager to install hermes command line utility. In order to do that, user "jenkins" must be allowed to execute yum or dpkg+apt-get as superuser.
You must place `sudo: required` inside your `.travis.yml` file to enable sudo usage. 

Source: https://docs.travis-ci.com/user/reference/overview/