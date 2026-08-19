import asyncio

from pysnmp.proto import rfc1902
from pysnmp.hlapi.v1arch.asyncio import (
    SnmpDispatcher, CommunityData, UdpTransportTarget, ObjectType, ObjectIdentity, set_cmd,
)

# See http://www.oidview.com/mibs/2435/BROTHER-MIB.html
SCAN_TO_OID = '1.3.6.1.4.1.2435.2.3.9.2.11.1.1.0'


def format_menu_entry_cmd(button, func, user, host, appnum, duration=360, brid=''):
    return 'TYPE=BR;BUTTON=%s;USER="%s";FUNC=%s;HOST=%s;APPNUM=%s;DURATION=%s;BRID=%s;' % (
        button, user, func, host, appnum, duration, brid)


async def add_menu_entry(dispatcher, community, transport, button, func, user, host, appnum,
                          duration=360, brid=''):
    cmd = format_menu_entry_cmd(button, func, user, host, appnum, duration, brid)
    errorIndication, errorStatus, errorIndex, varBinds = await set_cmd(
        dispatcher, community, transport,
        ObjectType(ObjectIdentity(SCAN_TO_OID), rfc1902.OctetString(cmd)),
    )

    # Check for errors and print out results
    if errorIndication:
        print(errorIndication)
    else:
        if errorStatus:
            print('%s at %s' % (
                errorStatus.prettyPrint(),
                errorIndex and varBinds[int(errorIndex)-1] or '?'))


async def _launch(args, config):
    dispatcher = SnmpDispatcher()
    try:
        community = CommunityData('internal', mpModel=0)  # mpModel=0 forces SNMPv1
        transport = await UdpTransportTarget.create((args.scanner_addr, 161))
        addr = (args.advertise_addr, args.advertise_port)
        print('Advertising %s:%d to %s' % (addr + (args.scanner_addr,)))
        for func, users in config['menu'].items():
            for user, entry in users.items():
                print('Entry:', func.upper(), user, entry)
        while True:
            appnum = 1
            for func, users in config['menu'].items():
                for user, entry in users.items():
                    await add_menu_entry(dispatcher, community, transport, 'SCAN', func.upper(),
                                          user, '%s:%d' % addr, appnum)
                    appnum += 1
            await asyncio.sleep(60)
    finally:
        # Only reached on error/cancellation (the loop above runs forever
        # otherwise); best-effort cleanup, don't let it mask the real error.
        try:
            dispatcher.close_dispatcher()
        except Exception:
            pass


def launch(args, config):
    asyncio.run(_launch(args, config))
