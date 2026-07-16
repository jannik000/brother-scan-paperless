import subprocess
import os
import sys
import traceback
import shutil
import datetime
import wand.image
import glob

def pnmtopdf(pnmfile, pdffile, resolution=None):
    with wand.image.Image(filename=pnmfile, resolution=resolution) as pnm:
        with pnm.convert('pdf') as pdf:
            pdf.save(filename=pdffile)
    os.remove(pnmfile)

scan_options = {
    'device': '--device-name',
    'resolution': '--resolution',
    'mode': '--mode',
    'source': '--source',
    'brightness': '--brightness',
    'contrast': '--contrast',
    'width': '-x',
    'height': '-y',
    'left': '-l',
    'top': '-t',
}

def add_scan_options(cmd, options):
    for name, arg in scan_options.items():
        if name in options:
            cmd += [arg, str(options[name])]
    cmd = [ str(c) for c in cmd ]

def scanto(func, options):
    print('scanto %s %s'%(func, options))
    options = options.copy()
    if func == 'FILE':
        if not 'dir' in options:
            options['dir'] = '/tmp'
        dst = options['dir']

    uid = options['uid']
    gid = options['gid']
    tmp = '/tmp'

    os.makedirs(dst, exist_ok=True)
    os.makedirs(tmp, exist_ok=True)

    now = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    adf = options.pop('adf', False)

    if adf:
        cmd = ['scanadf',
               '--output-file', os.path.join(tmp, 'scan_%s_%%d.pnm'%(now))]
        add_scan_options(cmd, options)
        print('# ' + ' '.join(cmd))
        subprocess.call(cmd)
        pnmfiles = []
        pdffiles = []
        for pnmfile in sorted(glob.glob(os.path.join(tmp, 'scan_%s_*.pnm'%(now))),
                                key=os.path.getmtime):
            pdffile = '%s.pdf'%(pnmfile[:-4])

            try:
                pnmtopdf(pnmfile, pdffile, options.get('resolution'))
                pnmfiles.append(pnmfile)
                pdffiles.append(pdffile)
            except Exception as e:
                print("Skipping broken scan page %s: %s" % (pnmfile, e), file=sys.stderr)
                traceback.print_exc()

                try:
                    os.remove(pnmfile)
                except OSError:
                    pass

        if not pdffiles:
            print("No valid pages scanned; aborting PDF creation", file=sys.stderr)
            return

        outputfile = os.path.join(tmp, 'scan_%s.pdf'%(now))
        cmd = ['pdfunite'] + pdffiles + [outputfile]
        print('# ' + ' '.join(cmd))
        subprocess.call(cmd)
        for f in pdffiles:
            os.remove(f)
    else:
        cmd = ['scanimage']
        add_scan_options(cmd, options)
        pnmfile = os.path.join(tmp, 'scan_%s.pnm'%(now))
        with open(pnmfile, 'w') as pnm:
            print('# ' + ' '.join(cmd))
            process = subprocess.Popen(cmd, stdout=pnm)
            process.wait()
        pdffile = '%s.pdf'%(pnmfile[:-4])
        pnmtopdf(pnmfile, pdffile, options['resolution'])
        print('Wrote', pdffile)
        outputfile = pdffile
    newfile = outputfile.replace(tmp, dst)
    print('Moving', outputfile, 'to', newfile)
    shutil.move(outputfile, newfile)
    os.chown(newfile, uid, gid)
