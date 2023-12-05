FROM golang:1.20-buster as builder
ARG TARGETARCH

ARG PLUGINS_VERSION=v1.4.0
ENV PLUGINS_VERSION=${PLUGINS_VERSION}

ARG TAG=${PLUGINS_VERSION}

ARG WORKDIR=/opt/plugins

RUN set -ex \
    && git clone -b ${PLUGINS_VERSION} --depth 1 https://github.com/containernetworking/plugins ${WORKDIR}

WORKDIR ${WORKDIR}

ARG RELEASE_DIR=release-${TAG} \
    OUTPUT_DIR=bin \
    SRC_DIR=${WORKDIR}

RUN set -ex \
    && mkdir -p ${SRC_DIR}/${RELEASE_DIR} \
    && mkdir -p ${OUTPUT_DIR} \
    && export BUILDFLAGS="-extldflags -static -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=${TAG}" \
    && PLUGINS="plugins/meta/* plugins/main/* plugins/ipam/*" \
    && \
    for d in $PLUGINS; do \
        plugin="$(basename "$d")"; \
        if [ "${plugin}" != "windows" ]; then \
            ${GO:-go} build -ldflags "$BUILDFLAGS" -o "${PWD}/bin/$plugin" ./"$d"; \
        fi; \
    done \
    && tar -C ${OUTPUT_DIR} --owner=0 --group=0 -caf ${RELEASE_DIR}/cni-plugins-linux-${TARGETARCH}-${TAG}.tgz . \
    && cd ${RELEASE_DIR} \
    && sha1sum cni-plugins-linux-${TARGETARCH}-${TAG}.tgz > cni-plugins-linux-${TARGETARCH}-${TAG}.tgz.sha1 \
    && sha256sum cni-plugins-linux-${TARGETARCH}-${TAG}.tgz > cni-plugins-linux-${TARGETARCH}-${TAG}.tgz.sha256 \
    && sha512sum cni-plugins-linux-${TARGETARCH}-${TAG}.tgz > cni-plugins-linux-${TARGETARCH}-${TAG}.tgz.sha512 \
    && cd .. \
    && chown -R ${UID} ${OUTPUT_DIR} ${RELEASE_DIR} \
    && mv ${RELEASE_DIR} dist

FROM debian:buster-slim

WORKDIR /opt/plugins

COPY --from=builder /opt/plugins/dist /opt/plugins/dist

VOLUME /dist

CMD cp -rf dist/* /dist/

