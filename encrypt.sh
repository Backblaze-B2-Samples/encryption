#!/usr/bin/env bash

set -e

PUBLIC_KEY="pub-key.pem"
FILE_TO_ENCRYPT="$@"
B2_BUCKET_NAME="b2demo"

# Ensure there is a file name specified.

if [ -z "$FILE_TO_ENCRYPT" ]; then
	echo "Usage: encrypt.sh <filename>"
	exit 1
fi

# Generate a one-time per file password that's 180 characters long. Save it
# into RAM only for use by subsequent commands.

ONE_TIME_PASSWORD=$(openssl rand -base64 180)

# Now, encrypt the file. The file is encrypted using symmetrical 
# encryption along with the 180 character one-time password above. 

echo $ONE_TIME_PASSWORD | \
	openssl aes-256-cbc -salt -pass stdin \
	-in $FILE_TO_ENCRYPT -out $FILE_TO_ENCRYPT.enc

# Now, encrypt the 180 character one-time password using your public key. This
# password was computed in RAM and only written to disk encrypted for security.
# Password is encrypted into a binary format. 

echo $ONE_TIME_PASSWORD | \
	openssl rsautl -encrypt -pubin -inkey $PUBLIC_KEY \
	-out $FILE_TO_ENCRYPT.key.enc

# Upload the encrypted file and the encrypted one time password to B2. 

b2 upload_file $B2_BUCKET_NAME $FILE_TO_ENCRYPT.enc $FILE_TO_ENCRYPT.enc
b2 upload_file $B2_BUCKET_NAME $FILE_TO_ENCRYPT.key.enc \
	$FILE_TO_ENCRYPT.key.enc
