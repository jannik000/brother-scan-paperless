from brscan.snmp import format_menu_entry_cmd


def test_format_menu_entry_cmd():
    cmd = format_menu_entry_cmd('SCAN', 'FILE', 'alice', '10.0.0.10:54925', 1)

    assert cmd == (
        'TYPE=BR;BUTTON=SCAN;USER="alice";FUNC=FILE;'
        'HOST=10.0.0.10:54925;APPNUM=1;DURATION=360;BRID=;'
    )


def test_format_menu_entry_cmd_custom_duration_and_brid():
    cmd = format_menu_entry_cmd('SCAN', 'FILE', 'bob', '10.0.0.10:54925', 2,
                                 duration=120, brid='abc')

    assert 'DURATION=120' in cmd
    assert 'BRID=abc' in cmd
