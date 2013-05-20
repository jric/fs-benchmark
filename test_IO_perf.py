#!/usr/bin/env python2.7
# __doc__ string below used to parse command-line args
# Docopt doesn't support argument groups.
'''
We run the "Directory Processor" benchmark:
  1.  Read the given directory
  2.  Rename each file to include its sequence number in the
      alphabetical list.
  3.  Open each file and strip out all the markup "<[^>]*>.

Usage:
  test-IO-perf.py <dir> --parallel=<num>

  <dir>             directory to process
  --parallel=<num>  how many threads to use [default: 4]
'''

import os, sys, re, codecs
from appError import AppLogger
from Dumper import dumps
from docopt import docopt
from multiprocessing import Pool

PROG = os.path.basename(__file__)
EXECDIR = os.path.dirname(__file__)
verbose = 0
L = AppLogger(PROG)
J = os.path.join

transform_re = re.compile(r'<[^>]*>')

def fileProcessor(task):
    (fp, seqno) = task
    dir = os.path.dirname(fp)
    (new_base, ext) = os.path.basename(fp).split(os.path.extsep)
    new_base += '-' + str(seqno + 1)
    new_fp = J(dir, new_base + os.path.extsep + ext)
    os.rename(fp, new_fp)
    with codecs.open(new_fp) as f:
        content = f.read()
    new_content = re.sub(transform_re, '', content)
    with codecs.open(new_fp, mode='w') as f:
        f.write(new_content)

def directoryProcessor(dir, parallel):
    files = os.listdir(dir)
    p = Pool(parallel)
    tasks = []
    for i in range(len(files)):
        tasks.append((J(dir, files[i]), i))
    p.map(fileProcessor, tasks)

def main(my_args):
    return directoryProcessor(my_args['<dir>'], int(my_args['--parallel']))
    
if __name__ == "__main__":
    L.announceMyself()
    args = docopt(__doc__)
    exit(main(args))
