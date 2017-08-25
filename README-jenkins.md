Our install script will use your OS package manager to install hermes command line utility. In order to do that, user "jenkins" must be allowed to execute yum or dpkg+apt-get as superuser.
Default Jenkins configuration doesn't give it access to sudo, though.

* login as root on your Jenkins server or agent(s)
* check that 'sudo' is installed: 
	
	`which sudo`
* if it's not, install it:
	
	`yum install sudo` - for redhat-based OS
	
	`apt-get install sudo` - for debian-based OS
* verify that a line saying `#includedir /etc/sudoers.d` is present in `/etc/sudoers`
	`grep -c '#includedir /etc/sudoers.d' /etc/sudoers` should return "1"
* if it' not present, use visudo to add it at the end of the file (or any other editor, if you're feeling confident that you won't break anything)
* specify permissions for user jenkins
	
	`echo "jenkins ALL=(ALL) NOPASSWD: $(which yum)" > /etc/sudoers.d/jenkins` - for redhat-based OS
	
	`echo "jenkins ALL=(ALL) NOPASSWD: $(which dpkg) , $(which apt-get)" > /etc/sudoers.d/jenkins` - for debian-based OS
* you're done!