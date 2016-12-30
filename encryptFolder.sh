#!/bin/bash

#
# Convert path for OpenSSL on CigWin
#
windowsPathConverter()
{
	local lUname;
	lUname=$(uname -s);
	local result;
	result=$(expr substr "$lUname" 1 10);
	
	if [[ "$result" == "MINGW32_NT" || "$result" == "MINGW64_NT" ]]; then
		# Do something under Windows NT platform
		local lCONVERT;
		lCONVERT=$(cygpath -p -w "$1");
		echo "$lCONVERT";
	else 
		echo "$1";
	fi
}

declare -r FOLDER_WORKSPACE="/e/temp/OpenSSH/";
declare -r TARGET="$3";
declare -r FILE_RSA_PRIV_KEY="$1";
declare temp_FILE_RSA_PRIV_KEY_PASSWORD;
temp_FILE_RSA_PRIV_KEY_PASSWORD=$(windowsPathConverter "$FOLDER_WORKSPACE""_test.lock");
declare -r FILE_RSA_PRIV_KEY_PASSWORD=$temp_FILE_RSA_PRIV_KEY_PASSWORD;
declare -r FILE_AES_PASSWORD_ENCRYPTED="$2";
declare temp_FILE_AES_PASSWORD_DECRYPTED;
temp_FILE_AES_PASSWORD_DECRYPTED=$(windowsPathConverter "$FOLDER_WORKSPACE""key.bin");
declare -r FILE_AES_PASSWORD_DECRYPTED=$temp_FILE_AES_PASSWORD_DECRYPTED;
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
		echo "ERROR - $lResult is not valid";
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
	extractkey

	# Encrypt File name
	local ENCRYPTED_FILENAME;
	ENCRYPTED_FILENAME=$(echo "$fileName" | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?
	
	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_FILENAME" | tr '/' _);
	local OUTPUT_FILENAME=$lOUTPUTDIR$BASE64_SAFE;
	local OUTPUT_FILENAME_SING=$lOUTPUTDIR$BASE64_SAFE".sha256";
	
	# Encrypt 
	openssl enc -aes-256-cbc -salt -in "$file" -out "$OUTPUT_FILENAME" -pass file:"$FILE_AES_PASSWORD_DECRYPTED"
	checkError $?

	# Generate signature
	local lRSA_PRIV_KEY=$FOLDER_WORKSPACE"data_PRIV.pem";
	local lRSA_PUB_KEY=$FOLDER_WORKSPACE"data_PUB.pem";
	openssl dgst -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -sha256 -sign "$lRSA_PRIV_KEY" -out "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME"
	checkError $?

	# Check signature
	openssl dgst -sha256 -verify "$lRSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$OUTPUT_FILENAME"
	checkError $?

	echo "> Encrypt $fileName : done";
	echo "> Output directory : $lOUTPUTDIR";
}

#
# Recursive folder parsing
#
encryptFolder(){
	local folderFullPath="";

	for file in "$1"/*
	do
		if [ ! -d "${file}" ]
		then
		echo .
			encryptFile "${file}" "$2"
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
			encryptFolder "${file}" "$result";
		fi
	done

	# Remove secure file
	autoPurge

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
	checkOpenSSLfile "$FILE_AES_PASSWORD_ENCRYPTED" "$FILE_RSA_PRIV_KEY"
	folderExist "$lOUTPUTDIR"

	# Get AES KEY	
	extractkey

	# Encrypt File name
	local ENCRYPTED_FOLDERNAME;
	ENCRYPTED_FOLDERNAME=$(echo "$folderName" | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?	

	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_FOLDERNAME" | tr '/' _);
	local OUTPUT_FOLDERNAME=$lOUTPUTDIR$BASE64_SAFE;
	
	# Check if output folder already exist
	if [ ! -d "$OUTPUT_FOLDERNAME" ]
	then
		mkdir "$OUTPUT_FOLDERNAME";
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
		echo "ERROR - $result is not valid";
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
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$fileName" | tr _ '/');
	local OUTPUT_FILENAME=$BASE64_SAFE;

	# Decrypt filename
	OUTPUT_FILENAME=$(echo "$OUTPUT_FILENAME" | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?

	# Decrypt file
	openssl enc -d -aes-256-cbc -in "$file" -out "$lOUTPUTDIR$OUTPUT_FILENAME" -pass file:"$FILE_AES_PASSWORD_DECRYPTED"
	checkError $?

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
	local lRSA_PUB_KEY=$FOLDER_WORKSPACE"data_PUB.pem";
	local OUTPUT_FILENAME_SING=$file".sha256";	

	# Check signature
	openssl dgst -sha256 -verify "$lRSA_PUB_KEY" -signature "$OUTPUT_FILENAME_SING" "$file"
	checkError $?

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
		fi
	done

	# Remove secure file
	autoPurge
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
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$folderName" | tr _ '/');
	local OUTPUT_FOLDERNAME=$BASE64_SAFE;

	# Decrypt filename
	DECRYPTED_FOLDERNAME=$(echo "$OUTPUT_FOLDERNAME" | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
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
	extractkey

	# Convert base64 safe to real base64
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$fileName" | tr _ '/');
	local OUTPUT_FILENAME=$BASE64_SAFE;

	# Decrypt filename
	OUTPUT_FILENAME=$(echo "$OUTPUT_FILENAME" | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?

	# Remove secure file
	autoPurge

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
	extractkey

	# Encrypt File name
	local ENCRYPTED_STRING;
	ENCRYPTED_STRING=$(echo "$fileName" | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:"$FILE_AES_PASSWORD_DECRYPTED");
	checkError $?	

	# Convert base64 to base64 safe
	local BASE64_SAFE;
	BASE64_SAFE=$(echo "$ENCRYPTED_STRING" | tr '/' _);

	# Remove secure file
	autoPurge

	echo "> Encrypt : [$BASE64_SAFE]";
}

# 
# Generate RSA KeyPair
#
genkey()
{
	local RSAKEY_PREFIX=data;
	local lRSAKEY_PASSWORD="dummypassword";
	local lRSA_PRIV_KEY=$FOLDER_WORKSPACE$RSAKEY_PREFIX"_PRIV.pem";
	local lRSA_PUB_KEY=$FOLDER_WORKSPACE$RSAKEY_PREFIX"_PUB.pem";
	local lAESPASSWORD_enc=$FILE_AES_PASSWORD_DECRYPTED".enc";

	# Get RSA_PRIV_KEY_PASSWORD
	read -r -s -p "> Your private password: " lRSAKEY_PASSWORD
	echo "$lRSAKEY_PASSWORD" > "$FILE_RSA_PRIV_KEY_PASSWORD"

	echo "> GENKEY : START"
	 
	# Generate RSA Key Pair 
	file=$lRSA_PRIV_KEY
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found.";
		exit 1;
	else
		echo "Generating $lRSA_PRIV_KEY";
		openssl genrsa -aes256 -passout file:"$FILE_RSA_PRIV_KEY_PASSWORD" -out "$lRSA_PRIV_KEY" 4096 -noout
		checkError $?		
	fi

	# Generate random AES Password
	file=$FILE_AES_PASSWORD_DECRYPTED;
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found."
		exit 1		
		exit
	else
		echo "Generate a 2048 bit (256 byte) random key";
		openssl rand -out "$FILE_AES_PASSWORD_DECRYPTED" 256
		checkError $?
	fi

	# Export Public key
	file=$lRSA_PUB_KEY
	if [ ! -f "$file" ]
	then
		openssl rsa -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -pubout -in "$lRSA_PRIV_KEY" -out "$lRSA_PUB_KEY"
		checkError $?		
	fi

	# Encrypt AES Password
	file=$lAESPASSWORD_enc
	if [ -f "$file" ]
	then
		echo "WARNING ! $file already found.";
		exit 1;
	else
		openssl rsautl -passin file:"$FILE_RSA_PRIV_KEY_PASSWORD" -encrypt -inkey "$lRSA_PUB_KEY" -pubin -in "$FILE_AES_PASSWORD_DECRYPTED" -out "$lAESPASSWORD_enc"
		checkError $?		
	fi

	# Remove secure file
	autoPurge

	echo "> GENKEY : DONE";
}

#
# Startup menu
#
menu()
{
	PS3='Please enter your choice: '
	options=("encrypt" "decrypt" "genkey" "decryptString" "encryptString" "Quit")
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
			"encryptString")
				encryptfromString
				;;								
			"Quit")
				break
				;;
			*) echo invalid option;;
		esac
	done

	# Remove secure file
	autoPurge

	exit
}

#
# Required files for this script
# 1 : $FILE_AES_PASSWORD_ENCRYPTED 
# 2 : $FILE_RSA_PRIV_KEY
#
checkOpenSSLfile()
{
	local file="$1";

	if [ ! -f "$file" ]
	then
		echo "$file not found.";
		exit 1;
	fi
	
	file="$2"
	if [ ! -f "$file" ]
	then
		echo "$file not found.";
		exit 1;
	fi
}

#
# Check if file exist
#
fileExist()
{
	local file="$1";
	if [ ! -f "$file" ]
	then
		echo "file $file not found.";
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
		echo "folder $folder not found.";
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
		echo "ERROR - $file is not valid";
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
		echo FAIL;

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


######
# Main method
######
main() {
	menu;
}

main "$@"