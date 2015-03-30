CollectM
========

Collectd agent for Windows

Installation
============

* Download from https://github.com/perfwatcher/collectm/releases/latest
* run `CollectM-<version>.install.exe`

CollectM would be added as service and started. If not :
```
C:\Program\ Files\CollectM\bin\node.exe C:\Program\ Files\CollectM\service.js [install|installAndStart|uninstall|stopAndUninstall|start|stop]
```
or
```
C:\Program\ Files (x86)\CollectM\bin\node.exe C:\Program\ Files (x86)\CollectM\service.js [install|installAndStart|uninstall|stopAndUninstall|start|stop]
```

Installer options :
* /S : silent install
* /D=&lt;C:\your\path&gt; : install to C:\your\path

Example : install to C:\Program Files\CollectM

```
Collectm-<version>.exe /S /D=C:\Program Files\CollectM
```
Note (from NSIS doc) :
/D sets the default installation directory. It must be the last parameter used in the command line and must not contain any quotes, even if the path contains spaces. Only absolute paths are supported.

Configure
=========

Use your browser to go to http://localhost:25826/ (login: admin / password: admin)

FAQ
===
* Which Windows version are suported ? It was only tested on Windows 2008, don't know for other version.

Developers
==========
build your own installer :

1. install nsis (http://nsis.sourceforge.net/)
2. install node (http://nodejs.org/)
3. install git (http://git-scm.com/downloads)
4. git clone https://github.com/perfwatcher/collectm
5. cd collectm
6. npm install
7. npm install -g grunt-cli (will install grunt in C:\Users\%USERNAME%\AppData\Roaming\npm)
8. set PATH=%PATH%;C:\Users\%USERNAME%\AppData\Roaming\npm\;C:\Program Files (x86)\NSIS\;
9. grunt cleanDirs distexe

TODO
====
* Write more documentation
* Add SSL on management port
* Set server host at install
* Stop to write what you'll never do
