#!/var/vcap/packages/service-backup_blobxfer/bin/python3

# -*- coding: utf-8 -*-
import re
import sys

sys.path.append('/var/vcap/packages/service-backup_blobxfer/lib/python3.6/site-packages')

from blobxfer_cli.cli import cli

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw?|\.exe)?$', '', sys.argv[0])
    sys.exit(cli())
