# docker-sync-wsl-native

This is a proof-of-concept attempt to improve docker performance in Windows and utilize a native
Linux file-system, i.e. files mapped in containers should have real file-system attributes such
as owner id, read, write and execute bits.

This project will install a simple laravel 5.5 project utilizing docker-sync, file system
performance and modifications such as chmod are expected to work as if we are using a *nix based
host. Including docker-sync should result in performance superior to Docker for Mac assuming
the use of only osxfs. Loading [http://localhost:8000/](http://localhost:8000/) once the project is
installed is between 4-8x (without opcache) quicker than a CIFS or SSHFS volume mount in my tests.

## Prerequisites

As of 2018-03-20 at least Windows Insider Preview Build 17093 is required. I've previously
experimented with sshfs and **do not** recommend that approach. I am running Insider Preview Build
17120 without issue, YMMV.

1. Install the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
    I'm using `Ubuntu 16.04.3 LTS (Xenial Xerus)`.

1. Create the file `/etc/wsl.conf` using a wsl terminal:

    `sudo nano /etc/wsl.conf`

    ```text
    [automount]
    enabled = true
    root = /
    options = "umask=2,fmask=113,metadata"
    mountFsTab = true
    ```

1. Follow the [docker sync on Windows](https://github.com/EugenMayer/docker-sync/wiki/docker-sync-on-Windows#3-launch-and-update)
    instructions from step #3 `Launch and update`.

1. Follow the instructions in [optional enhancements](#optional-enhancements) if you think
    they'll be of use to you. This guide has not been tested without them.

## Running the project

1. Clone the repository, create containers and start the inbuilt server:

    ```bash
    # clone the repository
    git clone https://github.com/andrewmackrodt/docker-sync-wsl-native.git
    
    # change into the project directory
    cd docker-sync-wsl-native
    
    # configure the project, dependencies and install
    ./app configure
    ./app make
    ./app install
    
    # start the php inbuilt server
    ./app start
    ```

1. You can now navigate to [http://localhost:8000/](http://localhost:8000/), I see page load times of
    ~110ms running on an Intel Core i7 3770k @ 4Ghz. Keep in mind that this is using only the PHP
    in-built server which is not designed with performance in mind.

1. Additionally, you can test how opcache affects performance (2x speed up on my machine). From your WSL
    shell execute these commands:

    ```bash
    # open a shell to the running app container
    ./app exec
    
    # install the opcache extension
    sudo docker-php-ext-install opcache
    
    # kill the inbuilt server, supervisor should automatically restart it
    sudo pkill php
    ```

### Optional enhancements

This section intends to offer advice about improving your development experience in Windows.
Advice here is optional but highly recommended.

#### ConEmu

I use this as my default shell and have created a task bar jump list item and explorer context
menu entry for it. As a daily bash user on Mac OS and Linux I find this a must have enhancement.
With the above configuration you will even have mouse support when running programs like `htop`.

1. Install [ConEmu](https://conemu.github.io/) "an advanced console window where you can run any
    shell of your choice".

1. Copy `%ConEmuBaseDir%\wsl` to `%LocalAppData\wslbridge%`, e.g. I copied
    `C:\Program Files\ConEmu\ConEmu\wsl` to `C:\Users\Andrew\AppData\Local\wslbridge`.

1. Make the file `wslbridge-backend` executable from a WSL shell:

    _This step is required due to the `fmask` attribute in `/etc/wsl.conf`. This is a problem
     for this particular file because it is in a system directory and we cannot set the
     executable bit even if we were the root user._

    ```bash
    cd /c/Users/Andrew/AppData/Local/wslbridge
    chmod a+x wslbridge-backend
    ```

1. Append the following to `/etc/fstab.conf` using a wsl terminal:

    `sudo nano /etc/fstab`

    _This is a continuation of the previous step; the wslbridge executable expects the
     wslbridge-backend file to exist in /mnt/c, however, we still want the drive to be
     accessible from /c. The mount order is important for current working directory
     resolution to put you into /c/* and not /mnt/c/*._

    ```text
    C:       /mnt/c      drvfs   rw,noatime,uid=1000,gid=1000,umask=2,fmask=113,metadata   0 0
    /mnt/c   /c          none    defaults,bind                                             0 0
    ```

1. Open ConEmu and create a Task called `Bash::WSL`:

    _Replace /cygdrive/c with /cygdrive/d if your %LocalAppData% directory is on drive D:._ 

    ```text
    Parameters:
        /icon %USERPROFILE%\AppData\Local\lxss\bash.ico
    
    Commands:
        set "PATH=%ConEmuBaseDirShort%\wsl;%PATH%" & %ConEmuBaseDirShort%\conemu-cyg-64.exe /cygdrive/c/Users/%Username%/AppData/Local/wslbridge/wslbridge.exe -cur_console:pn -t /bin/bash -l
    ```

#### Use WSL as the default terminal in PhpStorm
    
Update your PhpStorm configuration via `File -> Settings`:

    Appearance & Behaviour -> System Settings -> Synchronization
       [ off ] Use "safe write" (save changes to a temporary file first)
    
    Tools -> Terminal -> Application Settings
       Shell path: C:\Windows\System32\wsl.exe
