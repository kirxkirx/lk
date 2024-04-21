#!/usr/bin/env python2
# -*- coding: UTF-8 -*-
import cgi
import os

# For JobID generation
import random
import string

# for sleep
import time
# for sys
import sys

# use urlparse to get server name
from urlparse import urlparse

import re

# Global script parameters
service_name_for_url = '/lk/'
file_readwrite_buffer_size = 8192
MAX_FILE_SIZE = 10000000  # Maximum file size in bytes (10 MB)
# MAX_FILE_SIZE = 1000 # 1 KB for testing


def is_suspicious_filename(filename):
    # Define a maximum reasonable length for a filename
    MAX_LENGTH = 64

    # List of suspicious extensions
    SUSPICIOUS_EXTENSIONS = [
        '.php',
        '.py',
        '.pl',
        '.sh',
        '.rb',
        '.zip',
        '.gz',
        '.bz2',
        '.rar',
        '.7z',
        '.tar',
        '.exe',
        '.png',
        '.jpg',
        '.jpeg']

    # Regular expression for unusual characters
    # Adjust the regex pattern according to your requirements
    unusual_chars_pattern = re.compile(r'[^a-zA-Z0-9._+\-]')

    # Check if the filename is too long
    if len(filename) > MAX_LENGTH:
        return True

    # Check for suspicious file extensions
    _, file_extension = os.path.splitext(filename)
    if file_extension.lower() in SUSPICIOUS_EXTENSIONS:
        return True

    # Check for unusual characters in the filename
    if unusual_chars_pattern.search(filename):
        return True

    # If none of the above checks are true, the filename is not suspicious
    return False


def is_number(s):
    # Check if the input parameters are numbers
    try:
        float(s)  # for int, long and float
    except ValueError:
        return False
    return True


def truncate_string(input_string, N):
    # Truncate the string to a maximum of N characters
    truncated_string = input_string[:N]
    return truncated_string


def is_valid_string(s):
    # Check if the string does not start with "."
    if s.startswith("."):
        return False

    # Check if the string contains ".."
    if ".." in s:
        return False

    # Check if the string contains ".."
    if "/" in s:
        return False

    # Check if all characters in the string are alphanumeric or underscore
    return all(c.isalnum() or c == '_' or c == '.' for c in s)


def is_text_but_not_script(file_path):
    try:
        with open(file_path, 'rb') as file:
            # Read up to 1024 bytes from the file
            snippet = file.read(1024)

            # Check for null bytes to determine if it's a binary file
            if '\0' in snippet:
                return False

            # Check for common script patterns
            script_patterns = [
                '<?php', '<?=', '<?',          # PHP
                '#!/usr/bin/env python',       # Python
                '#!/usr/bin/python',           # Python with specific path
                '#!/usr/bin/env perl',         # Perl
                '#!/usr/bin/perl',             # Perl with specific path
                '#!/bin/sh', '#!/bin/bash',    # Shell scripts
                '#!/usr/bin/env sh',           # Shell with env
                '#!/usr/bin/env bash',         # Bash with env
                '#!/'                          # General script-like combination
            ]

            if any(pattern in snippet for pattern in script_patterns):
                return False

            return True
    except IOError:
        # Handle any I/O errors
        return False


def is_archive(filename):
    with open(filename, 'rb') as file:
        header = file.read(10)

    # Check for signatures of different archive formats
    if header[0:4] == b'\x50\x4B\x03\x04':  # ZIP file
        return True
    elif header[0:2] == b'\x1F\x8B':        # GZ file
        return True
    elif header[0:4] == b'\x52\x61\x72\x21':  # RAR file
        return True
    elif header[0:6] == b'\x37\x7A\xBC\xAF\x27\x1C':  # 7z file
        return True
    elif header[0:5] == b'\x42\x5A\x68':    # BZ2 file
        return True
    elif header[0:4] == b'\x75\x73\x74\x61':  # TAR file
        return True

    return False


def fbuffer(f, chunk_size):
    total_size = 0
    while True:
        chunk = f.read(chunk_size)
        if not chunk:
            break
        total_size += len(chunk)
        if total_size > MAX_FILE_SIZE:
            raise ValueError("File size exceeds the limit")
        yield chunk


# Start log
message = 'Starting program ' + sys.argv[0] + ' <br>'

# Check the system load
emergency_load = 50.0
max_load = 40.0
load = 99.0
while load > max_load:
    load = 0.0
    if True == os.access('/proc/loadavg', os.R_OK):
        procload = open('/proc/loadavg', 'r')
        loadline = procload.readline()
        procload.close()
        load = float(loadline.split()[1])
        if load > emergency_load:
            message = message + 'System load is extremely high'
            print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
            sys.exit(1)  # Just quit
        if load > max_load:
            # initialize using current system time, just in case...
            random.seed()
            sleep_time = 60 * random.random()
            message = message + 'System load is too high: ' + \
                str(load) + ', sleeping for ' + str(sleep_time) + ' seconds! <br> '
            time.sleep(sleep_time)


form = cgi.FieldStorage()

# Get input parameters
pmax = truncate_string(form.getfirst('pmax', '100'), 10)
if not is_number(pmax):
    message = message + 'Bad string pmax'
    print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
    sys.exit(1)  # Just quit
if float(pmax) <= 0.0:
    message = message + 'pmax out of range!'
    print """\
Content-Type: text/html\n
<html>
<p>ERROR!</br></br>
The requested pmax is out of range:</br>pmax = %lf </br>
pmax should be > 0.0 </br></p>
</html>
""" % (float(pmax))
    sys.exit(1)  # Just quit
pmax = (str(float(pmax)))

pmin = truncate_string(form.getfirst('pmin', '10'), 10)
if not is_number(pmin):
    message = message + 'Bad string pmin'
    print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
    sys.exit(1)  # Just quit
if float(pmin) <= 0.0:
    message = message + 'pmin out of range!'
    print """\
Content-Type: text/html\n
<html>
<p>ERROR!</br></br>
The requested pmin is out of range:</br>pmin = %lf </br>
pmin should be > 0.0 </br></p>
</html>
""" % (float(pmin))
    sys.exit(1)  # Just quit
pmin = str(float(pmin))

phaseshift = truncate_string(form.getfirst('phaseshift', '0.05'), 10)
if not is_number(phaseshift):
    message = message + 'Bad string phaseshift'
    print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
    sys.exit(1)  # Just quit
if float(phaseshift) <= 0.0:
    message = message + 'Phase shift out of range!'
    print """\
Content-Type: text/html\n
<html>
<p>ERROR!</br></br>
The requested phase shift is out of range:</br>phaseshift = %lf </br>
The phase shift should be between 0.0 and 0.5 .</br></p>
</html>
""" % (float(phaseshift))
    sys.exit(1)  # Just quit
phaseshift = str(float(phaseshift))

fileupload = truncate_string(form.getfirst('fileupload', 'True'), 5)


# Check if input values are reasonable
if float(pmax) > 10000:
    pmax = '10000'
if float(pmin) < 0.001:
    pmin = '0.001'
if float(phaseshift) < 0.0005:
    phaseshift = '0.0005'


if float(phaseshift) >= 0.5:
    message = message + 'Phase shift out of range!'
    print """\
Content-Type: text/html\n
<html>
<p>ERROR!</br></br>
The requested phase shift is out of range:</br>phaseshift = %lf </br>
The phase shift should be between 0.0 and 0.5 .</br></p>
</html>
""" % (float(phaseshift))
    sys.exit(1)  # Just quit


if fileupload == "True":
    message = message + 'Uploading new file <br>'
    # A nested FieldStorage instance holds the file
    fileitem = form['file']
    # Test if the file was NOT uploaded
    if not fileitem.filename:
        message = 'ERROR!!! No file was uploaded. :('
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit

    # Check if the input filename looks suspicious
    if is_suspicious_filename(fileitem.filename):
        message = 'ERROR!!! The input filename looks suspicious! Please rename the input file.'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit

safe_serverside_filename_for_original_lightcurve_file = 'original_lightcurve_file.txt'

jdmin = '0'
jdmax = '2470000'

pid = os.getpid()
message = message + 'Process ID:  ' + str(pid) + ' <br>'

# Set default values for time conversion parameters
applyhelcor = 'No'
timesys = 'UTC'
J2Kposition = '00:00:00.00 +00:00:00.0'
jdmanual = ''
pmanual = ''
previouspmanual = '0.1'
phaserange = '1'

# If a new file is being uploaded - we generate new JobID
if fileupload == "True":
    # Generate new JobID
    JobID = 'lk' + str(pid)
    random.seed()  # initialize using current system time, just in case...
    for i in range(8):
        JobID = JobID + random.choice(string.letters)
    # Take care of the other inout parameters appropriate for the new file
    # upload
    applyhelcor = truncate_string(form.getvalue('applyhelcor'), 3)
    timesys = truncate_string(form.getvalue('timesys'), 3)
    J2Kposition = truncate_string(
        form.getfirst(
            'position',
            '00:00:00.00 +00:00:00.0'),
        100)
    if applyhelcor == 'Yes':
        if J2Kposition == '00:00:00.00 +00:00:00.0':
            print """\
Content-Type: text/html\n
<html>
<p>PROBABLE ERROR!<br>
You have specified that the Heliocentric correction should be applied,
but the sky position is still set to the default value 00:00:00.00 +00:00:00.0.<br>
Please go back and enter the accurate J2000 position of the star.</p>
<p>
applyhelcor=%s,
timesys=%s,
J2Kposition=%s.
</p>
</html>
""" % (applyhelcor, timesys, J2Kposition)
            sys.exit(0)  # Just quit
else:
    # we'll be processing a previously uploaded file
    # make sure the supplied JobID does not look suspicious
    JobID = truncate_string(form.getfirst('jobid', 'True'), 20)
    if not is_valid_string(JobID):
        message = message + 'Bad string JobID'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(1)  # Just quit
    if JobID == "True":
        message = message + 'ERROR JobID == True'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit
    fn = truncate_string(form.getfirst('lcfile', 'True'), 20)
    if not is_valid_string(fn):
        message = message + 'Bad string fn: ' + fn
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(1)  # Just quit
    if fn == "True":
        message = message + 'ERROR fn == True'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit
    if is_suspicious_filename(fn):
        message = 'ERROR!!! The input filename (fn) looks suspicious! Please rename the input file.'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit
    #
    jdmin = truncate_string(form.getfirst('jdmin', '0'), 20)
    if not is_number(jdmin):
        message = message + 'Bad string jdmin'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(1)  # Just quit
    jdmax = truncate_string(form.getfirst('jdmax', '2460000'), 20)
    if not is_number(jdmax):
        message = message + 'Bad string jdmax'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(1)  # Just quit

message = message + 'Job ID:  ' + JobID + ' <br>'

# one way or the ther, JobID should be the valid string
if not is_valid_string(JobID):
    message = message + 'Bad string JobID'
    print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
    sys.exit(1)  # Just quit

# continue parsing the form
jdmanual = truncate_string(form.getfirst('jdmanual', ''), 20)
pmanual = truncate_string(form.getfirst('pmanual', ''), 20)
previouspmanual = truncate_string(form.getfirst('previouspmanual', ''), 20)
previoujdmanual = truncate_string(form.getfirst('previoujdmanual', ''), 20)
if pmanual == previouspmanual:
    if jdmanual == previoujdmanual:
        pmanual = ''
        jdmanual = ''

phaserange = truncate_string(form.getfirst('phaserange', '1'), 10)

asassnband = truncate_string(form.getfirst('asassnband', '1'), 10)

dirname = 'files/' + JobID
if fileupload == "True":
    os.mkdir(dirname)
dirname = dirname + '/'


# The scary part - writing the file
if fileupload == "True":
    # strip leading path from file name to avoid directory traversal attacks
    fn = os.path.basename(
        safe_serverside_filename_for_original_lightcurve_file)
    # os.path.join(dirname, fn) is used to construct the file path in a
    # platform-independent way
    file_path = os.path.join(dirname, fn)
    if os.path.exists(file_path):
        message = 'ERROR!!! The output file already exist'
        print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
        sys.exit(0)  # Just quit

    try:
        f = open(file_path, 'wb')

        try:
            # Write the file in chunks
            for chunk in fbuffer(fileitem.file, file_readwrite_buffer_size):
                f.write(chunk)
        except ValueError as e:
            f.close()
            os.remove(file_path)  # Delete the incomplete file
            message = 'ERROR!!! The lightcurve file is too large'
            print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
            sys.exit(1)  # Exit the script

        f.close()
        message = 'The lightcurve file "' + fn + '" was uploaded successfully! <br>' + \
                  'Pmax:  ' + pmax + 'd <br> ' + \
                  'Pmin:  ' + pmin + 'd <br> ' + \
                  'Pshift:  ' + phaseshift + ' <br> '
    except IOError as e:
        print("I/O Error:", e)
        sys.exit(1)  # Exit the script

else:
    file_path = os.path.join(dirname, fn)

if not os.path.exists(file_path):
    message = message + 'ERROR: file_path does not exist ' + file_path
    print """\
Content-Type: text/html\n
<html><body>
<p>%s</p>
</body></html>
""" % (message,)
    sys.exit(1)

# Check that the input file is not a obvious archive
if is_archive(file_path):
    # Delete the suspicious file
    os.remove(file_path)
    # silent exit here will produce 'End of script output before headers' in
    # apache logs
    sys.exit(1)

# Check that the input file looks like a text file, if not - delete it
if not is_text_but_not_script(file_path):
    # Delete the suspicious file
    os.remove(file_path)
    # silent exit here will produce 'End of script output before headers' in
    # apache logs
    sys.exit(1)


fullhostname = truncate_string(os.getenv('HTTP_HOST'), 20)

message = message + '<br><br>The output will be written to <a href=\"http://' + fullhostname + \
    service_name_for_url + dirname + '\">http://' + fullhostname + '/astrometry_engine/' + dirname + '</a><br><br>'

# Run the actual command
syscmd = 'export PATH=$PWD:$PATH; echo ' + phaserange + ' > ' + dirname + 'phaserange_type.input ; echo ' + asassnband + ' > ' + dirname + 'asassnband_' + asassnband + '.input ;  echo ' + applyhelcor + ' ' + timesys + ' ' + J2Kposition + ' > ' + \
    dirname + 'time_conversion.txt  ; lk_web.sh ' + file_path + ' ' + str(pmax) + ' ' + str(pmin) + ' ' + str(phaseshift) + ' ' + str(jdmin) + ' ' + str(jdmax) + ' ' + JobID + ' ' + jdmanual + ' ' + pmanual + ' 2>&1 >> ' + dirname + 'program.log'
CmdReturnStatus = os.system(
    'echo \"' +
    syscmd +
    '\" >> ' +
    dirname +
    'program.log')
CmdReturnStatus = os.system(syscmd)
message = message + 'Command return status:  ' + str(CmdReturnStatus) + ' <br>'

# Make sure the original data file is removed by lk_web.sh for security
# reasons (unless this is not the first run)
if os.path.exists(file_path):
    if fn != 'lightcurve.dat':
        os.remove(file_path)


# Everything is fine - redirect
results_page_url = 'http://' + fullhostname + \
    service_name_for_url + dirname + 'index.html'

# That's for debugging - print out the detailed log
# Read the log file
#f = open(dirname + 'program.log', 'r')
#for line in f:
#    message = message + line + ' <br>'

# That's for production - 'The output will be written to' is the key phrase expected by the VaST script pokaz_laflerkinman.sh
message = 'The output will be written to <a href="' + results_page_url + '">' + results_page_url + '</a>'

print """\
Content-Type: text/html\n
<html>
<head>
<meta http-equiv=\"Refresh\" content=\"0; url=%s\">
</head>
<body>
<p>%s</p>
</body></html>
""" % (results_page_url, message,)
sys.exit(0)  # Just quit
