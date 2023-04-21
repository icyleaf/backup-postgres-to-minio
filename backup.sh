#! /bin/sh

set -e
# set -o pipefail

if [[ -z "${MINIO_ACCESS_KEY}" ]]; then
  echo "You need to set the MINIO_ACCESS_KEY environment variable."
  exit 1
fi

if [[ -z "${MINIO_SECRET_KEY}" ]]; then
  echo "You need to set the MINIO_SECRET_KEY environment variable."
  exit 1
fi

if [[ -z "${MINIO_BUCKET}" ]]; then
  echo "You need to set the MINIO_BUCKET environment variable."
  exit 1
fi

if [[ -z "${MINIO_SERVER}" ]]; then
  echo "You need to set the MINIO_SERVER environment variable."
  exit 1
fi

if [[ -z "${POSTGRES_HOST}" ]]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [[ -z "${POSTGRES_USER}" ]]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [[ -z "${POSTGRES_PASSWORD}" ]]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

export PGUSER=${PGUSER:-$POSTGRES_USER}
export PGPASSWORD=${PGPASSWORD:-$POSTGRES_PASSWORD}
export PGHOST=${PGHOST:-$POSTGRES_HOST}
export PGPORT=${PGPORT:-$POSTGRES_PORT}

backup_db_to_minio() {
  db_name=$1
  bucket_path="minio/${MINIO_BUCKET}/${db_name}/${db_name}_$(date +'%Y-%m-%dT%H:%M:%SZ').sql.gz"

  if [[ "$ENABLE_PIPE" == "true" ]] || [[ "$ENABLE_PIPE" == "1" ]]; then
    echo "Creating dump of ${db_name} database from ${POSTGRES_HOST} and pipe to bucket $MINIO_BUCKET ..."
    pg_dump $POSTGRES_EXTRA_OPTS "${db_name}" | gzip | mc pipe $bucket_path
  else
    echo "Creating dump of ${db_name} database from ${POSTGRES_HOST} ..."
    backup_file="$HOME/${db_name}.sql.gz"
    pg_dump $POSTGRES_EXTRA_OPTS "${db_name}" | gzip > "$backup_file"

    echo "Uploading dump to bucket $MINIO_BUCKET"
    mc cp $backup_file $bucket_path
    rm -f $backup_file
  fi
}

##################
# main
##################
if [[ -z "$MINIO_API_VERSION" ]]; then
  mc alias set minio "$MINIO_SERVER" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" > /dev/null
else
  mc alias set minio "$MINIO_SERVER" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" --api "$MINIO_API_VERSION" > /dev/null
fi

if [[ -z "${POSTGRES_DATABASE}" ]]; then
  echo "Backup all databases of postgresl ..."
  DATABASES=$(psql $POSTGRES_EXTRA_OPTS -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres')")
  for DATABASE in $DATABASES; do
    backup_db_to_minio $DATABASE
  done
else
  backup_db_to_minio $POSTGRES_DATABASE
fi

echo "SQL backup uploaded successfully" 1>&2
