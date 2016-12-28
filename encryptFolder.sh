#!/bin/bash

declare -r RSA_KEY="$1"
declare -r ASEPASS="$2"
declare -r TARGET="$3"
declare -r WORKSPACE='E:\temp\OpenSSH\'
declare -r AESPASSWORD=$WORKSPACE"key.bin"
declare -r OUTPUTDIR='C:\Users\Windows-Work\Documents\Projects\ssl\TESTING\OUTPUT\'
# declare -r CURRENT=$PWD

encryptAES()
{
	result=$(checkfolder "$TARGET")
	#echo $result

	if [[ $result = "0" ]]
	then
		#echo "ENCRYPT a directory"
		encryptFolder "$TARGET"
	elif [[ $result = "1" ]]
	then
		#echo "ENCRYPT a file"
		encryptFile "$TARGET"
	else
		echo "ERROR - $result is not valid"
		exit 1
	fi

exit 1
}

#####
# Encrypt $1 file
# $2 outputDIR
#####
encryptFile(){
	local file="$1"
	local fileName=$(basename "$1")
	local lOUTPUTDIR=$OUTPUTDIR

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$OUTPUTDIR$2'\'
	fi

    # If exist
	checkOpenSSLfile "$ASEPASS" "$RSA_KEY"
	fileExist "$file"
	folderExist "$lOUTPUTDIR"

	echo "> Encrypt $fileName : start"
	
	# Get AES KEY	
	extractkey

	# Encrypt File name
	local ENCRYPTED_FILENAME=`echo $fileName | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$AESPASSWORD`

	# Create filename with SHA256
#	local ENCRYPTED_FILENAME_SHA256=`echo $ENCRYPTED_FILENAME | openssl dgst -sha256`
#	ENCRYPTED_FILENAME_SHA256=${ENCRYPTED_FILENAME_SHA256#*= }

	# Create Manifest file
#	local FILE_MANIFEST=$lOUTPUTDIR$ENCRYPTED_FILENAME".manifest"
	
#	touch $FILE_MANIFEST
#	echo $ENCRYPTED_FILENAME_SHA256 > $FILE_MANIFEST

	# Inject encrypted base64 filename
#	`echo $file | openssl enc -base64 -e -aes-256-cbc -nosalt -out $FILE_MANIFEST -pass file:$AESPASSWORD`

#	echo .
#	echo "$FILE_MANIFEST"
#	echo .
	
	# Convert base64 to base64 safe
	local BASE64_SAFE=`echo "$ENCRYPTED_FILENAME" | tr \/ _`
	local OUTPUT_FILENAME=$lOUTPUTDIR$BASE64_SAFE
	
	# Encrypt 
	openssl enc -aes-256-cbc -salt -in "$file" -out "$OUTPUT_FILENAME" -pass file:$AESPASSWORD

	# Remove secure file	
	purge $AESPASSWORD
	
	echo "> Encrypt $fileName : done"
	echo "> Output directory : $lOUTPUTDIR"	
}

encryptFolder(){
	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
			#echo "${file} is a file"
			#local folderName=$(basename "$1")
			encryptFile "${file}" "$2"
		else
			#echo "${file}"
			local folderName=$(basename "${file}")
			#echo $folderName
			local result=$(encryptFolderName "$folderName")
			encryptFolder "${file}" "$result"
		fi
	done
}

#
# Encrypt and Create folder
#
encryptFolderName(){
	local folderName="$1"
	local lOUTPUTDIR="$OUTPUTDIR"
	
	if [ -n "$2" ]
	then
		lOUTPUTDIR=$OUTPUTDIR$2'\'
	fi

    # If exist
	checkOpenSSLfile "$ASEPASS" "$RSA_KEY"
	folderExist "$lOUTPUTDIR"

	#echo "> encrypt folder $folderName : start"
	
	# Get AES KEY	
	extractkey

	# Encrypt File name
	local ENCRYPTED_FOLDERNAME=`echo $folderName | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$AESPASSWORD`
	
	# Convert base64 to base64 safe
	local BASE64_SAFE=`echo "$ENCRYPTED_FOLDERNAME" | tr \/ _`
	local OUTPUT_FOLDERNAME=$lOUTPUTDIR$BASE64_SAFE
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir $OUTPUT_FOLDERNAME
	fi

	# Remove secure file	
	purge $AESPASSWORD
	
	#echo "> encrypt folder $folderName : done"
	echo "$BASE64_SAFE"
}

decrypt()
{
	# If exist
	checkfile $TARGET $ASEPASS $RSA_KEY
	
	echo "> DECRYPT : START"
	
	# Get AES KEY	
	extractkey
	
	# Convert base64 safe to real base64
	local BASE64_SAFE=`echo "$TARGET" | tr _ \/`
	local OUTPUT_FILENAME=$BASE64_SAFE

	# Decrypt filename
	OUTPUT_FILENAME=`echo $OUTPUT_FILENAME | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$WORKSPACE"key.bin"`
	# Decrypt file
	openssl enc -d -aes-256-cbc -in "./$TARGET" -out "$OUTPUT_FILENAME" -pass file:$AESPASSWORD

	# Remove secure file
	purge $AESPASSWORD
	
	echo "> DECRYPT : DONE"	

	exit
}

genkey()
{
	local RSAKEY_PREFIX=data
	local RSAKEY_PASSWORD=dummypassword
	local lRSA_PRIV_KEY=$WORKSPACE$RSAKEY_PREFIX"_PRIV.pem"
	local lRSA_PUB_KEY=$WORKSPACE$RSAKEY_PREFIX"_PUB.pem"
	local lAESPASSWORD_enc=$AESPASSWORD".enc"

	echo "> GENKEY : START"
	 
	# Generate RSA Key Pair 
	file=$lRSA_PRIV_KEY
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
	else
		echo "Generating key request for $lRSA_PRIV_KEY"
		openssl genrsa -passout pass:$RSAKEY_PASSWORD -out $lRSA_PRIV_KEY 4096 -noout
	fi

	# Generate random AES Password
	file=$AESPASSWORD
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit
	else
		echo "Generate a 256 bit (32 byte) random key"
		openssl rand -base64 32 > $AESPASSWORD
	fi

	# Export Public key
	file=$lRSA_PUB_KEY
	if [ ! -f "$file" ]
	then
		openssl rsa -pubout -in $lRSA_PRIV_KEY -out $lRSA_PUB_KEY
	fi

	# Encrypt AES Password
	file=$lAESPASSWORD_enc
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit
	else
		openssl rsautl -encrypt -inkey $lRSA_PUB_KEY -pubin -in $AESPASSWORD -out $lAESPASSWORD_enc
	fi

	# Remove secure file
	purge $AESPASSWORD
	
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

menuconsole()
{
	while getopts ":a:p:" opt; do
	  case $opt in
		a) arg_1="$OPTARG"
		;;
		p) p_out="$OPTARG"
		;;
		\?) echo "Invalid option -$OPTARG" >&2
		;;
	  esac
	done

	printf "Argument p_out is %s\n" "$p_out"
	printf "Argument arg_1 is %s\n" "$arg_1"
}

# 1 : $TARGET 
# 2 : $ASEPASS 
# 3 : $RSA_KEY
# 4 : OUTPUTFOLDER
checkOpenSSLfile()
{
	local file="$1"

	if [ ! -f "$file" ]
	then
		echo "$file not found."
		exit 1
	fi
	
	file="$2"
	if [ ! -f "$file" ]
	then
		echo "$file not found."
		exit 1
	fi
}

fileExist()
{
	local file="$1"
	if [ ! -f "$file" ]
	then
		echo "file $file not found."
		exit 1
	fi
}


folderExist()
{
	local file="$1"
	if [ ! -d "$file" ]
	then
		echo "$file not found."
		exit 1
	fi
}

#
# Return value
# 0 = FOLDER
# 1 = FILE
#
checkfolder()
{
	local file="$1"
	local myresult=0

	if [[ -d "$file" ]]
	then
		myresult=0
	elif [[ -f "$file" ]]
	then
		myresult=1
	else
		echo "ERROR - $file is not valid"
		exit 1
	fi

	echo "$myresult"
}

extractkey()
{
	# Get AES KEY	
	local file=$AESPASSWORD
	if [ ! -f "$file" ]
	then
		openssl rsautl -decrypt -inkey "$RSA_KEY" -in "$ASEPASS" -out "$file"
	fi
}

purge()
{
	local lAESPASSWORD=$1
	rm $lAESPASSWORD
}

######
# Main method
######
main() {
	#menuconsole
	#menu	
	encryptAES
}

main "$@"