from brscan.scanto import add_scan_options


def test_add_scan_options_appends_known_options():
    cmd = ['scanimage']
    add_scan_options(cmd, {'resolution': 300, 'mode': 'Color', 'unknown': 'ignored'})

    assert cmd == ['scanimage', '--resolution', '300', '--mode', 'Color']
