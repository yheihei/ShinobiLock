#!/usr/bin/env python3
"""Generate the Xcode project with the Python standard library only."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def uid(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def put(key, value):
    identifier = uid(key)
    objects[identifier] = value
    return identifier


def encode(value, level=0):
    indent = "\t" * level
    if isinstance(value, dict):
        lines = [f"{indent}\t{key} = {encode(item, level + 1)};" for key, item in value.items()]
        return "{\n" + "\n".join(lines) + "\n" + indent + "}"
    if isinstance(value, list):
        lines = [f"{indent}\t{encode(item, level + 1)}," for item in value]
        return "(\n" + "\n".join(lines) + "\n" + indent + ")"
    return json.dumps(str(value), ensure_ascii=False)


def write_plist(path, value):
    with (ROOT / path).open("wb") as stream:
        plistlib.dump(value, stream, sort_keys=False)


config_ref = put("config", {
    "isa": "PBXFileReference", "lastKnownFileType": "text.xcconfig",
    "path": "Config/Project.xcconfig", "sourceTree": "SOURCE_ROOT",
})
privacy_ref = put("privacy", {
    "isa": "PBXFileReference", "lastKnownFileType": "text.xml",
    "path": "Config/PrivacyInfo.xcprivacy", "sourceTree": "SOURCE_ROOT",
})
shared = "Shared/ProbeState.swift"
core_files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "Core").glob("*.swift"))
app_files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "App").glob("*.swift"))
ads_package = put("ads.package", {
    "isa": "XCRemoteSwiftPackageReference",
    "repositoryURL": "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
    "requirement": {"kind": "exactVersion", "version": "13.9.0"},
})
ads_product = put("ads.product", {
    "isa": "XCSwiftPackageProductDependency", "package": ads_package, "productName": "GoogleMobileAds",
})
assets_ref = put("assets", {
    "isa": "PBXFileReference", "lastKnownFileType": "folder.assetcatalog",
    "path": "App/Assets.xcassets", "sourceTree": "SOURCE_ROOT",
})
font_files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "App/Fonts").glob("*")
                    if path.suffix == ".ttf" or path.name.endswith("-LICENSE.txt"))
font_refs = {path: put("font." + path, {
    "isa": "PBXFileReference", "lastKnownFileType": "file" if path.endswith(".ttf") else "text",
    "path": path, "sourceTree": "SOURCE_ROOT",
}) for path in font_files}
resource_files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "App/Resources").glob("*.json"))
resource_refs = {path: put("resource." + path, {
    "isa": "PBXFileReference", "lastKnownFileType": "text.json",
    "path": path, "sourceTree": "SOURCE_ROOT",
}) for path in resource_files}
specs = [
    ("ShinobiLock", "App/ShinobiLockApp.swift", None, None),
    ("ShieldConfiguration", "Extensions/ShieldConfiguration/ShieldConfigurationExtension.swift",
     "com.apple.ManagedSettingsUI.shield-configuration-service", "ShieldConfigurationExtension"),
    ("ShieldAction", "Extensions/ShieldAction/ShieldActionExtension.swift",
     "com.apple.ManagedSettings.shield-action-service", "ShieldActionExtension"),
    ("DeviceActivityMonitor", "Extensions/DeviceActivityMonitor/MonitorExtension.swift",
     "com.apple.deviceactivity.monitor-extension", "MonitorExtension"),
]
source_refs = {}
for path in core_files + [shared] + app_files + [spec[1] for spec in specs[1:]]:
    source_refs[path] = put(path, {
        "isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift",
        "path": path, "sourceTree": "SOURCE_ROOT",
    })

products = []
targets = []
extension_dependencies = []
extension_embeds = []
report_embeds = []
for name, source, extension_point, principal in specs:
    extension = extension_point is not None
    report = name == "ActivityReport"
    product = put(name + ".product", {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.app-extension" if extension else "wrapper.application",
        "includeInIndex": "0", "path": name + (".appex" if extension else ".app"),
        "sourceTree": "BUILT_PRODUCTS_DIR",
    })
    products.append(product)
    sources = []
    for path in core_files + [shared] + ([source] if extension else app_files):
        sources.append(put(name + ".source." + path, {"isa": "PBXBuildFile", "fileRef": source_refs[path]}))
    phases = [
        put(name + ".sources", {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647",
                                "files": sources, "runOnlyForDeploymentPostprocessing": "0"}),
        put(name + ".frameworks", {"isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647",
                                   "files": [] if extension else [put("ads.build", {"isa": "PBXBuildFile", "productRef": ads_product})],
                                   "runOnlyForDeploymentPostprocessing": "0"}),
        put(name + ".resources", {"isa": "PBXResourcesBuildPhase", "buildActionMask": "2147483647",
                                  "files": [put(name + ".privacy", {"isa": "PBXBuildFile", "fileRef": privacy_ref})]
                                           + ([] if extension else [put("assets.build", {"isa": "PBXBuildFile", "fileRef": assets_ref})]
                                              + [put("font.build." + path, {"isa": "PBXBuildFile", "fileRef": ref})
                                                 for path, ref in font_refs.items()]
                                              + [put("resource.build." + path, {"isa": "PBXBuildFile", "fileRef": ref})
                                                 for path, ref in resource_refs.items()]),
                                  "runOnlyForDeploymentPostprocessing": "0"}),
    ]
    if not extension:
        phases.append(uid("embed"))
    configurations = []
    for configuration in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME": name,
            "PRODUCT_BUNDLE_IDENTIFIER": "$(SHINOBI_BUNDLE_PREFIX)" + ("." + name if extension else ""),
            "INFOPLIST_FILE": "Config/" + name + "-Info.plist",
            "GENERATE_INFOPLIST_FILE": "NO",
            "CODE_SIGN_ENTITLEMENTS": "Config/Shared.entitlements",
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]
                                       + (["@executable_path/../../Frameworks"] if extension else []),
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SKIP_INSTALL": "YES" if extension else "NO",
        }
        if extension:
            settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
        else:
            settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
            settings["OTHER_LDFLAGS"] = ["$(inherited)", "-ObjC"]
        configurations.append(put(name + "." + configuration, {
            "isa": "XCBuildConfiguration", "baseConfigurationReference": config_ref,
            "buildSettings": settings, "name": configuration,
        }))
    config_list = put(name + ".configs", {"isa": "XCConfigurationList", "buildConfigurations": configurations,
                                         "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"})
    target = put(name + ".target", {
        "isa": "PBXNativeTarget", "buildConfigurationList": config_list, "buildPhases": phases,
        "buildRules": [], "dependencies": [] if extension else extension_dependencies,
        "name": name, "productName": name, "productReference": product,
        "packageProductDependencies": [] if extension else [ads_product],
        "productType": "com.apple.product-type.extensionkit-extension" if report else
                       "com.apple.product-type.app-extension" if extension else "com.apple.product-type.application",
    })
    targets.append(target)
    if extension:
        proxy = put(name + ".proxy", {"isa": "PBXContainerItemProxy", "containerPortal": uid("project"),
                                      "proxyType": "1", "remoteGlobalIDString": target, "remoteInfo": name})
        extension_dependencies.append(put(name + ".dependency", {
            "isa": "PBXTargetDependency", "target": target, "targetProxy": proxy,
        }))
        (report_embeds if report else extension_embeds).append(put(name + ".embed", {
            "isa": "PBXBuildFile", "fileRef": product,
            "settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]},
        }))

    info = {
        "CFBundleDevelopmentRegion": "ja", "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)", "CFBundlePackageType": "XPC!" if extension else "APPL",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "ShinobiAppGroup": "$(SHINOBI_APP_GROUP)",
    }
    if report:
        info["EXAppExtensionAttributes"] = {"EXExtensionPointIdentifier": extension_point}
    elif extension:
        info["NSExtension"] = {"NSExtensionPointIdentifier": extension_point,
                               "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME)." + principal}
    else:
        info.update({"CFBundleDisplayName": "カルマロック", "LSRequiresIPhoneOS": True,
                     "UIAppFonts": [Path(path).name for path in font_files if path.endswith(".ttf")],
                     "GADApplicationIdentifier": "$(SHINOBI_ADMOB_APP_ID)",
                     "ShinobiRewardedAdUnitID": "$(SHINOBI_REWARDED_AD_UNIT_ID)",
                     "GADDelayAppMeasurementInit": True,
                     "SKAdNetworkItems": [{"SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"}],
                     "UILaunchScreen": {}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                     "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}})
    write_plist("Config/" + name + "-Info.plist", info)

put("embed", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": "2147483647", "dstPath": "",
              "dstSubfolderSpec": "13", "files": extension_embeds, "name": "Embed App Extensions",
              "runOnlyForDeploymentPostprocessing": "0"})
put("embedReport", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": "2147483647",
                    "dstPath": "$(CONTENTS_FOLDER_PATH)/Extensions", "dstSubfolderSpec": "16",
                    "files": report_embeds, "name": "Embed ExtensionKit Extensions",
                    "runOnlyForDeploymentPostprocessing": "0"})
product_group = put("products", {"isa": "PBXGroup", "children": products, "name": "Products", "sourceTree": "<group>"})
main_group = put("main", {"isa": "PBXGroup", "children": [config_ref, privacy_ref, assets_ref] + list(font_refs.values()) + list(resource_refs.values()) + list(source_refs.values()) + [product_group],
                          "sourceTree": "<group>"})
project_configs = []
for configuration in ["Debug", "Release"]:
    settings = {
        "SDKROOT": "iphoneos", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if configuration == "Debug" else "-O",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if configuration == "Debug" else "dwarf-with-dsym",
    }
    if configuration == "Debug":
        settings.update({"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)", "ENABLE_TESTABILITY": "YES"})
    project_configs.append(put("project." + configuration, {
        "isa": "XCBuildConfiguration", "buildSettings": settings, "name": configuration,
    }))
project_config_list = put("project.configs", {
    "isa": "XCConfigurationList", "buildConfigurations": project_configs,
    "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release",
})
put("project", {
    "isa": "PBXProject", "attributes": {"BuildIndependentTargetsInParallel": "1", "LastUpgradeCheck": "2660"},
    "buildConfigurationList": project_config_list, "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "ja", "hasScannedForEncodings": "0", "knownRegions": ["ja", "en", "Base"],
    "mainGroup": main_group, "productRefGroup": product_group, "projectDirPath": "", "projectRoot": "", "targets": targets,
    "packageReferences": [ads_package],
})
project = ROOT / "ShinobiLock.xcodeproj"
project.mkdir(exist_ok=True)
project.joinpath("project.pbxproj").write_text(
    "// !$*UTF8*$!\n" + encode({"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects,
                              "rootObject": uid("project")}) + "\n"
)
schemes = project / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
schemes.joinpath("ShinobiLock.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('ShinobiLock.target')}" BuildableName="ShinobiLock.app" BlueprintName="ShinobiLock" ReferencedContainer="container:ShinobiLock.xcodeproj"/>
    </BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('ShinobiLock.target')}" BuildableName="ShinobiLock.app" BlueprintName="ShinobiLock" ReferencedContainer="container:ShinobiLock.xcodeproj"/></BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
write_plist("Config/Shared.entitlements", {
    "com.apple.developer.family-controls": True,
    "com.apple.security.application-groups": ["$(SHINOBI_APP_GROUP)"],
})
print("Generated ShinobiLock.xcodeproj with the app and 3 Screen Time extensions.")
