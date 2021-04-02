#!/usr/bin/env bash

PRIVATE_KEY="priv-key.pem"
FILE_TO_DECRYPT="$@"
BUCKET_NAME="b2demo"

if [ -z "$FILE_TO_DECRYPT" ]; then
	echo "Usage: decrypt.sh <filename>"
	exit 1
fi

# Download the encrypted file and encrypted one time password from B2.

b2 download_file_by_name $BUCKET_NAME $FILE_TO_DECRYPT.enc \
	$FILE_TO_DECRYPT.enc
b2 download_file_by_name $BUCKET_NAME $FILE_TO_DECRYPT.key.enc \
	$FILE_TO_DECRYPT.key.enc

# Then, decrypt the file. The command is excuted as one command to ensure that 
# the one time password remains in memory and isn't ever written to disk 
# in plaintext.

# openssl rsautl -decrypt -inkey $PRIVATE_KEY
# This command decrypts the one time password using the private key. This 
# command requires the private key passphrase to be typed into the console.
# Once decrypted, the plaintext one time password is passed via stdin to:

# openssl enc -aes-256-cbc -d -a -pass stdin -in $FILE_TO_DECRYPT.enc -out
# $FILE_TO_DECRYPT 
# This command decrypts the file using the one-time password and saves to
# the filesystem.

openssl rsautl -decrypt -inkey $PRIVATE_KEY -in $FILE_TO_DECRYPT.key.enc | \
	openssl enc -aes-256-cbc -d -pass stdin -in \
	$FILE_TO_DECRYPT.enc -out $FILE_TO_DECRYPT 


