FROM debian:12 as builder
RUN apt-get update && apt-get install -y sudo git build-essential python3-full pkg-config meson python3-pyelftools python3-configshell-fb libdpdk-dev liburing-dev patchelf
RUN git clone https://github.com/spdk/spdk --recursive /src
WORKDIR /src
RUN mkdir /rootfs
RUN python3 -m venv venv
ENV VIRTUAL_ENV /src/venv
ENV PATH "/src/venv/bin:$PATH"
RUN scripts/pkgdep.sh --developer-tools --pmem --rbd --rdma --uring
RUN ./configure --with-raid5f --with-uring --with-rdma --prefix=/rootfs
RUN make
RUN make install

FROM debian:12
RUN sed -i 's/Components: main/Components: main contrib/g' /etc/apt/sources.list.d/debian.sources
RUN apt-get update && apt-get install -y python3-full python3-pip libibverbs1 librdmacm1 liburing2 libfuse3-3 libaio1 dumb-init openssh-server libncurses6
RUN apt-get install -y --no-install-recommends zfsutils-linux && apt-get clean
RUN python3 -m pip install configshell-fb --force-reinstall --break-system-packages
COPY --from=builder /rootfs/ /tmp/spdk
RUN echo "PYTHONPATH=/usr/lib/python3.11/site-packages" >> /etc/environment
RUN cp -r /tmp/spdk/* /usr/ && rm -rf /tmp/spdk
COPY ./entrypoint-sshd.sh /
RUN mkdir /var/run/sshd