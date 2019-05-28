FROM gcc:9.1.0

WORKDIR /app

COPY . /app

ENV PATH="/opt/x86_64-w64-cross-mingw32/bin:$PATH"

RUN mkdir -p /opt/x86_64-w64-cross-mingw32/bin && \
    cp src/x86_64-w64-mingw32-pkg-config /opt/x86_64-w64-cross-mingw32/bin && \
    bash src/build.sh $GCC_VERSION && \
    rm -rf /app

