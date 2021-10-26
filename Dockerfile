FROM docker

COPY gojira.sh /usr/local/bin/gojira

RUN apk add bash && gojira version

WORKDIR /src

ENTRYPOINT ["gojira"]
