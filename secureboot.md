# (Work in Progress) Adding Secureboot to a System that boots via Efistub 

https://nwildner.com/posts/2020-07-04-secure-your-boot-process/

This Document will help to install my own Keys, sign the kernel (which will not be secured. ie. it will still load unsigned modules)
also I still want to be able to boot Windows, so Microsofts keys have to be added to db.

This is just because i'd like to know how things work, especially how to keep windows still booting in secureboot mode despite using my own keys. To make this a really secure setup you would have to:
- Password protect the uefi, so secureboot can not be disabled
- Store the PK encrypted
- Force kernel signature validation, so only signed modules will be loaded

## Explanation

There are four main EFI “variables” used to create a basic secureboot Root of Trust environment:
 - PK: The Platform Key, the master one, the ring to rule them all. The holder of a PK can install a new PK and update the KEK.
 - KEK: Key Exchange Key is a secondary key used to sign EFI executables directly or a key used to signd the db and dbx databases.
 - db: The signature databse is a list with all allowed signing certificates or criptografy hashes to allowed binaries. We will use THIS db key to sign our Linux Kernel.
 - dbx: The dark side of the db. Inverse db. “not-good-db”. You name it. It’s the list containing all keys that are not allowed.

