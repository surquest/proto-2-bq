FROM golang:1.20-bullseye

# Install protoc
RUN apt-get update && \
    apt-get install -y \
        protobuf-compiler \
        golang-goprotobuf-dev \
        curl \
        jq

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
RUN go install github.com/GoogleCloudPlatform/protoc-gen-bq-schema@latest

# Make a directory to work in
RUN mkdir -p /tmp/default
RUN curl -o /tmp/default/bq_field.proto https://raw.githubusercontent.com/GoogleCloudPlatform/protoc-gen-bq-schema/master/bq_field.proto
RUN curl -o /tmp/default/bq_table.proto https://raw.githubusercontent.com/GoogleCloudPlatform/protoc-gen-bq-schema/master/bq_table.proto
RUN curl -o /tmp/default/metadata.json https://raw.githubusercontent.com/surquest/proto-2-bq/main/schemas/metadata.json
RUN curl -o /tmp/convert.sh https://raw.githubusercontent.com/surquest/proto-2-bq/main/convert.sh
RUN chmod +x /tmp/convert.sh

# Uninstall curl
RUN apt-get remove -y curl

RUN mkdir -p /tmp/schemas
WORKDIR /tmp/schemas

ENTRYPOINT ["/tmp/convert.sh"]
