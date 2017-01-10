#!/bin/bash

declare -r RED='\033[0;31m'
declare -r NC='\033[0m' # No Color
#
#
#
ifIsDefined()
{
	if [ -n "$1" ]
	then
		echo "$1";
	else
		echo "$2";
	fi
}

#
# Convert path for OpenSSL on CigWin
#
windowsPathConverter()
{
	local lUname;
	lUname=$(uname -s);
	local result;
	result=$(expr substr "$lUname" 1 10);
	
	# Check if is Windows NT platform
	if [[ "$result" == "MINGW32_NT" || "$result" == "MINGW64_NT" ]]; then
		# Do something under Windows NT platform
		local lCONVERT;
		lCONVERT=$(cygpath -p -w "$1");
		echo "$lCONVERT";
	else 
		echo "$1";
	fi
}

declare -r FOLDER_WORKSPACE="/mnt/e/temp/OpenSSH/";
declare -r TARGET="$3"; # File or Folder
declare -r FILE_RSA_KEY_PREFIX=data;

declare temp_FILE_RSA_PRIV_KEY;
temp_FILE_RSA_PRIV_KEY=$(ifIsDefined "$1" "$FOLDER_WORKSPACE$FILE_RSA_KEY_PREFIX""_PRIV.pem");
declare -r FILE_RSA_PRIV_KEY=$temp_FILE_RSA_PRIV_KEY;

declare -r FILE_RSA_PUB_KEY="$FOLDER_WORKSPACE$FILE_RSA_KEY_PREFIX""_PUB.pem";

declare temp_FILE_RSA_PRIV_KEY_PASSWORD;
temp_FILE_RSA_PRIV_KEY_PASSWORD=$(windowsPathConverter "$FOLDER_WORKSPACE""_test.lock");
declare -r FILE_RSA_PRIV_KEY_PASSWORD=$temp_FILE_RSA_PRIV_KEY_PASSWORD;

declare temp_FILE_AES_PASSWORD_DECRYPTED;
temp_FILE_AES_PASSWORD_DECRYPTED=$(windowsPathConverter "$FOLDER_WORKSPACE""key.bin");
declare -r FILE_AES_PASSWORD_DECRYPTED=$temp_FILE_AES_PASSWORD_DECRYPTED;

declare temp_FILE_AES_PASSWORD_ENCRYPTED;
temp_FILE_AES_PASSWORD_ENCRYPTED=$(ifIsDefined "$2" "$FILE_AES_PASSWORD_DECRYPTED"".enc");
declare -r FILE_AES_PASSWORD_ENCRYPTED=$temp_FILE_AES_PASSWORD_ENCRYPTED;

declare -r FOLDER_OUTPUT_ENCRYPTED_DATA=$PWD"/OUTPUT/";
declare -r FOLDER_OUTPUT_DECRYPTED_DATA=$PWD"/OUTPUT_CLEAR/";


encryptAES()
{
	local lResult;
	lResult=$(checkfolder "$TARGET");

	if [[ $lResult = "0" ]]
	then
		encryptFolder "$TARGET";
	elif [[ $lResult = "1" ]]
	then
		encryptFile "$TARGET";
	else
		echoerr "ERROR - $lResult is not valid";
		exit 1;
	fi
}

#
# Encrypt $1 file
# [optional] add $2 like aditionnal folder
#
encryptFile(){
	local file="$1";
	local fileName;
	fileName=$(basename "$1");
	local lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA;

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA$2"/"
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";
	fileExist "$file";
	folderExist "$lOUTPUTDIR";

	# Get AES KEY	
	extractkey;

	# Encrypt File name
	local ENCRYPTED_FILENAME;
	ENCRYPTED_FILENAME=$(echo "$fileName" | openssl enc -base64 -A -e -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?;
	
	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_FILENAME" | tr '/' _);
	local OUTPUT_FILENAME=$lOUTPUTDIR$BASE64_SAFE;
	local OUTPUT_FILENAME_SING=$OUTPUT_FILENAME".sha256";

	if [ $(echo "$BASE64_SAFE" | wc -l) -gt 1 ];
	then
		echoerr "WARNING : File name is too long for base64 encoding [$fileName]";
		
		# Remove secure file
		autoPurge;
		exit 1;
	fi 

	# Encrypt 
	local tempFile=$(windowsPathConverter "$file");
	local tempOUTPUT_FILENAME=$(windowsPathConverter "$OUTPUT_FILENAME");
	openssl enc -aes-256-cbc -salt -in "$tempFile" -out "$tempOUTPUT_FILENAME" -pass file:"$FILE_AES_PASSWORD_DECRYPTED";
	checkError $?;

	# Generate signature
	openssl dgst -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -sha256 -sign "$FILE_RSA_PRIV_KEY" -out "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME";
	checkError $?;

	# Check signature
	openssl dgst -sha256 -verify "$FILE_RSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME";
	checkError $?;

	echo "> Encrypt $fileName : done";
	echo "> Output directory : $lOUTPUTDIR";
}

#
# Recursive folder parsing
#
encryptFolder(){	

	local folderFullPath;

	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
			encryptFile "${file}" "$2";
		else
			local folderName;
			folderName=$(basename "${file}");

			if [ -n "$folderFullPath" ]
			then
				folderFullPath="$folderFullPath/$2";
			else
				folderFullPath=$folderFullPath$2;
			fi

			local result;
			result=$(encryptFolderName "$folderName" "$folderFullPath");
			result="$folderFullPath/$result";

			# Parse folder
			encryptFolder "${file}" "$result";
			folderFullPath="";
		fi
	done

	# Remove secure file
	autoPurge;
}

#
# Encrypt folder name and create folder with encrypted folder name
#
encryptFolderName(){
	local folderName="$1";
	local lOUTPUTDIR="$FOLDER_OUTPUT_ENCRYPTED_DATA";

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_ENCRYPTED_DATA$2"/";
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";
	folderExist "$lOUTPUTDIR";

	# Get AES KEY	
	extractkey;

	# Encrypt File name
	local ENCRYPTED_FOLDERNAME;
#	local HASHED_ENCRYPTED_FOLDERNAME;
	ENCRYPTED_FOLDERNAME=$(echo "$folderName" | openssl enc -base64 -A -e -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
#	HASHED_ENCRYPTED_FOLDERNAME=$(echo "$ENCRYPTED_FOLDERNAME" | openssl dgst -sha1);
#	echo "HASH : $HASHED_ENCRYPTED_FOLDERNAME";
	checkError $?;

	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_FOLDERNAME" | tr '/' _);
	local OUTPUT_FOLDERNAME=$lOUTPUTDIR$BASE64_SAFE;
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir "$OUTPUT_FOLDERNAME";
		#touch "$lOUTPUTDIR""$BASE64_SAFE.manifest";
	fi

	#echo "> encrypt folder $folderName : done"
	echo "$BASE64_SAFE";
}

decryptAES()
{
	local result;
	result=$(checkfolder "$TARGET");
	
	if [[ $result = "0" ]]
	then
		decryptFolder "$TARGET";
	elif [[ $result = "1" ]]
	then
		decryptFile "$TARGET";
	else
		echoerr "ERROR - $result is not valid";
		exit 1;
	fi
}

# 
# Decrypt $1 file
# [optional] add $2 like aditionnal folder
# 
decryptFile()
{
	local file="$1";
	local fileName;
	fileName=$(basename "$1");
	local lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA;

	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA$2"/";
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";
	fileExist "$file";
	folderExist "$lOUTPUTDIR";

	# Get AES KEY	
	extractkey;

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$fileName" | tr _ '/');
	local OUTPUT_FILENAME=$BASE64_SAFE;

	# Decrypt filename
	OUTPUT_FILENAME=$(echo "$OUTPUT_FILENAME" | openssl enc -base64 -d -A -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?;

	# Decrypt file
	local tempOUTPUTDIR=$(windowsPathConverter "$lOUTPUTDIR$OUTPUT_FILENAME");
	openssl enc -d -aes-256-cbc -in "$file" -out "$tempOUTPUTDIR" -pass file:"$FILE_AES_PASSWORD_DECRYPTED";
	checkError $?;

	echo "> Decrypt $fileName : done";
	echo "> Output directory : $lOUTPUTDIR";
}

#
# Check if $1 is corrupted
#
chekcSingFile()
{
	local file="$1";
	file="${file%.*}";
	
    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";
	fileExist "$file";

	echo "> Check signature $fileName : start";
	
	# Generate signature
	local OUTPUT_FILENAME_SING=$file".sha256";	

	# Check signature
	openssl dgst -sha256 -verify "$FILE_RSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$file";
	checkError $?;

	echo "> Check signature $fileName : done";
}

#
# Recursive folder parsing for decrypt
#
decryptFolder(){
	local folderFullPath="";

	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
			local filename;
			filename=$(basename "${file}");
			local extension="${filename##*.}";

			if [[ "$extension" = "sha256" ]]
			then
				chekcSingFile "${file}";
			else
				decryptFile "${file}" "$2";
			fi
		else
			local folderName;
			folderName=$(basename "${file}");
	
			if [ -n "$folderFullPath" ]
			then
				folderFullPath="$folderFullPath/$2";
			else
				folderFullPath=$folderFullPath$2;
			fi

			local result;
			result=$(decryptFolderName "$folderName" "$folderFullPath");
			result="$folderFullPath/$result";
			decryptFolder "${file}" "$result";
			folderFullPath="";
		fi
	done

	# Remove secure file
	autoPurge;
}

#
# Decrypt folder name and create folder with clear folder name
#
decryptFolderName(){
	local folderName="$1";
	local lOUTPUTDIR="$FOLDER_OUTPUT_DECRYPTED_DATA";
	
	if [ -n "$2" ]
	then
		lOUTPUTDIR=$FOLDER_OUTPUT_DECRYPTED_DATA$2"/";
	fi

    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";
	folderExist "$lOUTPUTDIR";

	# Get AES KEY	
	extractkey;

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$folderName" | tr _ '/');
	local OUTPUT_FOLDERNAME=$BASE64_SAFE;

	# Decrypt filename
	DECRYPTED_FOLDERNAME=$(echo "$OUTPUT_FOLDERNAME" | openssl enc -base64 -d -A -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?

	local OUTPUT_FOLDERNAME="$lOUTPUTDIR$DECRYPTED_FOLDERNAME";
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir "$OUTPUT_FOLDERNAME";
	fi

	#echo "> decrypt folder $folderName : done"
	echo "$DECRYPTED_FOLDERNAME";
}

# 
# Decrypt file or folder name
#
decryptfromString()
{
	local fileName="";

	read -r -p "> Your file or folder name ? " fileName;
	
    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";

	# Get AES KEY	
	extractkey;

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$fileName" | tr _ '/');
	local OUTPUT_FILENAME=$BASE64_SAFE;

	# Decrypt filename
	OUTPUT_FILENAME=$(echo "$OUTPUT_FILENAME" | openssl enc -base64 -d -A -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?;

	# Remove secure file
	autoPurge;

	echo "> Decrypt : [$OUTPUT_FILENAME]";
}

# 
# Encrypt file or folder name
#
encryptfromString()
{
	local fileName="";

	read -r -p "> Your file or folder name ? " fileName;
	
    # If exist
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY";

	# Get AES KEY	
	extractkey;

	# Encrypt File name
	local ENCRYPTED_STRING;
	ENCRYPTED_STRING=$(echo "$fileName" | openssl enc -base64 -e -A -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?;

	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_STRING" | tr '/' _);

	# Remove secure file
	autoPurge;

	echo "> Encrypt : [$BASE64_SAFE]";
}

# 
# Generate RSA KeyPair
#
genkey()
{
	local lINPUT_RSA_PRIV_KEY_PASSWORD;
	
	# Get RSA_PRIV_KEY_PASSWORD
	read -r -s -p "> Your private password: " lINPUT_RSA_PRIV_KEY_PASSWORD;
	echo "$lINPUT_RSA_PRIV_KEY_PASSWORD" > "$FILE_RSA_PRIV_KEY_PASSWORD";

	echo "> GENKEY : START";
	 
	# Generate RSA Key Pair 
	local file=$FILE_RSA_PRIV_KEY;
	if [ -f "$file" ]
	then
		echoerr "WARNING ! $file already found.";
		exit 1;
	else
		echo "Generating $FILE_RSA_PRIV_KEY";
		openssl genrsa -aes256 -passout file:"$FILE_RSA_PRIV_KEY_PASSWORD" -out "$FILE_RSA_PRIV_KEY" 4096 -noout;
		checkError $?;		
	fi

	# Generate random AES Password
	file=$FILE_AES_PASSWORD_DECRYPTED;
	if [ -f "$file" ]
	then
		echoerr "WARNING ! $file already found.";
		exit 1;	
	else
		echo "Generate a 2048 bit (256 byte) random key";
		openssl rand -out "$FILE_AES_PASSWORD_DECRYPTED" 256;
		checkError $?;
	fi

	# Export Public key
	file=$FILE_RSA_PUB_KEY;
	if [ ! -f "$file" ]
	then
		openssl rsa -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -pubout -in "$FILE_RSA_PRIV_KEY" -out "$FILE_RSA_PUB_KEY";
		checkError $?;
	fi

	# Encrypt AES Password
	file=$FILE_AES_PASSWORD_ENCRYPTED;
	if [ -f "$file" ]
	then
		echoerr "WARNING ! $file already found.";
		exit 1;
	else
		openssl rsautl -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -encrypt -inkey "$FILE_RSA_PUB_KEY" -pubin -in "$FILE_AES_PASSWORD_DECRYPTED" -out "$FILE_AES_PASSWORD_ENCRYPTED";
		checkError $?;
	fi

	# Remove secure file
	autoPurge;

	echo "> GENKEY : DONE";
}

#
# Startup menu
#
menu()
{
	PS3='Please enter your choice: ';
	options=("encrypt" "decrypt" "genkey" "decryptString" "encryptString" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"encrypt")
				encryptAES;
				break
				;;
			"decrypt")
				decryptAES;
				break
				;;
			"genkey")
				genkey;
				break
				;;
			"decryptString")
				decryptfromString;
				break
				;;
			"encryptString")
				encryptfromString;
				break
				;;								
			"Quit")
				break
				;;
			*) echo invalid option;;
		esac
	done

	# Remove secure file
	autoPurge;
}

#
# Required files for this script
# 1 : $FILE_AES_PASSWORD_ENCRYPTED 
# 2 : $FILE_RSA_PRIV_KEY
#
checkOpenSSLfile()
{
	fileExist "$1";
	fileExist "$2";
}

#
# Check if file exist
#
fileExist()
{
	local file="$1";
	if [ ! -f "$file" ]
	then
		echoerr "file $file not found.";
		exit 1;
	fi
}

#
# Check if folder exist
#
folderExist()
{
	local folder="$1";
	if [ ! -d "$folder" ]
	then
		echoerr "folder $folder not found.";
		exit 1;
	fi
}

#
# Check $1 type and return value
# 0 = FOLDER
# 1 = FILE
#
checkfolder()
{
	local file="$1";
	local myresult=0;

	if [[ -d "$file" ]]
	then
		myresult=0;
	elif [[ -f "$file" ]]
	then
		myresult=1;
	else
		echoerr "ERROR - $file is not valid";
		exit 1;
	fi

	echo "$myresult";
}

#
# Create FILE_RSA_PRIV_KEY_PASSWORD and FILE_AES_PASSWORD_DECRYPTED
#
extractkey()
{
	# Get AES KEY	
	local file="";
	local lRSAKEY_PASSWORD="";

    file=$FILE_RSA_PRIV_KEY_PASSWORD;
	if [ ! -f "$file" ]
	then
		read -r -s -p "> Your private password: " lRSAKEY_PASSWORD;
		echo "$lRSAKEY_PASSWORD" > "$FILE_RSA_PRIV_KEY_PASSWORD";
	fi	

	file=$FILE_AES_PASSWORD_DECRYPTED;
	if [ ! -f "$file" ]
	then
		openssl rsautl -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -decrypt -inkey "$FILE_RSA_PRIV_KEY" -in "$FILE_AES_PASSWORD_ENCRYPTED" -out "$file";
		checkError $?;
	fi
}

checkError()
{
	if [ "$1" -ne 0 ]; then
		echoerr "Script fail";

		# Remove secure file
		autoPurge;	

		exit 1;
	fi
}

#
# Remove secure file
#
autoPurge()
{
	purge "$FILE_AES_PASSWORD_DECRYPTED";
	purge "$FILE_RSA_PRIV_KEY_PASSWORD";	
}

#
# Remove file
#
purge()
{
	local lfile=$1;

	if [ -f "$lfile" ]
	then
		rm "$lfile";
	fi
}

#
#
# James Roth - < http://stackoverflow.com/questions/2990414/echo-that-outputs-to-stderr >
echoerr() {
	 echo -e "$RED$@$NC" 1>&2; 
}

######
# Main method
######
main() {
	menu;
}

main "$@"