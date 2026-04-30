FROM alpine:3.20

RUN apk add --no-cache bash curl jq

WORKDIR /app

COPY monitor.sh /app/monitor.sh
COPY config.env /app/config.env

RUN chmod +x /app/monitor.sh

# Run every 5 minutes using a simple loop
CMD while true; do bash /app/monitor.sh; sleep 300; done
