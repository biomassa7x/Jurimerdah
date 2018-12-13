#!/bin/bash
#
# jurimerdah.sh
# alpha version 0.1 build 201812111706
# (c)2018 Biomassa (F.G.Massa) - biomassa@gmail.com
# 
# Description:
# Script to Backup dir(s) via rsync and DB via mysqldump (combo)
# 
# To do:
# - logging
# - email notification
# - separated configuration file
# - encrypt archive with a random generated password (sent by mail after backup)
# - multiple db backup
#

##### Let's begin! #####

# Define generic vars

myBackupName="www.gamescollection.it"
mySshRemote="yes"
myBackupSQL="yes"
myBackupType=""
myBackupRetention="30"

# Define remote ssh host

myHost="www.gamescollection.it"
myUserId="gamescollection_web"
myIdRsa="$HOME/.ssh/id_rsa.gamescollection"

# Define data source(s)

mySource=("wp-config.php" "www.gamescollection.it")
myExclude="wp-snapshots"

# Define source DB

myDbHost="db.massaweb.com"
myDbName="gc2017"
myDbUser="gc2017dbuser"
myDbPass="74VpYM7nSv"

# Define destination directory

myDestinationDir="backup"
myDestinationDump="$myDestinationDir/$myDbName.sql"

# First of all, some temporary items... ;-)

timestamp=`date '+%Y-%m-%d_%H%M'`
mkdir -p $myDestinationDir

# Let's do the job!
#

# 1. Copy source to destination vi Rsync
for tempSource in "${mySource[@]}"
do
	if [ $mySshRemote == "yes" ]
	then
		rsync -Pav --delete -e "ssh -i $myIdRsa" --exclude=$myExclude $myUserId@$myHost:$tempSource $myDestinationDir/
	else
		rsync -av --delete --exclude=$myExclude $tempSource $myDestinationDir/
	fi
done

# 2. Delete old dumps and do a new one
if [ $myBackupSQL == "yes" ]
then
	rm -f $myDestinationDir/$myDbName.sql.bak*
	if [ $mySshRemote == "yes" ]
	then
		ssh -i $myIdRsa $myUserId@$myHost "mysqldump -R -h $myDbHost -u $myDbUser -p$myDbPass $myDbName" > $myDestinationDir/$myDbName.sql.bak_$timestamp
	else
		mysqldump -R -h $myDbHost -u $myDbUser -p$myDbPass $myDbName > $myDestinationDir/$myDbName.sql.bak_$timestamp
	fi
fi

# 3. Re-Sync source -> destination with new files generated during the DB dump procedure
for tempSource in "${mySource[@]}"
do
	if [ $mySshRemote == "yes" ]
	then
		rsync -Pav --delete -e "ssh -i $myIdRsa" --exclude=$myExclude $myUserId@$myHost:$tempSource $myDestinationDir/
	else
		rsync -av --delete --exclude=$myExclude $tempSource $myDestinationDir/
	fi
done

# 4. Generate the archive and delete the old ones
case "$myBackupType" in
	daily|weekly|monthly)
		tar cvfz $myBackupName.$myBackupType.bak_$timestamp.tar.gz $myDestinationDir
		find $myBackupName.$myBackupType.bak_*.tar.gz -type f -mtime +$myBackupRetention -exec rm -f {} \;
		;;
	*)
		tar cvfz $myBackupName.bak_$timestamp.tar.gz $myDestinationDir
		find $myBackupName.bak_*.tar.gz -type f -mtime +$myBackupRetention -exec rm -f {} \;
	   	;;
esac

# 5. Done
echo "Done!"

exit 0

