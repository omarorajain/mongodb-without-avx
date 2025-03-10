FROM debian:bookworm-slim AS build

# Install build dependencies
RUN apt update -y && apt install -y build-essential \
    libcurl4-openssl-dev \
    liblzma-dev \
    libssl-dev \
    python-dev-is-python3 \
    python3-pip \
    curl \
&& rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Download MongoDB source
ARG MONGO_VERSION=
RUN mkdir /src && \
    curl -o /tmp/mongo.tar.gz -L "https://github.com/mongodb/mongo/archive/refs/tags/r${MONGO_VERSION}.tar.gz" && \
    tar xaf /tmp/mongo.tar.gz --strip-components=1 -C /src && \
    rm /tmp/mongo.tar.gz
WORKDIR /src

# Apply patch
COPY ./o2_patch.diff /o2_patch.diff
RUN patch -p1 < /o2_patch.diff

# Build MongoDB
ARG NUM_JOBS=
RUN export GIT_PYTHON_REFRESH=quiet && \
    uv venv /venv && \
    . /venv/bin/activate && \
    uv pip install requirements_parser && \
    uv pip install -r etc/pip/compile-requirements.txt && \
    /venv/bin/python3 buildscripts/scons.py install-servers MONGO_VERSION="${MONGO_VERSION}" --release --disable-warnings-as-errors -j ${NUM_JOBS} --linker=gold && \
    mv build/install /install && \
    strip --strip-debug /install/bin/mongod && \
    strip --strip-debug /install/bin/mongos && \
    rm -rf build /venv /src

# Final image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt update -y && \
    apt install -y libcurl4 && \
    apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries
COPY --from=build /install/bin/mongo* /usr/local/bin/

# Create user and data directory
RUN groupadd -r mongod && useradd -r -g mongod mongod
RUN mkdir -p /data/db && chown -R mongod:mongod /data
USER mongod

ENTRYPOINT [ "/usr/local/bin/mongod" ]
