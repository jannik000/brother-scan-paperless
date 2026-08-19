# brother-scan-paperless

Maintained by [Jannik000](https://github.com/jannik000/brother-scan-paperless).

> **2026-08-19 update:** dependencies and the Docker base image were modernized (Python 3.13,
> current `pysnmp`/`PyYAML`/`Wand`, Debian trixie) with AI pair-programming (Claude/vibecoded) —
> including a rewrite of the SNMP registration code, a fix for `scanadf` no longer being
> packaged in current Debian, and a real end-to-end test against a physical MFC-L2710DN. See
> [PR #1](https://github.com/jannik000/brother-scan-paperless/pull/1) for details.

Some quick modifications to the brother-scan docker to suit my needs to scan from my Brother printer directly to 
the Consume dir for Paperless. I had to change a few things

- It needs to write scanned files with a specific uid:gid (to match the Paperless consume dir's
  ownership) — set via the `PUID`/`PGID` environment variables
- The temp files needed to be processed somewhere other than the consume dir, so paperless didn't try to pick them 
up
- Multipage scans were being assembled in a random order but the filenames are sequential, so forced a sort

Follows the old instructions below to get going for the most part. Copy the sample files, adjust to needs, add 
Brother's brscan4 deb, run the `python3 setup.py build sdist` and fire off the docker-compose file

---

# brother-scan

This tool is alternative to the brscan-skey with automatic document feeder
support and compressed PDF output.

## Using Docker

The easiest way to use brscand is to build a Docker image with the Dockerfile
provided here.

### Requirements

* Docker installed.
* The latest proprietary brscan4 deb from Brother
  * I had to go through their 'Downloads' page for my device (https://support.brother.com/g/b/productsearch.aspx?c=us&lang=en&content=dl)
  * The Dockerfile defaults to the deb name `brscan4-0.4.11-1.amd64.deb`

### Build image

Make sure you have downloaded the brscan4 deb file and placed it
in the top-level directory of the repository next to the Dockerfile.

Adapt `BRSCAN_DEB` if the version has changed.

```
python3 setup.py build sdist
docker build -t brscan --build-arg BRSCAN_DEB="brscan4-0.4.11-1.amd64.deb" .
```

### Configuration

Edit `brother-scan.yaml` according to your preferences.

### Run

To run brscand with the following setup:

* MFC-L2700DW scanner.
* Scanner at IP address 192.168.0.10.
* Host OS at IP address 192.168.0.100.
* Output written to $HOME/brscan

```sh
docker run --rm \
  -v $HOME/brscan:/output -v $(pwd)/brother-scan.yaml:/brother-scan.yaml \
  -e SCANNER_MODEL=MFC-L2700DW -e SCANNER_IP=192.168.0.10 \
  -e ADVERTISE_IP=192.168.0.100 -e PUID=1000 -e PGID=1000 \
  -p 54925:54925/udp \
  brscan
```

`PUID`/`PGID` control the uid:gid that scanned files are written as (e.g. to match your Paperless
consume dir's ownership) — default to `1000:1000` if unset.

### Deploying to a target without build tooling (e.g. a NAS)

If your deployment target (Synology Container Manager, etc.) can only run pre-built images and
can't build from a Dockerfile itself, build the image somewhere that has Docker and Python (your
workstation, a VM, WSL, ...) and ship the finished image instead:

```sh
scripts/build-image.sh brscan4-0.4.11-1.amd64.deb
```

This builds the sdist and image exactly like the steps above, then exports it to
`brscan-image-<git commit>.tar.gz` (also tags the image `brscan:<git commit>` locally, so you can
tell which build is actually running). Transfer that file to the target and load it — on Synology,
via **Container Manager → Image → Add → Add From File**; on a host with Docker CLI access,
`docker load < brscan-image-*.tar.gz`.

Then point your `docker-compose.yml` at the loaded image instead of building:

```yaml
services:
  brother-scan:
    image: brscan:latest   # instead of a `build:` block
    ...
```

Since the target never sees the Dockerfile or the Brother `.deb`, this also works if you don't
want that proprietary file anywhere near the deployment target's filesystem.

## Running on host OS

If you for some reason want to run it directly on your Linux host OS, that
might also be possible.  It probably need to be Ubuntu, Debian, RedHat or something like that to make it work.

### Python Virtual Environment

It is recommanded to use venv (Python Virtual Environment) to install the
required Python modules.

### Requirements

In order for this to work, host OS must have the following installed (assuming
Debian)

* Python 3.13+
* sane-utils package (`scanimage` command, used for both single-page and ADF/batch scanning)
* poppler-utils package (`pdfunite` command)
* libusb-0.1-4 package (`libusb-0.1.so.4` library)
* brscan4 (brscan4-0.4.4-1.amd64.deb can be fetched from Brother)

### Installation

```python
python3 -m venv .
./bin/pip install -r requirements.txt
python3 setup.py install
```

### Configuration

Run `brsaneconfig4` to configure the scanner.  Example configuring MFC-L2700DW
scanner with IP address 192.168.0.100:

```sh
brsaneconfig4 -a name="Brother" model="MFC-L2700DW" ip="192.168.0.100"
```

Edit `brother-scan.yaml` according to your preferences. The uid:gid that scanned files are
written as isn't set there though — that's the `PUID`/`PGID` environment variables shown below.

### Run

Now you just need to run the brscand daemon.  Example running on host with IP
192.168.0.10 and scanner with IP address 192.168.0.100:

```sh
PUID=1000 PGID=1000 brscand 192.168.0.100 192.168.0.10
```

## Uselinks

* https://www.mcbsys.com/blog/2014/11/register-pc-on-brother-scanner/
* https://github.com/jmesmon/brother2/blob/master/PROTO

## Tested devices
 * MFC-L2710DN
