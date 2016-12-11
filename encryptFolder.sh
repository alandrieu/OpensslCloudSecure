#!/bin/bash

declare -r RSA_KEY=$1
declare -r ASEPASS=$2
declare -r FILETARGET=$3
declare -r WORKSPACE='E:\temp\OpenSSH\'
# declare -r CURRENT=$PWD

encryptAES()
{
	local AESPASSWORD=$WORKSPACE"key.bin"
	
	# If exist
	checkfile

	echo "> ENCRYPT : START"
	
	# Get AES KEY	
	extractkey
	
	# Encrypt File name
	local ENCRYPTED_FILENAME=`echo $FILETARGET | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$AESPASSWORD`
	
	# Convert base64 to base64 safe
	local BASE64_SAFE=`echo "$ENCRYPTED_FILENAME" | tr \/ _`
	local OUTPUT_FILENAME=$BASE64_SAFE

	# Encrypt 
	openssl enc -aes-256-cbc -salt -in "$FILETARGET" -out "$OUTPUT_FILENAME" -pass file:$AESPASSWORD

	# Remove secure file	
	purge
	
	echo "> ENCRYPT : DONE"
	
	exit
}

decrypt()
{
	local AESPASSWORD=$WORKSPACE"key.bin"
	
	# If exist
	checkfile
	
	echo "> DECRYPT : START"
	
	# Get AES KEY	
	extractkey
	
	# Convert base64 safe to real base64
	local BASE64_SAFE=`echo "$FILETARGET" | tr _ \/`
	local OUTPUT_FILENAME=$BASE64_SAFE

	# Decrypt filename
	OUTPUT_FILENAME=`echo $OUTPUT_FILENAME | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$WORKSPACE"key.bin"`
	# Decrypt file
	openssl enc -d -aes-256-cbc -in "./$FILETARGET" -out "$OUTPUT_FILENAME" -pass file:$AESPASSWORD

	# Remove secure file
	purge
	
	echo "> DECRYPT : DONE"	

	exit
}

genkey()
{
	local RSAKEY_PREFIX=data
	local RSAKEY_PASSWORD=dummypassword
	local AESPASSWORD="key.bin"
	
	echo "> GENKEY : START"
	 
	# Generate RSA Key Pair 
	file=$RSAKEY_PREFIX"_PRIV.pem"
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
	else
		echo "Generating key request for $RSAKEY_PREFIX"
		openssl genrsa -passout pass:$RSAKEY_PASSWORD -out $RSAKEY_PREFIX"_PRIV.pem" 4096 -noout
	fi

	# Generate random AES Password
	file=$AESPASSWORD
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit
	else
		echo "Generate a 256 bit (32 byte) random key"
		openssl rand -base64 32 > $WORKSPACE$AESPASSWORD
	fi

	# Export Public key
	file=$RSAKEY_PREFIX"_PUB.pem"
	if [ ! -f "$file" ]
	then
		openssl rsa -pubout -in $RSAKEY_PREFIX"_PRIV.pem" -out $RSAKEY_PREFIX"_PUB.pem"
	fi

	# Encrypt AES Password
	file=$AESPASSWORD".enc"
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit
	else
		openssl rsautl -encrypt -inkey $RSAKEY_PREFIX"_PUB.pem" -pubin -in $WORKSPACE$AESPASSWORD -out $AESPASSWORD".enc "
	fi

	# Remove secure file
	purge
	
	echo "> GENKEY : DONE"
}

menu()
{
	PS3='Please enter your choice: '
	options=("encrypt" "decrypt" "genkey" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"encrypt")
				encryptAES
				;;
			"decrypt")
				decrypt
				;;
			"genkey")
				genkey
				;;
			"Quit")
				break
				;;
			*) echo invalid option;;
		esac
	done

	exit
}

checkfile()
{
	file=$FILETARGET
	if [ ! -f "$file" ]
	then
		echo "$file not found."
		exit
	fi
	
	file=$ASEPASS
	if [ ! -f "$file" ]
	then
		echo "$file not found."
		exit
	fi
	
	file=$RSA_KEY
	if [ ! -f "$file" ]
	then
		echo "$file not found."
		exit
	fi
}

extractkey()
{
	# Get AES KEY	
	local file=$WORKSPACE"key.bin"
	if [ ! -f "$file" ]
	then
		openssl rsautl -decrypt -inkey "$RSA_KEY" -in "$ASEPASS" -out "$file"
	fi
}

purge()
{
	local AESPASSWORD="key.bin"
	rm $WORKSPACE$AESPASSWORD
}

######
# Main method
######
main() {
	menu
}

main "$@"