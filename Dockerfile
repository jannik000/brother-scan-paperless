FROM python:3.13-slim-trixie
ARG BRSCAN_DEB=brscan4-0.4.11-1.amd64.deb
LABEL maintainer="Esben Haabendal, esben@haabendal.dk"

# Without this, print() output sits in Python's stdout buffer and never
# reaches "docker logs" since the container has no TTY.
ENV PYTHONUNBUFFERED=1

# This is where the scan output will be written to
VOLUME /output

# This must be mapped to ${ADVERTISE_IP}:54925
EXPOSE 54925/udp

# Install required Debian packages.
# "sane" (metapackage) and "sane-frontends" (scanadf) no longer exist in
# current Debian; sane-utils alone provides scanimage, which now also
# covers ADF scanning via --batch (see brscan/scanto.py).
RUN apt-get update -q \
 && apt-get install -q -y sane-utils poppler-utils libusb-0.1-4 imagemagick \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install required python modules
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

# Install Brother scanner driver
COPY $BRSCAN_DEB /tmp/
RUN dpkg --install /tmp/brscan4-*.deb

# Fixup symbolic links
RUN mkdir /usr/lib/sane \
 && for f in /usr/lib64/sane/libsane-brother*;do ln -s $f /usr/lib/sane/;done

# Install brscan (run "setup.py build sdist" before docker build)
COPY dist/brscan-0.0.1.tar.gz /tmp/
RUN pip install --no-binary :all: /tmp/brscan-*.tar.gz

# Allow the PDF coder (only), which is disabled by ImageMagick's default
# policy; everything else in the default policy (resource limits, other
# blocked coders) stays intact since we only ever read PNM and write PDF.
RUN policy=$(ls /etc/ImageMagick-*/policy.xml) \
 && sed -i '/pattern="PDF"/s/rights="none"/rights="read|write"/' "$policy"

# Add run script and set it as default command
ADD run.sh /
CMD ["/run.sh"]
