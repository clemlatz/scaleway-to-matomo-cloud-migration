#!/bin/bash

set -e;

ftpUsername=$MATOMO_MIGRATION_FTP_USERNAME;
ftpPassword=$MATOMO_MIGRATION_FTP_PASSWORD;
scalewayInstanceId=$MATOMO_MIGRATION_SCALEWAY_INSTANCE_ID;
databaseName=$MATOMO_MIGRATION_DATABASE_NAME;
expirationDate=$MATOMO_MIGRATION_EXPIRATION_DATE;

function log () {
  currentDate=$(date +"%Y-%m-%d %T");
  echo "$currentDate | $1";
}

log "Initiating $databaseName database transfer…";

log "Creating $databaseName database backup…";

backupResult=$(scw rdb backup create --wait \
  instance-id=$scalewayInstanceId \
  database-name=$databaseName \
  expires-at=$expirationDate);
backupResultData=(${backupResult// / });
backupId=${backupResultData[1]};

log "Database backup succeeded (ID: $backupId)!";

log "Preparing backup for export…";

scw rdb backup export --wait $backupId >/dev/null;

log "Backup ready for export!";

backupDate=$(date +"%Y-%m-%d_%H-%M");
fileName="matomo-db_$backupDate.sql.gz"

log "Downloading backup $backupId to $fileName...";

scw rdb backup download $backupId output=$fileName;

log "Download succeeded!";

log "Uploading backup to FTP server…";

lftp \
    -e "put -O . $fileName; bye" \
    -u $ftpUsername,$ftpPassword \
    ftp-innocraft-customer-uploads.alwaysdata.net;

log "Database transfer succeeded!";

lftp \
    -e "ls -h; bye" \
    -u $ftpUsername,$ftpPassword \
    ftp-innocraft-customer-uploads.alwaysdata.net;

log "Deleting local database dump…";

rm $fileName;

log "Local database dump deleted";
