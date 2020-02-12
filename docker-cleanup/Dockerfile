FROM alpine

RUN apk add --update bash curl docker \
    && rm -rf /var/cache/apk/*

COPY docker-clean.sh /bin/
RUN chmod +x /bin/docker-clean.sh

ENV DOCKER_CLEAN_INTERVAL 86400

CMD ["bash", "/bin/docker-clean.sh"]