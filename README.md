# pg-s3-backup

Dockerized tool to back up PostgreSQL databases and upload to Amazon S3.

## Features
- Dumps a PostgreSQL database using `pg_dump`
- Compresses the dump with gzip (configurable compression level)
- Uploads the compressed backup to an S3 bucket with server-side encryption
- Configurable S3 storage class
- Comprehensive logging with configurable log levels
- Robust error handling and validation
- Automatic cleanup of temporary files
- Metadata tagging for S3 objects

## Requirements
- Docker
- AWS S3 bucket
- PostgreSQL database URL

## Environment Variables
| Variable            | Description                                 | Default |
|---------------------|---------------------------------------------|---------|
| `BACKUP_DATABASE_URL` | PostgreSQL connection URL (e.g. `postgres://user:pass@host:port/dbname`) | **Required** |
| `AWS_S3_BUCKET`     | Name of the S3 bucket to upload backups to  | **Required** |
| `AWS_S3_REGION`     | AWS region of the S3 bucket                 | **Required** |
| `AWS_ACCESS_KEY_ID` | AWS access key ID                           | **Required** |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key                   | **Required** |
| `AWS_S3_STORAGE_CLASS` | S3 storage class (STANDARD, STANDARD_IA, etc.) | `STANDARD` |
| `COMPRESSION_LEVEL` | Gzip compression level (1-9)               | `6` |
| `LOG_LEVEL`         | Logging level (DEBUG, INFO, WARN, ERROR)   | `INFO` |

## Usage

```sh
docker run --rm \
  -e BACKUP_DATABASE_URL=postgres://user:pass@host:port/dbname \
  -e AWS_S3_BUCKET=your-bucket-name \
  -e AWS_S3_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e AWS_S3_STORAGE_CLASS=STANDARD_IA \
  fuxatech/pg-s3-backup:stable
```

Backups will be compressed and uploaded to `s3://<AWS_S3_BUCKET>/backups/` with the filename format `<dbname>-<YYYY-MM-DD-HHMMSS>.sql.gz`.

## How it works
1. **Environment Validation**: Validates all required environment variables
2. **Database Dump**: Uses `pg_dump` to create a SQL dump of the database
3. **Compression**: Compresses the dump with `gzip` using the specified compression level
4. **S3 Upload**: Uploads the compressed file to S3 using `aws s3 cp` with:
   - Server-side encryption (`--sse`)
   - Configurable storage class
   - Metadata tags (database name and backup date)
5. **Cleanup**: Automatically removes temporary files

## Example S3 Path
```
s3://your-bucket-name/backups/yourdb-2025-07-10-040357.sql.gz
```

## S3 Object Metadata
Each uploaded backup includes the following metadata:
- `db-name`: The name of the backed up database
- `backup-date`: The timestamp when the backup was created

## Logging
The tool provides comprehensive logging with different levels:
- `DEBUG`: Detailed debugging information including file sizes and compression details
- `INFO`: General information about the backup process (default)
- `WARN`: Warning messages for non-critical issues
- `ERROR`: Error messages for critical failures

Logs include timestamps and are formatted as: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`

## License
MIT
