FROM nvcr.io/nvidia/tensorrt:19.03-py2

MAINTAINER robert.d.clark@hpe.com

# Set to non-interactive mode to prevent tzdata requiring TTY access.
# See https://askubuntu.com/questions/909277/avoiding-user-interaction-with-tzdata-when-installing-certbot-in-a-docker-contai.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt-get install -y --no-install-recommends \
    numactl \
    build-essential \
    cmake \
    git \
    wget \
    doxygen \
    graphviz \
    libboost-program-options-dev \
    libopencv-dev \
    ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN pip2 install --upgrade pip
RUN pip2 install numpy pandas matplotlib

COPY models /dlbs/models
COPY python /dlbs/python
COPY scripts /dlbs/scripts
COPY src /tmp
COPY run /dlbs/scripts

RUN cd /tmp/tensorrt && cmake -DHOST_TYPE=INT8 -DCMAKE_INSTALL_PREFIX=/opt/tensorrt . && \
    make -j$(nproc) && make build_docs && make install && \
    rm -rf /tmp/tensorrt

ENV PATH /opt/tensorrt/bin:$PATH

CMD ["/dlbs/scripts/run"]
