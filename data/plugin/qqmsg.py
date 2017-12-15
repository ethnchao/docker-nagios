#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import urllib
from optparse import OptionParser
reload(sys)
sys.setdefaultencoding("utf-8")


def legacyChannel(dest, msg):
    try:
        encodeMsg = msg.encode('GBK')
    except Exception:
        encodeMsg = msg
    data = {'destination': dest, 'message': encodeMsg}
    urllib.urlopen('http://192.168.120.180:18080/messageProxy/QqProxyServlet',
                   urllib.urlencode(data))


def smartQQChannel(dest, msg):
    urllib.urlopen('http://192.168.120.234:3200/send?type=buddy&to='
                   + dest + '&msg=' + msg)


def getParser():
    parser = OptionParser(
        prog="qqmsg",
        description="Send QQ message to group or buddy",
        epilog="Support legacyChannel & smartQQChannel")
    parser.add_option('-m', '--msg', dest='msg', help='message content')
    parser.add_option('-d', '--dest', dest='dest',
                      help='which one will be recieve this message')
    return parser


def main():
    parser = getParser()
    (args, value) = parser.parse_args()
    msg = args.msg
    # group = args.group
    dest = args.dest
    if not msg or not dest:
        print >> sys.stderr, 'At least one required option is missing'
        sys.exit(1)
    try:
        legacyChannel(dest, msg)
    except Exception:
        raise


if __name__ == '__main__':
    main()
