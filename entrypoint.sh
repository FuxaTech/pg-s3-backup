#!/bin/bash

set -e

readonly DATE=$(date +%F-%H%M%S)
readonly S3_PATH="s3://${AWS_S3_BUCKET:-}/backups"
readonly STORAGE_CLASS="${AWS_S3_STORAGE_CLASS:-STANDARD}"
readonly COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

readonly DB_NAME=$(echo "$BACKUP_DATABASE_URL" | sed -E 's#.*/([^/?]+).*#\1#')
readonly BACKUP_FILENAME="$DB_NAME-$DATE.sql"
readonly BACKUP_FILE_PATH="/backup/$BACKUP_FILENAME"
readonly GZ_BACKUP_FILE_PATH="$BACKUP_FILE_PATH.gz"

export AWS_DEFAULT_REGION=$AWS_S3_REGION

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        DEBUG) [[ "$LOG_LEVEL" == "DEBUG" ]] && echo "[$timestamp] [DEBUG] $message" >&2 ;;
        INFO)  echo "[$timestamp] [INFO] $message" ;;
        WARN)  echo "[$timestamp] [WARN] $message" >&2 ;;
        ERROR) echo "[$timestamp] [ERROR] $message" >&2 ;;
    esac
}

validate_environment() {
    local errors=()
    
    [[ -z "${BACKUP_DATABASE_URL:-}" ]] && errors+=("BACKUP_DATABASE_URL is required")
    [[ -z "${AWS_S3_BUCKET:-}" ]] && errors+=("AWS_S3_BUCKET is required")
    [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] && errors+=("AWS_ACCESS_KEY_ID is required")
    [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] && errors+=("AWS_SECRET_ACCESS_KEY is required")
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        log ERROR "Environment validation failed:"
        for error in "${errors[@]}"; do
            log ERROR "  - $error"
        done
        exit 1
    fi
    
    log INFO "Environment validation passed"
}

cleanup() {
    log INFO "Cleaning up temporary files"
    rm -f "$BACKUP_FILE_PATH" "$GZ_BACKUP_FILE_PATH"
}

trap cleanup EXIT

backup_database() {
    log INFO "Starting backup of database: $DB_NAME"
    
    log INFO "Creating database dump..."
    if ! pg_dump "$BACKUP_DATABASE_URL" > "$BACKUP_FILE_PATH"; then
        log ERROR "Database dump failed"
        exit 1
    fi
    
    local dump_size=$(du -h "$BACKUP_FILE_PATH" | cut -f1)
    log INFO "Database dump completed: $dump_size"
    
    log INFO "Compressing backup file (level: $COMPRESSION_LEVEL)..."
    if ! gzip -"$COMPRESSION_LEVEL" "$BACKUP_FILE_PATH"; then
        log ERROR "Compression failed"
        exit 1
    fi
    
    local compressed_size=$(du -h "$GZ_BACKUP_FILE_PATH" | cut -f1)
    log INFO "Compression completed: $compressed_size"
}

upload_to_s3() {
    log INFO "Uploading to S3: $S3_PATH/$BACKUP_FILENAME.gz"
    
    local upload_args=(
        "$GZ_BACKUP_FILE_PATH"
        "$S3_PATH/$BACKUP_FILENAME.gz"
        --storage-class "$STORAGE_CLASS"
        --sse
    )
    
    upload_args+=(--metadata "db-name=$DB_NAME,backup-date=$DATE")
    
    if ! aws s3 cp "${upload_args[@]}"; then
        log ERROR "S3 upload failed"
        exit 1
    fi
    
    log INFO "S3 upload completed successfully"
}

main() {
    log INFO "=== PostgreSQL S3 Backup Started ==="
    log INFO "Database: $DB_NAME"
    log INFO "S3 Bucket: $AWS_S3_BUCKET"
    
    validate_environment
    backup_database
    upload_to_s3
    
    log INFO "=== Backup completed successfully ==="
}

main "$@"
