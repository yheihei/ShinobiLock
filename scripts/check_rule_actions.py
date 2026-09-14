#!/usr/bin/env python3
"""Exercise rule persistence and unlock requests with simulated Screen Time services."""
import argparse
import os
from pathlib import Path
import platform
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', default='booted', help='Simulator UDID or booted')
args = parser.parse_args()
build = root / 'build/rule-action-check'
build.mkdir(parents=True, exist_ok=True)
source = (root / 'Shared/ProbeState.swift').read_text()
start = source.index('    private static func directory() throws -> URL {')
end = source.index('\n    // Reads never', start)
source = source[:start] + '''    private static func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("shinobilock-rule-check-\\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
''' + source[end:]
# Replace only OS integration. Transactions, validation, rewards and mutations use current source.
for before, after in [
    ('ManagedSettingsStore(named: ManagedSettingsStore.Name("ShinobiLock.Probe"))', 'TestStore()'),
    ('static let center = DeviceActivityCenter()', 'static let center = TestCenter()'),
]:
    assert source.count(before) == 1, before
    source = source.replace(before, after)
(build / 'ProbeState.swift').write_text(source)
environment = dict(os.environ)
environment.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'],
                              env=environment, text=True).strip()
environment['SDKROOT'] = sdk
binary = build / 'checks'
command = ['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-sdk', sdk,
           '-target', f'{platform.machine()}-apple-ios26.5-simulator', '-parse-as-library']
command += [str(path) for path in sorted((root / 'Core').glob('*.swift'))]
command += [str(build / 'ProbeState.swift'), str(root / 'Verification/RuleActionChecks.swift'), '-o', str(binary)]
subprocess.run(command, env=environment, check=True)
subprocess.run(['xcrun', 'simctl', 'spawn', args.simulator, str(binary)], env=environment, check=True)
