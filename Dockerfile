FROM debian:trixie AS builder

ARG MARCH_AMD64="-march=znver4 -mtune=znver4"

SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    gcc make pkg-config libc6-dev \
    librtlsdr-dev libusb-1.0-0-dev \
    zlib1g-dev libzstd-dev libncurses-dev \
    wget ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

RUN [[ $(uname -m) == x86_64 ]] && MARCH=" $MARCH_AMD64" || MARCH="" && \
    mkdir -p /out/share/tar1090 && \
    make -j$(nproc) RTLSDR=yes OPTIMIZE="-O2 $MARCH" && \
    mv readsb /out/readsb && \
    mv viewadsb /out/viewadsb && \
    make clean && \
    make -j$(nproc) WITH_UUIDS=yes OPTIMIZE="-O2 $MARCH" && \
    mv readsb /out/readsb-with-uuids && \
    make clean && \
    make -j$(nproc) PRINT_UUIDS=yes TRACKS_UUID=yes OPTIMIZE="-O2 $MARCH" && \
    mv readsb /out/readsb-uuid && \
    mv viewadsb /out/viewadsb-uuid && \
    wget --timeout 10 --tries=6 --retry-connrefused --retry-on-http-error=404,429,500,502,503,504 -O /out/share/tar1090/aircraft.csv.gz https://raw.githubusercontent.com/wiedehopf/tar1090-db/csv/aircraft.csv.gz

FROM debian:trixie-slim
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    librtlsdr0 libncurses6 zlib1g libzstd1 libjemalloc2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /run/readsb /usr/local/share/tar1090

COPY --from=builder /out/readsb /out/readsb-with-uuids /out/readsb-uuid /usr/local/bin/
COPY --from=builder /out/viewadsb /out/viewadsb-uuid /usr/local/bin/
COPY --from=builder /out/share/tar1090/aircraft.csv.gz /usr/local/share/tar1090/aircraft.csv.gz

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
ENV MALLOC_CONF=narenas:1,tcache:false

ENTRYPOINT ["/usr/local/bin/readsb"]
