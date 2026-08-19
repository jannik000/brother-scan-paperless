from brscan.listen import parse_notification


def test_parse_notification_valid_packet():
    payload = b'TYPE=BR;BUTTON=SCAN;USER="alice";FUNC=FILE;HOST=10.0.0.10:54925;APPNUM=1;'
    data = bytes([2, 0, 0, 0x30]) + payload

    assert parse_notification(data) == {
        'TYPE': 'BR',
        'BUTTON': 'SCAN',
        'USER': 'alice',
        'FUNC': 'FILE',
        'HOST': '10.0.0.10:54925',
        'APPNUM': '1',
    }


def test_parse_notification_rejects_short_packet():
    assert parse_notification(b'\x02\x00\x00') is None


def test_parse_notification_rejects_wrong_header():
    data = bytes([2, 0, 0, 0x99]) + b'TYPE=BR;'
    assert parse_notification(data) is None
