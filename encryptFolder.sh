#!/bin/bash

# Convert path for OpenSSL
windowsPathConverter()
{
	if [[ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" || "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]]; then
		# Do something under Windows NT platform
		local lCONVERT=$(cygpath -p -w "$1")
		echo $lCONVERT
	else 
		echo $1
	fi
}

declare -r FOLDER_WORKSPACE="/e/temp/OpenSSH/"
declare -r TARGET="$3"
declare -r FILE_RSA_PRIV_KEY="$1"
declare -r FILE_RSA_PRIV_KEY_PASSWORD=$(windowsPathConverter "$FOLDER_WORKSPACE""_test.lock")
declare -r FILE_AES_PASSWORD_ENCRYPTED="$2"
declare -r FILE_AES_PASSWORD_DECRYPTED=$FOLDER_WORKSPACE"key.bin"
declare -r FOLDER_OUTPUT_ENCRYPTED_DATA=$PWD"/OUTPUT/"
declare -r FOLDER_OUTPUT_DECRYPTED_DATA=$PWD"/OUTPUT_CLEAR/"

encryptAES()
{
	result=$(checkfolder "$TARGET")

	if [[ $result = "0" ]]
	then
		encryptFolder "$TARGET"
	elif [[ $result = "1" ]]
	then
		encryptFile "$TARGET"
	else
		echo "ERROR - $result is not valid"
		exit 1
	fi
}

#####
# Encrypt $1 file
# [optional] $2 outputDIR
#####
encryptFile(){
	local file="$1"
	local fileName=$(basename "$1")
	local lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA
	local lFILE_RSA_PRIV_KEY_PASSWORD=$(windowsPathConverter "$FILE_RSA_PRIV_KEY_PASSWORD")

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA$2"/"
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	fileExist "$file"
	folderExist "$lOUTPUTDIR"

	#	echo "> Encrypt $fileName : start"
	
	# Get AES KEY	
	extractkey

	# Encrypt File name
	local ENCRYPTED_FILENAME=`echo $fileName | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$FILE_AES_PASSWORD_DECRYPTED`
	checkError $?
	
	# Convert base64 to base64 safe
	local BASE64_SAFE=`echo "$ENCRYPTED_FILENAME" | tr \/ _`
	local OUTPUT_FILENAME=$lOUTPUTDIR$BASE64_SAFE
	local OUTPUT_FILENAME_SING=$lOUTPUTDIR$BASE64_SAFE".sha256"
	
	# Encrypt 
	openssl enc -aes-256-cbc -salt -in "$file" -out "$OUTPUT_FILENAME" -pass file:$FILE_AES_PASSWORD_DECRYPTED
	checkError $?

	# Generate signature
	local lRSA_PRIV_KEY=$FOLDER_WORKSPACE"data_PRIV.pem"
	local lRSA_PUB_KEY=$FOLDER_WORKSPACE"data_PUB.pem"
	openssl dgst -passin file:"$lFILE_RSA_PRIV_KEY_PASSWORD" -sha256 -sign "$lRSA_PRIV_KEY" -out "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME"
	checkError $?

	# Check signature
	openssl dgst -sha256 -verify "$lRSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME"
	checkError $?

	echo "> Encrypt $fileName : done"
	echo "> Output directory : $lOUTPUTDIR"	
}

#
# Recursive folder parsing
#
encryptFolder(){
	local folderFullPath=""

	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
		echo .
			encryptFile "${file}" "$2"
		else
			local folderName=$(basename "${file}")
	
			if [ -n "$folderFullPath" ]
			then
				folderFullPath="$folderFullPath\\$2"
			else
				folderFullPath=$folderFullPath$2
			fi

			echo "FOLDER = $folderFullPath"

			local result=$(encryptFolderName "$folderName" "$folderFullPath")
			echo "RESULT = $folderFullPath\\$result"
			result="$folderFullPath\\$result"
			encryptFolder "${file}" "$result"
		fi
	done

	# Remove secure file	
	purge $FILE_AES_PASSWORD_DECRYPTED
	purge $FILE_RSA_PRIV_KEY_PASSWORD
}

#
# Encrypt and Create folder
#
encryptFolderName(){
	local folderName="$1"
	local lOUTPUTDIR="$FOLDER_OUTPUT_ENCRYPTED_DATA"
	
	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA$2"/"
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	folderExist "$lOUTPUTDIR"

	# Get AES KEY	
	extractkey

	# Encrypt File name
	local ENCRYPTED_FOLDERNAME=`echo $folderName | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$FILE_AES_PASSWORD_DECRYPTED`
	checkError $?	

	# Convert base64 to base64 safe
	local BASE64_SAFE=`echo "$ENCRYPTED_FOLDERNAME" | tr \/ _`
	local OUTPUT_FOLDERNAME=$lOUTPUTDIR$BASE64_SAFE
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir $OUTPUT_FOLDERNAME
	fi

	#echo "> encrypt folder $folderName : done"
	echo "$BASE64_SAFE"
}

decryptAES()
{
	result=$(checkfolder "$TARGET")
	#echo $result

	if [[ $result = "0" ]]
	then
		#echo "ENCRYPT a directory"
		decryptFolder "$TARGET"
	elif [[ $result = "1" ]]
	then
		#echo "ENCRYPT a file"
		decryptFile "$TARGET"
	else
		echo "ERROR - $result is not valid"
		exit 1
	fi
}

#####
# Encrypt $1 file
# [optional] $2 outputDIR
#####
decryptFile()
{
	local file="$1"
	local fileName=$(basename "$1")
	local lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA$2"/"
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	fileExist "$file"
	folderExist "$lOUTPUTDIR"

	# Get AES KEY	
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE=`echo "$fileName" | tr _ \/`
	local OUTPUT_FILENAME=$BASE64_SAFE

	# Decrypt filename
	OUTPUT_FILENAME=`echo $OUTPUT_FILENAME | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$FILE_AES_PASSWORD_DECRYPTED`
	checkError $?

	# Decrypt file
	openssl enc -d -aes-256-cbc -in "$file" -out "$lOUTPUTDIR$OUTPUT_FILENAME" -pass file:$FILE_AES_PASSWORD_DECRYPTED
	checkError $?

	echo "> Decrypt $fileName : done"
	echo "> Output directory : $lOUTPUTDIR"		
}

#
# 
#
chekcSingFile()
{
	local file="$1"
	file="${file%.*}"
	
    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	fileExist "$file"

	echo "> Check signature $fileName : start"
	
	# Generate signature
	local lRSA_PUB_KEY=$FOLDER_WORKSPACE"data_PUB.pem"
	local OUTPUT_FILENAME_SING=$file".sha256"	

	# Check signature
	openssl dgst -sha256 -verify "$lRSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$file"
	checkError $?

	echo "> Check signature $fileName : done"	
}

#
# Recursive folder parsing
#
decryptFolder(){
	local folderFullPath=""

	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
			local filename=$(basename "${file}")
			local extension="${filename##*.}"

			if [[ "$extension" = "sha256" ]]
			then
				chekcSingFile "${file}"
			else
				decryptFile "${file}" "$2"
			fi
		else
			local folderName=$(basename "${file}")
	
			if [ -n "$folderFullPath" ]
			then
				folderFullPath="$folderFullPath\\$2"
			else
				folderFullPath=$folderFullPath$2
			fi

			echo "FOLDER = $folderFullPath"

			local result=$(decryptFolderName "$folderName" "$folderFullPath")
			echo "RESULT = $folderFullPath\\$result"
			result="$folderFullPath\\$result"
			decryptFolder "${file}" "$result"
		fi
	done

	# Remove secure file	
	purge $FILE_AES_PASSWORD_DECRYPTED
	purge $FILE_RSA_PRIV_KEY_PASSWORD
}

#
# decrypt and Create folder
#
decryptFolderName(){
	local folderName="$1"
	local lOUTPUTDIR="$FOLDER_OUTPUT_DECRYPTED_DATA"
	
	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA$2"/"
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	folderExist "$lOUTPUTDIR"

	# Get AES KEY	
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE=`echo "$folderName" | tr _ \/`
	local OUTPUT_FOLDERNAME=$BASE64_SAFE

	# Decrypt filename
	DECRYPTED_FOLDERNAME=`echo $OUTPUT_FOLDERNAME | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$FILE_AES_PASSWORD_DECRYPTED`
	checkError $?

	local OUTPUT_FOLDERNAME="$lOUTPUTDIR$DECRYPTED_FOLDERNAME"
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir "$OUTPUT_FOLDERNAME"
	fi

	#echo "> decrypt folder $folderName : done"
	echo "$DECRYPTED_FOLDERNAME"
}

decryptfromString()
{
	local fileName=""

	read -p "> Your file or folder name ? " fileName
	
    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"

	# Get AES KEY	
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE=`echo "$fileName" | tr _ \/`
	local OUTPUT_FILENAME=$BASE64_SAFE

	# Decrypt filename
	OUTPUT_FILENAME=`echo $OUTPUT_FILENAME | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$FILE_AES_PASSWORD_DECRYPTED`
	checkError $?

	# Remove secure file	
	purge $FILE_AES_PASSWORD_DECRYPTED
	purge $FILE_RSA_PRIV_KEY_PASSWORD

	echo "> Decrypt : $OUTPUT_FILENAME"
}

genkey()
{
	local RSAKEY_PREFIX=data
	local lRSAKEY_PASSWORD=""
	local lRSA_PRIV_KEY=$(windowsPathConverter "$FOLDER_WORKSPACE$RSAKEY_PREFIX""_PRIV.pem")
	local lRSA_PUB_KEY=$(windowsPathConverter "$FOLDER_WORKSPACE$RSAKEY_PREFIX""_PUB.pem")
	local lAESPASSWORD_enc=$(windowsPathConverter "$FILE_AES_PASSWORD_DECRYPTED"".enc")
	local lFILE_RSA_PRIV_KEY_PASSWORD=$(windowsPathConverter "$FILE_RSA_PRIV_KEY_PASSWORD")

	# Get RSA_PRIV_KEY_PASSWORD
	read -p "> Your password ? " lRSAKEY_PASSWORD
	echo $lRSAKEY_PASSWORD > $FILE_RSA_PRIV_KEY_PASSWORD
	echo $FILE_RSA_PRIV_KEY_PASSWORD

	echo "> GENKEY : START"
	 
	# Generate RSA Key Pair 
	file=$lRSA_PRIV_KEY
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit 1
	else
		echo "Generating key $lRSA_PRIV_KEY"
		openssl genrsa -aes256 -passout file:"$lFILE_RSA_PRIV_KEY_PASSWORD" -out "$lRSA_PRIV_KEY" 4096 -noout
		checkError $?		
	fi

	# Generate random AES Password
	file=$FILE_AES_PASSWORD_DECRYPTED
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit 1		
		exit
	else
		echo "Generate a 256 bit (32 byte) random key"
		openssl rand -base64 32 > $FILE_AES_PASSWORD_DECRYPTED
		checkError $?
	fi

	# Export Public key
	file=$lRSA_PUB_KEY
	if [ ! -f "$file" ]
	then
		openssl rsa -passin file:"$lFILE_RSA_PRIV_KEY_PASSWORD" -pubout -in "$lRSA_PRIV_KEY" -out "$lRSA_PUB_KEY"
		checkError $?		
	fi

	# Encrypt AES Password
	file=$lAESPASSWORD_enc
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit 1
	else
		openssl rsautl -passin file:"$lFILE_RSA_PRIV_KEY_PASSWORD" -encrypt -inkey "$lRSA_PUB_KEY" -pubin -in "$FILE_AES_PASSWORD_DECRYPTED" -out "$lAESPASSWORD_enc"
		checkError $?		
	fi

	# Remove secure file
	purge $FILE_AES_PASSWORD_DECRYPTED
	purge $FILE_RSA_PRIV_KEY_PASSWORD

	echo "> GENKEY : DONE"
}



menu()
{
	PS3='Please enter your choice: '
	options=("encrypt" "decrypt" "genkey" "decryptString" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"encrypt")
				encryptAES
				;;
			"decrypt")
				decryptAES
				;;
			"genkey")
				genkey
				;;
			"decryptString")
				decryptfromString
				;;				
			"Quit")
				break
				;;
			*) echo invalid option;;
		esac
	done

	# Remove secure file
	purge $FILE_AES_PASSWORD_DECRYPTED
	purge $FILE_RSA_PRIV_KEY_PASSWORD

	exit
}

# 1 : $TARGET 
# 2 : $FILE_AES_PASSWORD_ENCRYPTED 
# 3 : $FILE_RSA_PRIV_KEY
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
	local folder="$1"
	if [ ! -d "$folder" ]
	then
		echo "folder $folder not found."
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
	local file=""
	local lRSAKEY_PASSWORD=""

    file=$FILE_RSA_PRIV_KEY_PASSWORD
	if [ ! -f "$file" ]
	then
		read -p "> Your password ? " lRSAKEY_PASSWORD
		echo $lRSAKEY_PASSWORD > $FILE_RSA_PRIV_KEY_PASSWORD
	fi	

	file=$FILE_AES_PASSWORD_DECRYPTED
	if [ ! -f "$file" ]
	then
		openssl rsautl -passin file:$FILE_RSA_PRIV_KEY_PASSWORD -decrypt -inkey "$FILE_RSA_PRIV_KEY" -in "$FILE_AES_PASSWORD_ENCRYPTED" -out "$file"
		checkError $?
	fi

}

checkError()
{
	if [ $1 -ne 0 ]; then
		echo FAIL
		# Remove secure file
		purge $FILE_AES_PASSWORD_DECRYPTED
		purge $FILE_RSA_PRIV_KEY_PASSWORD			
		exit 1
	fi
}

purge()
{
	local lfile=$1
	
	if [ -f "$lfile" ]
	then
		rm $lfile
	fi
}

######
# Main method
######
main() {
	#menu
	genkey
}

main "$@"
