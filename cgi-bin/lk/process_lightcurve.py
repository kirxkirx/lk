#!/usr/bin/env python3
# -*- coding: UTF-8 -*-
import cgi
import os
import random
import string
import time
import sys
import re
from urllib.parse import urlparse  # Updated from urlparse for Python 3

# Global script parameters
service_name_for_url = '/lk/'
file_readwrite_buffer_size = 8192
MAX_FILE_SIZE = 50000000  # Maximum file size in bytes (50 MB) - increased from 10 MB
MAX_INPUT_FILENAME_LENGTH = 80

def is_suspicious_filename(filename):
    # Define a maximum reasonable length for a filename
    MAX_LENGTH = MAX_INPUT_FILENAME_LENGTH

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

    return False

def sanitize_filename(filename):
    MAX_LENGTH = MAX_INPUT_FILENAME_LENGTH
    filename = filename.strip()
    filename = re.sub(r'[^a-zA-Z0-9._+-]', '_', filename)
    filename = filename[:MAX_LENGTH]
    return filename

def is_number(s):
    try:
        float(s)
    except ValueError:
        return False
    return True

def truncate_string(input_string, N):
    if input_string is None:
        return ''
    return str(input_string)[:N]

def is_valid_string(s):
    if s.startswith("."):
        return False
    if ".." in s:
        return False
    if "/" in s:
        return False
    return all(c.isalnum() or c == '-' or c == '+' or c == '_' or c == '.' for c in s)

def is_text_but_not_script(file_path):
    try:
        with open(file_path, 'rb') as file:
            snippet = file.read(1024)
            
            # Check for null bytes (binary file)
            if b'\x00' in snippet:
                return False

            # Convert to string for pattern matching
            snippet_str = snippet.decode('utf-8', errors='ignore')
            
            script_patterns = [
                '<?php', '<?=', '<?',
                '#!/usr/bin/env python',
                '#!/usr/bin/python',
                '#!/usr/bin/env perl',
                '#!/usr/bin/perl',
                '#!/bin/sh', '#!/bin/bash',
                '#!/usr/bin/env sh',
                '#!/usr/bin/env bash',
                '#!/'
            ]

            if any(pattern in snippet_str for pattern in script_patterns):
                return False

            return True
    except IOError:
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

def print_html_response(message, redirect_url=None):
    print("Content-Type: text/html\n")
    html = ["<html>"]
    
    if redirect_url:
        html.append("<head>")
        html.append('<meta http-equiv="Refresh" content="0; url={0}">'.format(redirect_url))
        html.append("</head>")
    
    html.extend([
        "<body>",
        "<p>{0}</p>".format(message),
        "</body>",
        "</html>"
    ])
    
    print("\n".join(html))

# Start log
message = 'Starting program {0} <br>'.format(sys.argv[0])

# Check the system load
emergency_load = 50.0
max_load = 40.0
load = 99.0
while load > max_load:
    load = 0.0
    if os.access('/proc/loadavg', os.R_OK):
        with open('/proc/loadavg', 'r') as procload:
            loadline = procload.readline()
            load = float(loadline.split()[1])
            
        if load > emergency_load:
            message = message + 'System load is extremely high'
            print_html_response(message)
            sys.exit(1)
            
        if load > max_load:
            random.seed()
            sleep_time = 60 * random.random()
            message = message + 'System load is too high: {0}, sleeping for {1} seconds! <br> '.format(load, sleep_time)
            time.sleep(sleep_time)

form = cgi.FieldStorage()

# Get input parameters
pmax = truncate_string(form.getfirst('pmax', '100'), 10)
if not is_number(pmax):
    print_html_response('Bad string pmax')
    sys.exit(1)

if float(pmax) <= 0.0:
    print_html_response('ERROR!</br></br>The requested pmax is out of range:</br>pmax = {0} </br>pmax should be > 0.0 </br>'.format(float(pmax)))
    sys.exit(1)
pmax = str(float(pmax))

pmin = truncate_string(form.getfirst('pmin', '10'), 10)
if not is_number(pmin):
    print_html_response('Bad string pmin')
    sys.exit(1)

if float(pmin) <= 0.0:
    print_html_response('ERROR!</br></br>The requested pmin is out of range:</br>pmin = {0} </br>pmin should be > 0.0 </br>'.format(float(pmin)))
    sys.exit(1)
pmin = str(float(pmin))

phaseshift = truncate_string(form.getfirst('phaseshift', '0.05'), 10)
if not is_number(phaseshift):
    print_html_response('Bad string phaseshift')
    sys.exit(1)

if float(phaseshift) <= 0.0 or float(phaseshift) >= 0.5:
    print_html_response('ERROR!</br></br>The requested phase shift is out of range:</br>phaseshift = {0} </br>The phase shift should be between 0.0 and 0.5 .</br>'.format(float(phaseshift)))
    sys.exit(1)
phaseshift = str(float(phaseshift))

fileupload = truncate_string(form.getfirst('fileupload', 'True'), 5)

# Check if input values are reasonable
if float(pmax) > 10000:
    pmax = '10000'
if float(pmin) < 0.001:
    pmin = '0.001'
if float(phaseshift) < 0.0005:
    phaseshift = '0.0005'

safe_serverside_filename_for_original_lightcurve_file = 'original_lightcurve_file.txt'

jdmin = '0'
jdmax = '2470000'

pid = os.getpid()
message = message + 'Process ID: {0} <br>'.format(pid)

# Set default values for time conversion parameters
applyhelcor = 'No'
timesys = 'UTC'
J2Kposition = '00:00:00.00 +00:00:00.0'
jdmanual = ''
pmanual = ''
previouspmanual = '0.1'
phaserange = '1'

if fileupload == "True":
    message = message + 'Uploading new file <br>'
    fileitem = form['file']
    
    if not fileitem.filename:
        print_html_response('ERROR!!! No file was uploaded. :(')
        sys.exit(0)
    
    if is_suspicious_filename(fileitem.filename):
        print_html_response('ERROR!!! The input filename looks suspicious! Please rename the input file.')
        sys.exit(0)

    # Generate new JobID for new file upload
    JobID = 'lk{0}'.format(pid)
    random.seed()
    for _ in range(8):
        JobID = JobID + random.choice(string.ascii_letters)
    JobID = JobID + '__' + sanitize_filename(fileitem.filename).replace('.', '_')
    
    # Handle time conversion parameters
    applyhelcor = truncate_string(form.getvalue('applyhelcor'), 3)
    timesys = truncate_string(form.getvalue('timesys'), 3)
    J2Kposition = truncate_string(form.getfirst('position', '00:00:00.00 +00:00:00.0'), 100)
    
    if applyhelcor == 'Yes' and J2Kposition == '00:00:00.00 +00:00:00.0':
        print_html_response(
            'PROBABLE ERROR!<br>'
            'You have specified that the Heliocentric correction should be applied, '
            'but the sky position is still set to the default value 00:00:00.00 +00:00:00.0.<br>'
            'Please go back and enter the accurate J2000 position of the star.'
        )
        sys.exit(0)
else:
    # Processing previously uploaded file
    JobID = truncate_string(form.getfirst('jobid', 'True'), 18 + MAX_INPUT_FILENAME_LENGTH)
    if not is_valid_string(JobID):
        print_html_response('Bad string JobID')
        sys.exit(1)
    if JobID == "True":
        print_html_response('ERROR JobID == True')
        sys.exit(0)

    fn = truncate_string(form.getfirst('lcfile', 'True'), 20)
    if not is_valid_string(fn):
        print_html_response('Bad string fn: {0}'.format(fn))
        sys.exit(1)
    if fn == "True":
        print_html_response('ERROR fn == True')
        sys.exit(0)
    if is_suspicious_filename(fn):
        print_html_response('ERROR!!! The input filename (fn) looks suspicious! Please rename the input file.')
        sys.exit(0)

    jdmin = truncate_string(form.getfirst('jdmin', '0'), 20)
    if not is_number(jdmin):
        print_html_response('Bad string jdmin')
        sys.exit(1)
    jdmax = truncate_string(form.getfirst('jdmax', '2460000'), 20)
    if not is_number(jdmax):
        print_html_response('Bad string jdmax')
        sys.exit(1)

message = message + 'Job ID: {0} <br>'.format(JobID)

if not is_valid_string(JobID):
    print_html_response('Bad string JobID')
    sys.exit(1)

# Parse additional form parameters
jdmanual = truncate_string(form.getfirst('jdmanual', ''), 20)
pmanual = truncate_string(form.getfirst('pmanual', ''), 20)
previouspmanual = truncate_string(form.getfirst('previouspmanual', ''), 20)
previoujdmanual = truncate_string(form.getfirst('previoujdmanual', ''), 20)
if pmanual == previouspmanual and jdmanual == previoujdmanual:
    pmanual = ''
    jdmanual = ''

phaserange = truncate_string(form.getfirst('phaserange', '1'), 10)
asassnband = truncate_string(form.getfirst('asassnband', '1'), 10)

dirname = 'files/{0}'.format(JobID)
if fileupload == "True":
    os.mkdir(dirname)
dirname = dirname + '/'

# Handle file upload
if fileupload == "True":
    fn = os.path.basename(safe_serverside_filename_for_original_lightcurve_file)
    file_path = os.path.join(dirname, fn)
    
    if os.path.exists(file_path):
        print_html_response('ERROR!!! The output file already exists')
        sys.exit(0)

    try:
        with open(file_path, 'wb') as f:
            try:
                for chunk in fbuffer(fileitem.file, file_readwrite_buffer_size):
                    f.write(chunk)
            except ValueError as e:
                os.remove(file_path)
                print_html_response('ERROR!!! The lightcurve file is too large (maximum size: {0} MB)'.format(MAX_FILE_SIZE // 1000000))
                sys.exit(1)

        # Save original filename
        original_filename = sanitize_filename(fileitem.filename)
        with open(os.path.join(dirname, 'original_lightcurve_filename.txt'), 'w') as f:
            f.write(original_filename)

        message = 'The lightcurve file "{0}" was uploaded successfully! <br>Pmax: {1}d <br>Pmin: {2}d <br>Pshift: {3} <br>'.format(
            fn, pmax, pmin, phaseshift)
    except IOError as e:
        print("I/O Error:", e)
        sys.exit(1)
else:
    file_path = os.path.join(dirname, fn)

if not os.path.exists(file_path):
    print_html_response('ERROR: file_path does not exist {0}'.format(file_path))
    sys.exit(1)

# Security checks
if is_archive(file_path):
    os.remove(file_path)
    sys.exit(1)

if not is_text_but_not_script(file_path):
    os.remove(file_path)
    sys.exit(1)


# Get hostname and determine protocol
fullhostname = truncate_string(os.getenv('HTTP_HOST', 'localhost'), 20)

# Default protocol
protocol = 'http'

# Check if the script was accessed via HTTPS
if os.environ.get('REQUEST_SCHEME') == 'https':
    # Apache web server sets REQUEST_SCHEME=https
    protocol = 'https'
elif os.environ.get('HTTPS') == 'on':
    # Nginx sets HTTPS=on
    protocol = 'https'
elif os.environ.get('HTTP_REFERER', '').find('https:') != -1:
    # Check if the referer contains 'https:'
    protocol = 'https'

# Construct the output directory URL
message = '{0}<br><br>The output will be written to <a href="{1}://{2}{3}{4}">{1}://{2}/astrometry_engine/{4}</a><br><br>'.format(
    message, protocol, fullhostname, service_name_for_url, dirname)

# Construct and run the command
syscmd = 'export PATH=$PWD:$PATH; echo {0} > {1}phaserange_type.input ; echo {2} > {1}asassnband_{2}.input ; echo {3} {4} {5} > {1}time_conversion.txt ; lk_web.sh {6} {7} {8} {9} {10} {11} {12} {13} {14} 2>&1 >> {1}program.log'.format(
    phaserange, dirname, asassnband, applyhelcor, timesys, J2Kposition,
    file_path, str(pmax), str(pmin), str(phaseshift), str(jdmin),
    str(jdmax), JobID, jdmanual, pmanual
)

# Log the command
CmdReturnStatus = os.system('echo "{0}" >> {1}program.log'.format(syscmd, dirname))
# Execute the command
CmdReturnStatus = os.system(syscmd)

message = message + 'Command return status: {0} <br>'.format(CmdReturnStatus)

# Clean up original data file for security
if os.path.exists(file_path):
    if fn != 'lightcurve.dat':
        os.remove(file_path)

# Construct results page URL and redirect
results_page_url = '{0}://{1}{2}{3}index.html'.format(
    protocol, fullhostname, service_name_for_url, dirname)

# Final message for production
message = 'The output will be written to <a href="{0}">{0}</a>'.format(results_page_url)

# Print final HTML response with redirect
print_html_response(message, results_page_url)
sys.exit(0)
