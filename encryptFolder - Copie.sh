#!/bin/bash

declare -r RSA_KEY=$1
declare -r ASEPASS=$2
declare -r FILETARGET=$3
declare -r WORKSPACE='E:\temp\OpenSSH\'
declare -r CURRENT=$PWD

encryptRSA()
{
	local RSAKEY=$RSA_KEY # $RSAKEY"_PRIV.pem"
	local filename="$FILETARGET"

	# File
	local filepath="./"
	local filename="Kaiba_01.mp4"
	
	file=$filename
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	file=$RSAKEY
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
    file=$RSAKEY".pub.pem"
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Export publique key"
		openssl rsa -pubout -in $RSAKEY -out $WORKSPACE".pub.pem"
	fi	

	echo "> ENCRYPT : START"
	local ENCRYPTED_FILENAME=`echo $filename | openssl rsautl -encrypt -inkey $WORKSPACE".pub.pem" -pubin`
	ENCRYPTED_FILENAME=`openssl enc -base64 <<< $ENCRYPTED_FILENAME`
	
	local HASHED_FILENAME="TEST"
	
	echo $ENCRYPTED_FILENAME > HASHED_FILENAME.manifest
	
	echo "> FILENAME : " $HASHED_FILENAME
	openssl rsautl -encrypt -inkey $WORKSPACE".pub.pem" -pubin -in $filename -out $HASHED_FILENAME

	echo "> ENCRYPT : DONE"
	
	exit
}

encryptAES()
{
	local RSAKEY=$RSA_KEY # $RSAKEY"_PRIV.pem"
	local AESKEY=$ASEPASS # ./key.bin.enc 
	local filename="$FILETARGET"

	# File
	#local filepath="./"
	#local filename="Kaiba_01.mp4"
	
	file=$filename
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	file=$AESKEY
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	file=$RSAKEY
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
    file=$RSAKEY".pub.pem"
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Export publique key"
		openssl rsa -pubout -in $RSAKEY -out $WORKSPACE".pub.pem"
	fi

	echo "> ENCRYPT : START"
	echo ">> Get AES KEY"
	openssl rsautl -decrypt -inkey $RSAKEY -in $AESKEY -out $WORKSPACE"key.bin"
	
	echo ">> Get Encrypted filename"
	temp=`echo $filename | sed 's/ /_/g'`
	echo $temp
	ENCRYPTED_FILENAME=`echo $temp | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:$WORKSPACE"key.bin"`

	echo "> ENCRYPTED_FILENAME : " $ENCRYPTED_FILENAME
	HEXVAL=$(xxd -pu <<< "$ENCRYPTED_FILENAME")
	echo "> HEX_ENCRYPTED_FILENAME : " $HEXVAL
	
	echo ">> Encrypt $filename to $HEXVAL"
	openssl enc -aes-256-cbc -salt -in "$filename" -out "$HEXVAL" -pass file:$WORKSPACE"key.bin"

	rm $WORKSPACE"key.bin"
	
	echo "> ENCRYPT : DONE"
	
	exit
}

decrypt()
{
	local RSAKEY=$RSA_KEY # $RSAKEY"_PRIV.pem"
	local AESKEY=$ASEPASS # ./key.bin.enc 
	local HEXVAL="$FILETARGET"

	file=$HEXVAL
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	file=$AESKEY
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	file=$RSAKEY
	if [ -f "$file" ]
	then
		echo .
	else
		echo "$file not found."
		exit
	fi
	
	echo "> DECRYPT : START"
	openssl rsautl -decrypt -inkey $RSAKEY -in $AESKEY -out $WORKSPACE"key.bin" 
	
	local filename=`echo $HEXVAL | xxd -r -p`
	echo "> FILENAME CONVERT : $HEXVAL > $filename"
	filename=`echo $filename | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:$WORKSPACE"key.bin"`
	echo "> FILENAME DECRYPT : " $filename

	openssl enc -d -aes-256-cbc -in ./$HEXVAL -out $filename -pass file:$WORKSPACE"key.bin"

	rm $WORKSPACE"key.bin"
	echo "> DECRYPT : DONE"	
	
	exit
}

genkey()
{
	#local RSAKEY=$RSA_KEY # $RSAKEY"_PRIV.pem"
	#local AESKEY=$ASEPASS # ./key.bin.enc 
	#local HEXVAL="$FILETARGET"
	
	#Required
	# RSAKEY=$1
	RSAKEY=data

	# File
	filepath="./"
	filename="Kaiba_01.mp4"

	# Private Key password
	password=dummypassword
	
	echo "> GENKEY : START"
	 
	file=$RSAKEY"_PRIV.pem"
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Generating key request for $RSAKEY"
		openssl genrsa -passout pass:$password -out $RSAKEY"_PRIV.pem" 4096 -noout
	fi

	file=key.bin
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Generate a 256 bit (32 byte) random key"
		openssl rand -base64 32 > key.bin
	fi

	file=$RSAKEY"_PUB.pem"
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Export publique key"
		openssl rsa -pubout -in $RSAKEY"_PRIV.pem" -out $RSAKEY"_PUB.pem"
	fi

	file=key.bin.enc
	if [ -f "$file" ]
	then
		echo "$file found."
	else
		echo "Encrypt AES KEY"
		openssl rsautl -encrypt -inkey $RSAKEY"_PUB.pem" -pubin -in key.bin -out key.bin.enc 
	fi

	# openssl enc -aes-256-cbc -salt -in "Kaiba_01.mp4" -out "Kaiba_01.mp4.enc" -pass file:./key.bin

	# echo "> ENCCRYPT : START"
	# testt=`echo $filename | openssl enc -base64 -e -aes-256-cbc -nosalt -pass file:./key.bin`
	# openssl enc -aes-256-cbc -salt -in "Kaiba_01.mp4" -out $testt".enc" -pass file:./key.bin

	# echo "> FILENAME : " $testt
	# HEXVAL=$(xxd -pu <<< "$testt")
	# echo "> FILENAME : " $HEXVAL
	# openssl enc -aes-256-cbc -salt -in $filename -out $HEXVAL -pass file:./key.bin

	# echo "> ENCCRYPT : DONE"

	# echo "> DECRYPT : START"
	# openssl rsautl -decrypt -inkey $RSAKEY"_PRIV.pem" -in ./key.bin.enc -out ./decrypt/key.bin 
	# filename=`echo $HEXVAL | xxd -r -p`
	# echo "> FILENAME : " $filename
	# filename=`echo $filename | openssl enc -base64 -d -aes-256-cbc -nosalt -pass file:./decrypt/key.bin`
	# echo "> FILENAME : " $filename

	# openssl enc -d -aes-256-cbc -in ./$HEXVAL -out ./decrypt/$filename -pass file:./decrypt/key.bin

	rm ./decrypt/key.bin
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
				#encryptRSA
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

######
# Main method
######
main() {
	menu
}

main "$@"