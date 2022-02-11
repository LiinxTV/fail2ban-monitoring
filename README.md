
### Features

- Real-time database updates.
- Easy to install to your server.
- Powerfull and cost less resources.
- Compatible with most GNU distributions.

![](https://www.alouit-multimedia.com/wp-content/uploads/2012/12/fail2ban-logo.jpg)

Installation:
-------------

**I can't believe that you don't have fail2ban installed on your server. If you don't have it, please go to (https://doc.ubuntu-fr.org/fail2ban)**

Required:
- [Python2 >= 2.6 or Python >= 3.2](https://www.python.org) or [PyPy](https://pypy.org)
- python-setuptools, python-distutils or python3-setuptools for installation from source

Optional:
- [pyinotify >= 0.8.3](https://github.com/seb-m/pyinotify), may require:
  * Linux >= 2.6.13
- [gamin >= 0.0.21](http://www.gnome.org/~veillard/gamin)
- [systemd >= 204](http://www.freedesktop.org/wiki/Software/systemd) and python bindings:
  * [python-systemd package](https://www.freedesktop.org/software/systemd/python-systemd/index.html)
- [dnspython](http://www.dnspython.org/)

**To install:**

**Shell part:**

    sudo git clone https://github.com/LiinxTV/fail2ban-monitoring.git
    cd fail2ban-monitoring
    mv fail2ban-monitoring.sh /usr/bin/fail2ban-monitoring.sh

Warning, before installing, make sure to have the alias in your `~/.bashrc`:

    echo "alias f2bm='sh /usr/bin/fail2ban-monitoring.sh'" >> ~/.bashrc
    source ~/.bashrc

Then finally install it:

    f2bm install
    
NOTE: if you want to import your actual fail2ban list to the database, just run `f2bm import`

If you want to see if f2bm is correctly installed, just run:

    f2bm debug

Grafana setup:
-------------

First, add a data source:

![](https://i.ibb.co/TkQ70m2/1.png)

![](https://i.ibb.co/fQ5SM2v/2.png)

![](https://i.ibb.co/znZw7x6/3.png)

Fill the form like this:

![](https://i.ibb.co/1Rrkwmf/4.png)

**Grafana part 2 - The dashboard:**

![](https://i.ibb.co/dpFNfsJ/5.png)

![](https://i.ibb.co/9sVqQFL/6.png)

Select `grafana.json` and finish the import process.

**Nice, you're done !**

Configuration:
--------------
• You must define action event to your JAILs. Exemple configuration of SSHD jail:

    [sshd]
    port    = ssh
    logpath = %(sshd_log)s
    backend = %(sshd_backend)s
    action = grafana
