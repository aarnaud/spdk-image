FROM debian:13 as builder
RUN apt-get update && apt-get install -y sudo curl git procps build-essential python3-full pkg-config meson python3-pyelftools python3-configshell-fb libdpdk-dev liburing-dev patchelf
RUN git clone --branch v26.01 https://github.com/spdk/spdk --recursive /src
WORKDIR /src
RUN mkdir /rootfs
RUN python3 -m venv venv
ENV VIRTUAL_ENV /src/venv
ENV PATH "/src/venv/bin:$PATH"
RUN python3 -m pip install uv
RUN scripts/pkgdep.sh --developer-tools --lz4 --rbd --rdma --uring
RUN ./configure --with-raid5f --with-uring --with-rdma --prefix=/rootfs
RUN make
RUN make install

FROM debian:13
RUN sed -i 's/Components: main/Components: main contrib/g' /etc/apt/sources.list.d/debian.sources
RUN apt-get update && apt-get install -y python3-full python3-pip python3-configshell-fb libibverbs1 librdmacm1 liburing2 libfuse3-4 libaio1t64 dumb-init openssh-server libncurses6 libnuma1
RUN apt-get install -y --no-install-recommends zfsutils-linux && apt-get clean
COPY --from=builder /rootfs/ /tmp/spdk
RUN echo "PYTHONPATH=/usr/lib/python3.11/site-packages" >> /etc/environment
RUN cp -r /tmp/spdk/* /usr/ && rm -rf /tmp/spdk
COPY --from=builder /src/python /src/python
COPY --from=builder /src/scripts /src/scripts
RUN pip install --break-system-packages /src/python/ && rm -rf /src
# Test binary and cli
RUN spdk_tgt --version && spdk-cli --help
COPY ./entrypoint-sshd.sh /