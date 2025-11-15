FROM alpine:3.22

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ENV GZIP_COMPRESSION_LEVEL=6

ENV DB_DUMP_LOCATION=/data
ENV DB_HOSTNAME=localhost
ENV DB_PORT=3306
ENV DB_STRUCT_TABLES=""
ENV DB_USER_NAME=root
ENV DB_USER_PASSWORD=""
ENV DB_DATABASES=""
ENV DB_SNAPSHOT_ALL_DATABASES=""
ENV DB_SNAPSHOT_COMBINED=""
ENV DB_SNAPSHOT_USERS_GRANTS=""
ENV DB_DEFAULT_CHARSET=utf8mb4
ENV DB_EXCLUDE_DATABASES="information_schema,performance_schema,mysql,sys"

ENV RSNAPSHOT_RETAIN_DAILY=7
ENV RSNAPSHOT_RETAIN_HOURLY=8
ENV RSNAPSHOT_RETAIN_MONTHLY=6
ENV RSNAPSHOT_RETAIN_WEEKLY=4
ENV RSNAPSHOT_VERBOSE=2
ENV RSNAPSHOT_LOGLEVEL=3

RUN apk --update --no-cache add rsnapshot mariadb-client && \
  mkdir -p ${DB_DUMP_LOCATION}

COPY ./build/conf/rsnapshot/rsnapshot.conf /etc/rsnapshot.conf
COPY ./build/scripts /scripts

ENTRYPOINT ["/scripts/run.sh"]

LABEL ca.unb.lib.generator="rsnapshot" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="MIT" \
  org.label-schema.description="mariadb-snapshot provides a MariaDB/MySQL point-in-time snapshot for database instances." \
  org.label-schema.name="mariadb-snapshot" \
  org.label-schema.schema-version="1.0" \
  org.label-schema.vcs-url="https://github.com/JacobSanford/docker-mariadb-snapshot" \
  org.label-schema.vendor="Jacob Sanford" \
  org.opencontainers.image.authors="Jacob Sanford <jsanford@unb.ca>" \
  org.opencontainers.image.source="https://github.com/JacobSanford/docker-mariadb-snapshot"
