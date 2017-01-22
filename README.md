# OpensslCloudSecure
Openssl script for securing files and folders in cloud storage.


## Menu

1. Encrypt file or folders
2. Decrypt file or folders
3. Generate KeyPair (RSA Private key and AES password)
4. Encrypt string from input
5. Decrypt string from input
6. List encrypted files/folders
7. Exit script

## Get Started 
### 1) Encrypt (recursive) :

> By default the output directory is => $PWD"OUTPUT"

```bash
root@TESTING-DEB:/mnt/c/temp/FILES# ./encryptFolder.sh /mnt/e/temp/OpenSSH/data_PRIV.pem /mnt/e/temp/OpenSSH/key.bin.enc ./Video/
1) encrypt        3) genkey         5) encryptString
2) decrypt        4) decryptString  6) Quit
Please enter your choice: 1
Verified OK
> Encrypt c01b39c7a35ccc3b081a3e83d2c71fa9a767ebfeb45c69f08e17dfe3ef375a7b.txt : done
> Output directory : /mnt/c/temp/FILES/OUTPUT//QXHSM9gZ8IJOJh8YwpGLlyc3sEEYN6TxkR+FgOCzWCU=/
Verified OK
> Encrypt [MeTEam]-GNU GPL video vostfr HD .mp4 : done
> Output directory : /mnt/c/temp/FILES/OUTPUT//QXHSM9gZ8IJOJh8YwpGLlyc3sEEYN6TxkR+FgOCzWCU=/
Verified OK
```

### 2) Decrypt (recursive) :

> By default the output directory is => $PWD"OUTPUT_CLEAR"

```bash
root@TESTING-DEB:/mnt/c/temp/FILES# ./encryptFolder.sh /mnt/e/temp/OpenSSH/data_PRIV.pem /mnt/e/temp/OpenSSH/key.bin.enc ./OUTPUT/
1) encrypt        3) genkey         5) encryptString
2) decrypt        4) decryptString  6) Quit
Please enter your choice: 2
> Decrypt C6K21H_GcAc2+vI62EicK0BBFr1kf6Gy4meuqCqUuYbqVxhpn7tX9A1L2sRusik0jOFpp0664mCLMs478lrlfQ== : done
> Output directory : /mnt/c/temp/FILES/OUTPUT_CLEAR//GNU GPL video (1 - 50)/
> Check signature  : start
Verified OK
```

### 3) List encrypted files/folders (recursive) :

```bash
root@TESTING-DEB:/mnt/c/temp/FILES# ./build.sh && ./encryptFolder.sh /mnt/e/temp/OpenSSH/data_PRIV.pem /mnt/e/temp/OpenSSH/key.bin.enc ./OUTPUT/
1) encrypt        3) genkey         5) encryptString  7) Quit
2) decrypt        4) decryptString  6) ls
Please enter your choice: 6
├──Video
│   ├──GNU GPL video
│   │   ├──GNU GPL - 01.mp4
│   │   ├──GNU GPL - 01.mkv
│   │   ├──GNU GPL - 01.avi
root@WINDOWS-WORK-PC:/mnt/c/temp/FILES#
```