#!/bin/bash

# Upload settings

	# PROTOCOL determines how the files will be uploaded and is one of:
	#  "local"	Copies to a location on your Pi.
	#		Use this if you have the "allsky-website" package installed.
	#  "ftp"	Uploads to a remote FTP server.
	#		See the section for ftp PROTOCOL below.
	#  "ftps"	Uploads to a remote FTP server that supports secure FTP transfer.
	# 		*** Use "ftps" instead of "ftp" if you can - it's more secure than ftp. ***
	#		See the section for ftp PROTOCOL below.
	#  "sftp"	(SSH file transfer) - Uploads to a remote FTP server that supports secure transfer.
	#		See the section for sftp PROTOCOL below.
	#  "scp"	(secure copy) - Copies to a remote server.
	#		See the section for scp PROTOCOL below.
	#  "S3"		Uploads to an Amazon Web Services (AWS) server.
	#		See the "S3 PROTOCOL only" section below.
	#  "gcs"	uploads to an Google Cloud Storage (GCS) bucket.
	#		See the "GCS PROTOCOL only" section below.
PROTOCOL="local"


# X*X*X*X*X*X*X*X*X*X*X*X          IMPORTANT NOTE          X*X*X*X*X*X*X*X*X*X*X*X*X*X
# YOU must create directories on the remote server (or on your Pi if PROTOCOL="local")
# for the variables below that end in "_DIR" (for example, IMAGE_DIR).
# X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*X*XX*X*X*X*X*X*X


# By default, the destination file name is the same as the file being uploaded.
# The *_DESTINATION_NAME variables below can be set to specify a DIFFERENT destination name.
# For example, if the file being uploaded is "allsky-20210710.mp4" you may want it
# called "allsky.mp4" on the remote web server so the name is always the same.
# In that case, set   VIDEOS_DESTINATION_NAME="allsky.mp4"
# If you want the destination file name to be the same as what's being uploaded,
# leave the *_DESTINATION_NAME blank.

# The WEB_*_DIR variables below are optionally used to copy a file to a directory on the Pi
# IN ADDITION TO being uploaded to a remote server.
# This is useful, for example, if your Pi's webpage cannot be reached from the Internet and
# you want an image to exist on the Pi AND on a remote web server.
# In that case, upload to the remote server using the PROTOCOL variable,
# and set the corresponding WEB_*_DIR variables to directories on your Pi.
# For example, for a timelapse, set VIDEOS_DIR to the name of the directory on the
# remote web server, and set WEB_VIDEOS_DIR to the name of the directory on your Pi,
# which will usually be in /var/www/html/allsky/videos.

	# The remote directory where the current "image.jpg" file should be copied to.
	# If you have the "allsky-website" package installed, leave it blank.
IMAGE_DIR="/var/www/html/allsky-website"
WEB_IMAGE_DIR=""

	# The remote directory where the timelapse video should be uploaded to.
	# If you have the "allsky-website" package installed, use VIDEOS_DIR="/var/www/html/allsky/videos".
VIDEOS_DIR="/var/www/html/allsky-website/videos"
VIDEOS_DESTINATION_NAME=""
WEB_VIDEOS_DIR=""

	# The remote directory where the keogram image should be copied to.
	# If you have the "allsky-website" package installed, use KEOGRAM_DIR="/var/www/html/allsky/keograms".
KEOGRAM_DIR="/var/www/html/allsky-website/keograms"
KEOGRAM_DESTINATION_NAME=""
WEB_KEOGRAM_DIR=""

	# The remote directory where the startrails image should be copied to.
	# If you have the "allsky-website" package installed, use STARTRAILS_DIR="/var/www/html/allsky/startrails".
STARTRAILS_DIR="/var/www/html/allsky-website/startrails"
STARTRAILS_DESTINATION_NAME=""
WEB_STARTRAILS_DIR=""


############### ftp, ftps, sftp, and scp PROTOCOLS only:
	# Enter the name of the remote server.  If you don't know it, ask your service provider.
REMOTE_HOST=""

############### ftp, ftps, and sftp PROTOCOLS only:
	# Enter the username of the login on the remote server.
REMOTE_USER=""

	# Enter the password of the login on your FTP server.  Does not apply to PROTOCOL=scp.
REMOTE_PASSWORD=""

	# Optionally enter the port required by your FTP server.  This rarely has to be done.
REMOTE_PORT=""

	# If you need special commands executed when connecting to the FTP server enter them here.
	# See the Wiki (https://github.com/thomasjacquin/allsky/wiki/11-Troubleshooting:-uploads)
	# for example commands to enter into LFTP_COMMANDS.
	# If you have more than one command to enter, separate them with semicolons (;).
	# This setting does not apply to the "scp" PROTOCOL.
LFTP_COMMANDS=""

############### scp PROTOCOL only:
	# You will need to set up SSH key authentication on your server.
	# First, generate a SSH key on your client:
	#   ssh-keygen -t rsa
	# When prompted, leave default filename, and use an empty passphrase.
	# Then, copy the generated key to your server:
	#   ssh-copy-id remote_username@server_ip_address
	# The private SSH key will be stored in ~/.ssh (default filename is id_rsa)

	# Enter the path to the SSH key
SSH_KEY_FILE=""

############### S3 PROTOCOL only:
	# You will need to install the AWS CLI:
	#   sudo apt-get install python3-pip
	#   pip3 install awscli --upgrade --user
	#   export PATH=/home/pi/.local/bin:$PATH
	#   aws configure
	# When prompted, enter a valid access key ID, Secret Access Key, and Default region name,
	# for example, (e.g. "us-west-2").  Set the Default output format to "json" when prompted.

	# AWS CLI directory where the AWS CLI tools are installed.
	# If you used a different PATH variable above, change AWS_CLI_DIR to match it.
AWS_CLI_DIR="/home/pi/.local/bin"

	# Name of S3 Bucket where the files will be uploaded (must be in Default region specified above).
	# You may want to turn off or limit bucket versioning to avoid consuming lots of
	# space with multiple versions of the "image.jpg" files.
S3_BUCKET="allskybucket"

	# S3_ACL is set to private by default.
	# If you want to serve your uploaded files vis http(s), change S3_ACL to "public-read".
	# You will need to ensure the S3 bucket policy is configured to allow public access to
	# objects with a public-read ACL.
	# You may need to set a CORS policy in S3 if the files are to be accessed by
	# Javascript from a different domain.
S3_ACL="private"

############### GCS PROTOCOL only:
	# You will need to install the gsutil command, which is part of the Google Cloud SDK.
	# See installation instructions at https://cloud.google.com/storage/docs/gsutil_install
	# NOTE: The gsutil command must be installed somewhere in the standard $PATH,
	# usually in /usr/bin.
	# Make sure you authenticate the cli tool with the correct user as well.

	# Name of the GCS bucket where the files are uploaded.
GCS_BUCKET="allskybucket"

	# GCS_ACL applies an access control rules to the uploaded files.
	# It is set to "private" by default.
	# You can use any one of the predefined acl rules found at
	# https://cloud.google.com/storage/docs/access-control/lists#predefined-acl
	# To access files over https, you can set it to "publicRead".
GCS_ACL="private"

