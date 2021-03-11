# Encrypting files in B2

Backblaze’s backup product has been encrypting customer data by default from the day it shipped in 2008. The files are encrypted on the user’s computer, transferred to Backblaze via an encrypted SSL connection and stored in the encrypted format. In fact, there is no way to turn it off. Flash forward to 2016, we’ve now encrypted billions of files and decrypted millions of files. The way encryption works in the online backup product is described on the [Backblaze blog](https://www.backblaze.com/blog/how-to-make-strong-encryption-easy-to-use/).

While B2 does support [server side encryption](https://www.backblaze.com/b2/docs/server_side_encryption.html), some customers perfer to manage their own encryption keys and upload encrypted files to B2. This article describes one way to encrypt files and push them to B2, using the a similar technique to how the Backblaze online backup product works today.

**Prerequisities**
- OpenSSL command line tool.
This tool is installed on Mac and generally on Linux hosts by default. It needs be be downloaded and installed for Windows.

- B2 CLI tool 
This can be found on [Github](https://github.com/Backblaze/B2_Command_Line_Tool) or can be installed via PIP “pip install b2”. After installation, you need to run the authorize_account step to provide your B2 credentials


     $ b2 authorize_account [accountId] [applicationKey]

# Steps

## Create a private/public keypair. 

You only need to do this step once. (Alternatively - if you already have a public/private key pair, you can omit this.)

	PRIVATE_KEY="priv-key.pem"
	PUBLIC_KEY="pub-key.pem"
	
	# Generates a private key. The passphrase for the private 
	# key is required to be typed in during key creation.
	
	openssl genrsa -aes256 -out $PRIVATE_KEY 2048
	
	# From the private key, generates a public key. This key will be used
	# to encrypt the one time password generated for each file's 
	# encryption. This command will require the private key passphrase.
	
	openssl rsa -in $PRIVATE_KEY -pubout -out $PUBLIC_KEY

The private key (priv-key.pem) and the passphrase you set should be saved in a secure location. If you lose either of these, any files encrypted using the technique below will be lost forever.

As you'll see below, the private key is only needed for decrypting files. For added security, do not keep this file on the computer you use for encrypting data.

## Encrypt and transmit file to B2.

You need to run this step for each file you wish to encrypt. This step generates a 180 character one-time per file password and uses this to encrypt the file. Then, this one-time password is itself encrypted, using the public key and stored to disk.

Finally, both the encrypted file and the encrypted one-time password is transmitted to B2.

	PUBLIC_KEY="pub-key.pem"
	FILE_TO_ENCRYPT="myfile.zip"
	B2_BUCKET_NAME="encryptiondemo"
	
	# Generate a one-time per file password that's 180 characters long. 
	# Save it into RAM only for use by subsequent commands.
	
	ONE_TIME_PASSWORD=`openssl rand -base64 180`
	
	# Now, encrypt the file. The file is encrypted using symmetrical 
	# encryption along with the 180 character one-time password above. 
	
	echo $ONE_TIME_PASSWORD | \
		openssl aes-256-cbc -a -salt -pass stdin \
		-in $FILE_TO_ENCRYPT -out $FILE_TO_ENCRYPT.enc
		
	# Now, encrypt the 180 character one-time password using the public 
	# key. This password was computed in RAM and only written to disk 
	# encrypted for security. Password is encrypted into a binary format. 
	
	echo $ONE_TIME_PASSWORD | \
		openssl rsautl -encrypt -pubin -inkey $PUBLIC_KEY \
		-out $FILE_TO_ENCRYPT.key.enc
		
	# Upload the encrypted file and the encrypted one time password to B2. 
	
	b2 upload_file $B2_BUCKET_NAME $FILE_TO_ENCRYPT.enc \
	    $FILE_TO_ENCRYPT.enc
	b2 upload_file $B2_BUCKET_NAME $FILE_TO_ENCRYPT.key.enc \
		$FILE_TO_ENCRYPT.key.enc

## Download and decrypt from B2.

You need to run this step for every file you want to retreive from B2 and decrypt. This step fetches the encrypted file and one-time passsword from B2. The one-time password is decrypted using your private key. Then, this password is used to decrypt the file.

	PRIVATE_KEY="priv-key.pem"
	FILE_TO_DECRYPT="myfile.zip"
	BUCKET_NAME="encryptiondemo"
	
	# Download the encrypted file and encrypted one time password from B2.
	
	b2 download_file_by_name $BUCKET_NAME $FILE_TO_DECRYPT.enc \
		$FILE_TO_DECRYPT.enc
	b2 download_file_by_name $BUCKET_NAME $FILE_TO_DECRYPT.key.enc \
		$FILE_TO_DECRYPT.key.enc
		
	# Then, decrypt the file. The command is excuted as one command to 
	# ensure that the one time password remains in memory and isn't ever 
	# written to disk in plaintext.
	
	# openssl rsautl -decrypt -inkey $PRIVATE_KEY
	# This command decrypts the one time password using the private key. 
	# This command requires the private key passphrase to be typed into 
	# the console. Once decrypted, the plaintext one time password is 
	# passed via stdin to:
	
	# openssl enc -aes-256-cbc -d -a -pass stdin -in \ 
	# $FILE_TO_DECRYPT.enc -out $FILE_TO_DECRYPT 
	# This command decrypts the file using the one-time password and 
	# saves to the filesystem.
	
	openssl rsautl -decrypt -inkey $PRIVATE_KEY -in \ 
		$FILE_TO_DECRYPT.key.enc | \
		openssl enc -aes-256-cbc -d -a -pass stdin -in \
		$FILE_TO_DECRYPT.enc -out $FILE_TO_DECRYPT 

# Notes and Limitations

Some additional notes and limitations to this encryption approach:

- The filenames are not encrypted. The filename of the file on disk, is the filename that's stored in B2.
- The encrypted file and the encrypted one-time password are stored as separately files in B2 and are being uploaded separately. Therefore, you need to ensure that both files are uploaded to B2 successfully. If only the encrypted content is uploaded, but not the encrypted one-time password, the file can't later be decrypted.
- The private key and that private key's passphrase that's being used to decrypt the one-time passwords need to be secured well and backed up. Without this private key - the files cannot be decrypted. 
- This implementation does not upload the public or private key to B2.
- Finally, there are many different methods to encrypt files and transmit them to B2. Backblaze doesn't guarantee that using this method will interoperate with encryption/decryption features that may be built into B2 in the future.

# **FAQ**

## What happens if my private key is compromised? Do I need to re-encrypt my files?

No. Because your files are encrypted with the one-time password. 

If your private key has been compromised, you need to follow these steps, (1) Generate a new public/private key pair, (2) download all the encrypted one-time password files from B2. (3) decrypt these one-time password files using the compromised private key, (4) re-encrypt the one-time password files with new public key, and (5) re-upload the newly encrypted one-time password files to B2.

A one-time password file is only 345 bytes, so this operation can be done rapidly.

## If I change the passphrase on my private key, do I need to re-encrypt all my files?

No. You can change the private key passphrase without changing anything on the B2 side. The private key passphrase is required when you use the private key to generate a public key or decrypt files.

