# brother-scan-paperless

Some quick modifications to the brother-scan docker to suit my needs to scan from my Brother printer directly to 
the Consume dir for Paperless. I had to change a few things

- It needed to set proper uid:gid. Hacky but they must be specified in brother-scan.yaml now
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
  -e ADVERTISE_IP=192.168.0.100 -p 54925:54925/udp \
  brscan
```

## Running on host OS

If you for some reason want to run it directly on your Linux host OS, that
might also be possible.  It probably need to be Ubuntu, Debian, RedHat or something like that to make it work.

### Python Virtual Environment

It is recommanded to use venv (Python Virtual Environment) to install the
required Python modules.

### Requirements

In order for this to work, host OS must have the following installed (assuming
Debian)

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

Edit `brother-scan.yaml` according to your preferences.

### Run

Now you just need to run the brscand daemon.  Example running on host with IP
192.168.0.10 and scanner with IP address 192.168.0.100:

```sh
brscand 192.168.0.100 192.168.0.10
```

## Uselinks

* https://www.mcbsys.com/blog/2014/11/register-pc-on-brother-scanner/
* https://github.com/jmesmon/brother2/blob/master/PROTO

## Tested devices
 * MFC-L2710DN
