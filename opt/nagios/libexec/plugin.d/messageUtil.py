#!/usr/bin/python
#coding: utf-8
KATANA_INTRO = "\n\
## ##\n\
##### KATANA Util: Message Util\n\
## ##\n"


import sys
reload(sys)
sys.setdefaultencoding("utf-8")
import urllib


# 消息发送服务地址
MESSAGE_AGENT_SERVER = "http://192.168.120.180:18080/messageProxy/QqProxyServlet"


class MessageUtil(object):
    """Config file operation Util
    发送Message的工具类
    需要Message Agent Server支持，支持中英文编码
    """
    def __init__(self):
        super(MessageUtil, self).__init__()

    def send(self, contactList, content):
        """发送消息
        Attributes:
        contactList 联系人列表，以空格间隔
        content     消息内容
        """
        try:
            contentStr = content.encode('GBK')
        except Exception:
            contentStr = content
        for contact in contactList.split(' '):
            data = {'destination': contact, 'message': contentStr}
            urllib.urlopen(MESSAGE_AGENT_SERVER, urllib.urlencode(data))
        print '\nOK: Message Send Complete.'


if __name__ == '__main__':
    print KATANA_INTRO
    try:
        messageUtil = MessageUtil()
        messageUtil.send(sys.argv[1], sys.argv[2])
    except IndexError, e:
        print 'ERROR: 参数不完整.'
        raise e
