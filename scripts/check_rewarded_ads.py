#!/usr/bin/env python3
"""Exercise the shipping ad controller with fake SDK responses and a monotonic test clock."""
import os
from pathlib import Path
import platform
import subprocess

root = Path(__file__).resolve().parents[1]
build = root / 'build/rewarded-ads-check'
build.mkdir(parents=True, exist_ok=True)
source = (root / 'App/RewardedAds.swift').read_text()
source = source.replace('import GoogleMobileAds\n', '').replace('import UserMessagingPlatform\n', '')
source = source.replace('UIApplication.shared.applicationState', 'TestApplication.state')
source = source.replace('ProcessInfo.processInfo.systemUptime', 'TestClock.uptime')
source = source.replace('.seconds(15)', '.milliseconds(30)')
(build / 'RewardedAds.swift').write_text(source)
environment = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], env=environment, text=True).strip()
environment['SDKROOT'] = sdk
binary = build / 'checks'
command = ['xcrun', 'swiftc', '-sdk', sdk, '-target', f'{platform.machine()}-apple-ios26.5-simulator',
           '-D', 'DEBUG', '-parse-as-library']
command += [str(root / path) for path in ['Core/RewardGate.swift', 'Core/KarmaDialogue.swift',
             'App/KarmaRoomView.swift', 'App/ShinobiStyle.swift', 'Verification/AdSDKStubs.swift',
             'Verification/RewardedAdsChecks.swift']]
command += [str(build / 'RewardedAds.swift'), '-o', str(binary)]
subprocess.run(command, env=environment, check=True)
subprocess.run(['xcrun', 'simctl', 'spawn', 'booted', str(binary)], env=environment, check=True)
