FROM alpine:3.17

WORKDIR /app
RUN apk add --update --no-cache postgresql-client && \
    rm -rf /var/cache/apk/*

ADD https://dl.min.io/client/mc/release/linux-amd64/mc /usr/local/bin/mc
COPY go-cron /usr/local/bin/go-cron
RUN chmod +x /usr/local/bin/mc && chmod +x /usr/local/bin/go-cron

COPY run.sh run.sh
COPY backup.sh backup.sh

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

CMD ["sh", "run.sh"]
