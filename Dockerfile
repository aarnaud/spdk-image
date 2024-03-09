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
RUN apt-get update && apt-get install -y python3-full python3-pip libibverbs1 librdmacm1 liburing2 libfuse3-3 libaio1 dumb-init openssh-server
RUN python3 -m pip install configshell-fb --force-reinstall --break-system-packages
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages/
ENV LD_LIBRARY_PATH=/usr/local/lib
COPY --from=builder /rootfs/ /usr/local/
COPY ./entrypoint-sshd.sh /
RUN mkdir /var/run/sshd
RUN echo 'alias zdb="chroot /host /usr/local/sbin/zdb"' >> .bashrc
RUN echo 'alias zfs="chroot /host /usr/local/sbin/zfs"' >> .bashrc
RUN echo 'alias zpool="chroot /host /usr/local/sbin/zpool"' >> .bashrc