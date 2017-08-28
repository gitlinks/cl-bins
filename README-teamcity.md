# Before first installation

## Root access for yum or apt-get + dpkg

Our install script will use your OS package manager to install hermes command line utility. In order to do that, user running the build must be allowed to execute yum or dpkg+apt-get as superuser.

Default Teamcity configuration may not allow it, though.

1. check which user is used to run your builds:
    * add a command line build step to your build configuration:
        * `echo Gitlinks user: $(whoami)`
    * username will now show up in the build log
    * username suggested by the official installation guide is `tcagent`, and we'll use this name in this document  
1. login as `root` on your Teamcity agent(s)
1. check whether `sudo` is installed: 
	* `which sudo`
1. if it's not, install it:
	* `yum install sudo` - for redhat-based OS
	* `apt-get install sudo` - for debian-based OS
1. verify, that a line saying `#includedir /etc/sudoers.d` is present in `/etc/sudoers`
	* `grep -c '#includedir /etc/sudoers.d' /etc/sudoers` should return "1"
1. if it' not present, use `visudo` to add it at the end of the file (or any other editor, if you're feeling confident that you won't break anything)
1. specify permissions for user `tcagent` (replace "tcagent" with your user name from step #1 if it's different!)
	* `echo "tcagent ALL=(ALL) NOPASSWD: $(which yum)" > /etc/sudoers.d/teamcity` - for redhat-based OS
	* `echo "tcagent ALL=(ALL) NOPASSWD: $(which dpkg) , $(which apt-get)" > /etc/sudoers.d/teamcity` - for debian-based OS
1. you're done!

## Agent-side sources checkout for git metadata

Gitlinks command line utility needs to retrieve project metadata such as: project name, remote url and current branch.
In order to do that, git metadata (.git directory) must be checked out on agent machine.

By default, teamcity has the agent clone the sources directly from the remote repository.
This way, we have all git metadata available when we run hermes cli - that's good.

But, there is another option - server clones sources, and sends them over to the agent, WITHOUT the git metadata - that's bad, as we can't extract all git-related info that's required for hermes cli to run.

The "bad" case will happen if:
* build is configured to use server checkout
* there is no git installed on agent machine
* git password authentication is used, but git version on the agent machine is too old
* git ssh authentication is used, but agent ssh key is not registered on the remote (gitlab, etc)

Follow those steps to ensure sources are checked out by the agent:
1. make sure agent-side checkout is set
    * in Teamcity go to:    
        * `Build 
        -> Version Control Settings 
        -> (Show advanced options) 
        -> VCS checkout mode`
    * set either "Prefer to checkout files on agent" or "Always checkout files on agent".
1. make sure git is installed on agent machine
1. make sure agent machine has access to the remote repository:
    * for password-based authentication - ensure git version is high enough (according to Teamcity: "Password authentication requires git 1.7.3.0")
    * for key-based authentication - ensure agent's ssh key is registered in your remote repository 
1. for more info, see: https://confluence.jetbrains.com/display/TCD10/VCS+Checkout+Mode