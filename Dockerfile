FROM postgres:16-alpine

RUN apk add --no-cache \
  aws-cli \
  gzip

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
