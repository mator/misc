#!/usr/bin/env python

from __future__ import print_function
import re
import select
import sys
from prometheus_client import Counter, start_http_server
from systemd import journal


# Description: listen to journald logs continiously
# as a base took
# https://stackoverflow.com/questions/26331116/reading-systemd-journal-from-python-script

# log substring to filter station (mrn=xx) from
MSG_ID = "string_to_select_line_from_logs"
# systemd unit id to filter logs from
SUNIT_ID = "unit_to_watch_logs_on.service"
# TCP port to start webserver on
LISTEN_PORT = 9600

j = journal.Reader()
j.log_level(journal.LOG_INFO)
j.add_match(_SYSTEMD_UNIT=SUNIT_ID)

j.seek_tail()
j.get_previous()

p = select.poll()
p.register(j, j.get_events())

c = Counter('log1_counter', 'sample log counter', ['label1'])

try:
    start_http_server(LISTEN_PORT)
except:
    print("Error: unable to start http_server on port %s" % LISTEN_PORT)
    sys.exit(1)
finally:
    print("Info: started to listen on port %s" % LISTEN_PORT)

while p.poll():
    # wait for new logs to appear
    if j.wait() != journal.APPEND:
        continue
    # process new entry
    j.process()

    for entry in j:
        if MSG_ID in entry['MESSAGE']:
            #print(str(entry['__REALTIME_TIMESTAMP'] )+ ' ' + entry['MESSAGE'])
            z = re.search(r"mrn=(\w+)\s", entry['MESSAGE'])
            if z:
                station_id = z.group(1)
                c.labels(station_id).inc()
