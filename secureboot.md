# Adding Secureboot to a System that boots via Efistub 

https://nwildner.com/posts/2020-07-04-secure-your-boot-process/

## so?

There are four main EFI “variables” used to create a basic secureboot Root of Trust environment:
 - PK: The Platform Key, the master one, the ring to rule them all. The holder of a PK can install a new PK and update the KEK.
 - KEK: Key Exchange Key is a secondary key used to sign EFI executables directly or a key used to signd the db and dbx databases.
 - db: The signature databse is a list with all allowed signing certificates or criptografy hashes to allowed binaries. We will use THIS db key to sign our Linux Kernel.
 - dbx: The dark side of the db. Inverse db. “not-good-db”. You name it. It’s the list containing all keys that are not allowed.
