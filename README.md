# docker-sync-wsl-native

This is a proof-of-concept attempt to improve docker performance in Windows and utilize a native
Linux file-system, i.e. files mapped in containers should have real file-system attributes such
as owner id, read, write and execute bits.

This project will install a simple laravel 5.5 project utilizing docker-sync, file system
performance and modifications such as chmod are expected to work as if we are using a *nix based
host. Actually, thanks to docker-sync, we should get performance superior to Docker for Mac.
On my machine loading [http://localhost:8000/](http://localhost:8000/) once the project is installed
is between 4-8x (without opcache) quicker than using a CIFS or SSHFS volume mount.

_Note: this is WIP and some instructions may be out of date. Additionally the stability of this
method is unproven but gives a glimpse into what may be possible in the future._

## Prerequisites

### Windows setup

1. Add docker-sync support to WSL: https://github.com/EugenMayer/docker-sync/wiki/docker-sync-on-Windows

2. Start a "Bash on Ubuntu on Windows" shell and execute:

        # allow passwordless sudo for wslboot
        echo -e "$USER ALL=(root) NOPASSWD: /usr/local/bin/wslboot.sh" | sudo tee /etc/sudoers.d/wslboot >/dev/null
        sudo cp bin/wslboot.sh /usr/local/bin
        sudo chmod a+x /usr/local/bin/wslboot.sh
        
        # generate a private key for openssh and copy it to the windows desktop
        ssh-keygen
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        cp ~/.ssh/authorized_keys "/mnt/c/Users/$(ls -1 /mnt/c/Users | egrep -i ^$USER$)/Desktop/id_rsa-wsl"

3. Then, using command prompt:

        copy bin\wsl.bat %LocalAppData%

4. Install [Mountain Duck](https://mountainduck.io/) and configure a new bookmark:

        SFTP (SSH File Transfer Protocol)
          Nickname: WSL
          Server: 127.0.0.1
          Port: 22
          Username: andrew
          SSH Private Key: C:\Users\Andrew\Desktop\id_rsa-wsl
          Path: /home/andrew
          Drive Letter: W:

    _Optional: you may try [SFTP Net Drive](http://www.sftpnetdrive.com/) instead but I did not find it as stable_
   
#### ConEmu setup

_This is an optional but recommend step_

Create a ConEmu Task "Bash::WSL"

    Parameters:
        /icon %USERPROFILE%\AppData\Local\lxss\bash.ico
    
    Commands:
        set "PATH=%ConEmuBaseDirShort%\wsl;%PATH%" & %ConEmuBaseDirShort%\conemu-cyg-64.exe --wsl -cur_console:pnm:/mnt -t /usr/local/bin/wslboot.sh

#### PhpStorm setup

_This is an optional but recommend step_

    Appearance & Behaviour -> System Settings -> Synchronization
      [ off ] Use "safe write" (save changes to a temporary file first)
       
    Tools -> Terminal -> Application Settings
      # replace your username
      Shell path: C:\Users\Andrew\AppData\Local\wsl.bat

### Installation

1. Open a WSL shell via running `%LocalAppData%\wsl.bat` in a command prompt, this shell must remain open
   throughout the entire duration.

2. Mount your WSL home directory using Mountain Duck so that it's accessible via Explorer and your editor(s).

3. Clone the repository, create containers and start the inbuilt server 
    
        # clone the repository into your WSL home directory 
        git clone https://github.com/andrewmackrodt/docker-sync-wsl-native.git /w/docker-sync-wsl-native
        
        # change into the project directory
        cd /w/docker-sync-wsl-native

        # configure the project, dependencies and install
        ./app configure
        ./app make
        ./app install
        
        # start the php inbuilt server
        ./app start

4. You can now navigate to [http://localhost:8000/](http://localhost:8000/), I see page load times of
   about ~110ms running on an Intel Core i7 3770k @ 4Ghz.

5. Additionally, you can test how opcache affects performance (2x speed up on my machine). From your WSL
   shell execute these commands:

        # open a shell to the running app container
        ./app exec
        
        # install the opcache extension
        sudo docker-php-ext-install opcache
        
        # kill the inbuilt server, supervisor should automatically restart it
        sudo pkill php
