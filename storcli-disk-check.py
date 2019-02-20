#!/usr/bin/python3

# used as a cron checker

import subprocess
import sys

if len(sys.argv) > 1 and sys.argv[1] == '--test':
    f = open("storcli-disk-failed.txt", "r")
    freadlist = f.readlines()
    f.close()
    output = ""
    output = output.join(freadlist)
    err = 0
else:
    cmd = [ "/usr/bin/storcli", "/c0/vall", "show" ]
    cp = subprocess.run(cmd, capture_output=True, universal_newlines=True, check=True)
    output, rc, err = cp.stdout, cp.returncode, cp.stderr

if err:
    print(rc, err)
    quit()

dash = 0
for line in output.split('\n'):
    if line.startswith('---'):
        dash = dash+1
    elif dash == 2 :
        data = line.split(' ')
        #
        # if disk state is not Optimal , print and exit
        if data[4] != 'Optl' :
            print(output)
            quit()


# vim: set expandtab ts=4 sw=4:
