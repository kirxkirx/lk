[![test_apache_install](https://github.com/kirxkirx/lk/actions/workflows/test_apache_install.yml/badge.svg)](https://github.com/kirxkirx/lk/actions/workflows/test_apache_install.yml)

# Web-based Period Search Software

This repository contains the source code of the [web-based period search service](https://scan.sai.msu.ru/lk/) ([mirror](https://kirx.net/lk/)). You are welcome to install it on your own web server.

## Requirements

- A CGI-enabled web server (tested with Apache)
- Python 2 with `os`, `cgi`, and `cgitb` modules installed
- gnuplot
- GCC

## Installation Instructions

### 1. Compile the Program

Navigate to the `cgi-bin/lk/` directory and run `make`:

```bash
cd cgi-bin/lk/
make
```

If `make` complains about the absence of GSL, install the GSL development package from your Linux distribution and try to run `make` again. Return to the previous directory:

```bash
cd -
```

### 2. Copy the Program to Your Web-Server's CGI-Bin Directory

```bash
sudo cp -r cgi-bin/lk/ /var/www/my.server.net/cgi-bin/
```

### 3. Copy the Static Web Pages

Copy the static web pages to a location visible to your web server:

```bash
sudo cp -r htdocs/lk/ /var/www/my.server.net/public_html/
```

### 4. Manage Temporary Directory

Create a temporary directory to hold computation results and ensure symbolic links are set correctly:

```bash
sudo mkdir /space
sudo mount -t tmpfs -o size=1G,mode=0777 tmpfs /space
```

It is recommended to create a cron job to regularly clean and re-mount this directory:

```cron
00 01 * * * rm -rf /space/ /space/.* &>/dev/null; umount /space; mount -t tmpfs -o size=1G,mode=0777 tmpfs /space
```

### 5. Change File Ownership

Change the ownership of the directories to the web server's user, commonly `www-data` or `apache`:

```bash
sudo chown -R www-data:www-data /var/www/my.server.net/public_html/lk/ /var/www/my.server.net/cgi-bin/lk
```

### 6. Configure Apache

Ensure the 'Includes' option and 'XBitHack on' parameter are enabled in your Apache configuration:

```apache
<Directory /var/www/>
    Options Indexes FollowSymLinks Includes
    XBitHack on
    AllowOverride None
    Require all granted
</Directory>
```

The program relies on XBitHack to include a list of removed data points instead of dealing with `.shtml`. If you skip this step, the list of manually removed data points ("JD mag." pairs) will not be displayed, but the functionality of the software will not be affected.

After completing the above steps, the period search service should be accessible at `http://my.server.net/lk`.

An example of a deployment script may be found in the [GitHub Action worklow](https://github.com/kirxkirx/lk/blob/main/.github/workflows/test_apache_install.yml) testing this code.

## Copyleft

Copyleft 2014-2024 Kirill Sokolovsky <kirx@kirx.net>

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public License](http://www.gnu.org/licenses/) for more details.
