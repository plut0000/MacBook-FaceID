#!/usr/bin/env python3
"""Emit a self-contained Xcode project for MacBook FaceID."""

from __future__ import annotations

import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJ = ROOT / "MacBookFaceID/MacBookFaceID.xcodeproj"

SWIFT_FILES = [
    "App/MacBookFaceIDApp.swift",
    "App/AppDelegate.swift",
    "App/AppModel.swift",
    "App/MenuBarContentView.swift",
    "Island/IslandController.swift",
    "Island/IslandGeometry.swift",
    "Island/IslandView.swift",
    "Island/ScanAnimationView.swift",
    "Enrollment/HeadPose.swift",
    "Enrollment/EnrollmentSession.swift",
    "Enrollment/EnrollmentView.swift",
    "Recognition/FaceAligner.swift",
    "Recognition/FaceEmbedder.swift",
    "Recognition/IdentityVault.swift",
    "Liveness/LivenessEngine.swift",
    "Credentials/CryptoBox.swift",
    "Credentials/SessionKeychain.swift",
    "Credentials/SessionGate.swift",
    "Unlock/UnlockPipeline.swift",
    "Unlock/ScreenLockObserver.swift",
    "Unlock/AccessibilityTyper.swift",
    "Unlock/DisplayWaker.swift",
    "Unlock/SpacebarTrigger.swift",
    "Camera/CameraManager.swift",
    "Camera/CameraPreviewView.swift",
    "Settings/SettingsRootView.swift",
    "Settings/FacePane.swift",
    "Settings/RecognitionPane.swift",
    "Settings/CameraPane.swift",
    "Settings/PasswordPane.swift",
    "Settings/GeneralPane.swift",
    "Onboarding/OnboardingView.swift",
    "Permissions/PermissionMonitor.swift",
    "Support/AppConstants.swift",
]

FRAMEWORKS = [
    "SwiftUI",
    "AppKit",
    "AVFoundation",
    "Vision",
    "Security",
    "IOKit",
    "ApplicationServices",
    "ServiceManagement",
    "Combine",
    "CoreGraphics",
    "CoreImage",
    "QuartzCore",
    "Carbon",
    "CryptoKit",
    "LocalAuthentication",
    "CoreML",
    "CoreVideo",
    "CoreMedia",
]


def hid() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> None:
    ids = {
        "project": hid(),
        "target": hid(),
        "sources": hid(),
        "resources": hid(),
        "frameworks": hid(),
        "main_group": hid(),
        "products": hid(),
        "src_group": hid(),
        "fw_group": hid(),
        "product_ref": hid(),
        "project_cfg": hid(),
        "target_cfg": hid(),
        "debug_proj": hid(),
        "release_proj": hid(),
        "debug_tgt": hid(),
        "release_tgt": hid(),
        "info": hid(),
        "entitlements": hid(),
        "assets": hid(),
        "assets_build": hid(),
        "bridge": hid(),
    }

    file_ids = {}
    build_ids = {}
    group_ids = {}
    for path in SWIFT_FILES:
        file_ids[path] = hid()
        build_ids[path] = hid()
        folder = path.split("/")[0]
        if folder not in group_ids:
            group_ids[folder] = hid()

    fw_file = {}
    fw_build = {}
    for name in FRAMEWORKS:
        fw_file[name] = hid()
        fw_build[name] = hid()

    def build_file_section() -> str:
        lines = ["/* Begin PBXBuildFile section */"]
        for path in SWIFT_FILES:
            name = path.split("/")[-1]
            lines.append(
                f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};"
            )
        lines.append(
            f"\t\t{ids['assets_build']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids['assets']} /* Assets.xcassets */; }};"
        )
        for name in FRAMEWORKS:
            lines.append(
                f"\t\t{fw_build[name]} /* {name}.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fw_file[name]} /* {name}.framework */; }};"
            )
        lines.append("/* End PBXBuildFile section */")
        return "\n".join(lines)

    def file_ref_section() -> str:
        lines = ["/* Begin PBXFileReference section */"]
        lines.append(
            f'\t\t{ids["product_ref"]} /* MacBook FaceID.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "MacBook FaceID.app"; sourceTree = BUILT_PRODUCTS_DIR; }};'
        )
        for path in SWIFT_FILES:
            name = path.split("/")[-1]
            lines.append(
                f"\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
            )
        lines.append(
            f'\t\t{ids["info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};'
        )
        lines.append(
            f'\t\t{ids["entitlements"]} /* MacBookFaceID.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MacBookFaceID.entitlements; sourceTree = "<group>"; }};'
        )
        lines.append(
            f'\t\t{ids["assets"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};'
        )
        lines.append(
            f'\t\t{ids["bridge"]} /* CGSessionBridge.h */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = CGSessionBridge.h; sourceTree = "<group>"; }};'
        )
        for name in FRAMEWORKS:
            lines.append(
                f'\t\t{fw_file[name]} /* {name}.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {name}.framework; path = System/Library/Frameworks/{name}.framework; sourceTree = SDKROOT; }};'
            )
        lines.append("/* End PBXFileReference section */")
        return "\n".join(lines)

    def frameworks_phase() -> str:
        entries = "".join(
            f"\t\t\t\t{fw_build[name]} /* {name}.framework in Frameworks */,\n" for name in FRAMEWORKS
        )
        return f"""/* Begin PBXFrameworksBuildPhase section */
		{ids['frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
{entries}			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */"""

    def groups() -> str:
        by_folder: dict[str, list[str]] = {}
        for path in SWIFT_FILES:
            folder, name = path.split("/")
            by_folder.setdefault(folder, []).append(path)

        folder_blocks = []
        folder_children = ""
        for folder, paths in by_folder.items():
            children = "".join(
                f"\t\t\t\t{file_ids[p]} /* {p.split('/')[-1]} */,\n" for p in paths
            )
            if folder == "Support":
                children += f"\t\t\t\t{ids['bridge']} /* CGSessionBridge.h */,\n"
            if folder == "App":
                # Resources live as a sibling; App group stays sources-only.
                pass
            folder_blocks.append(
                f"""		{group_ids[folder]} /* {folder} */ = {{
			isa = PBXGroup;
			children = (
{children}			);
			path = {folder};
			sourceTree = "<group>";
		}};"""
            )
            folder_children += f"\t\t\t\t{group_ids[folder]} /* {folder} */,\n"

        resources_group = hid()
        ids["resources_group"] = resources_group

        fw_children = "".join(f"\t\t\t\t{fw_file[n]} /* {n}.framework */,\n" for n in FRAMEWORKS)

        return f"""/* Begin PBXGroup section */
		{ids['main_group']} = {{
			isa = PBXGroup;
			children = (
				{ids['src_group']} /* MacBookFaceID */,
				{ids['fw_group']} /* Frameworks */,
				{ids['products']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids['products']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids['product_ref']} /* MacBook FaceID.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{ids['src_group']} /* MacBookFaceID */ = {{
			isa = PBXGroup;
			children = (
{folder_children}				{resources_group} /* Resources */,
			);
			path = MacBookFaceID;
			sourceTree = "<group>";
		}};
		{resources_group} /* Resources */ = {{
			isa = PBXGroup;
			children = (
				{ids['info']} /* Info.plist */,
				{ids['entitlements']} /* MacBookFaceID.entitlements */,
				{ids['assets']} /* Assets.xcassets */,
			);
			path = Resources;
			sourceTree = "<group>";
		}};
		{ids['fw_group']} /* Frameworks */ = {{
			isa = PBXGroup;
			children = (
{fw_children}			);
			name = Frameworks;
			sourceTree = "<group>";
		}};
{chr(10).join(folder_blocks)}
/* End PBXGroup section */"""

    def native_target() -> str:
        return f"""/* Begin PBXNativeTarget section */
		{ids['target']} /* MacBookFaceID */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['target_cfg']} /* Build configuration list for PBXNativeTarget "MacBookFaceID" */;
			buildPhases = (
				{ids['sources']} /* Sources */,
				{ids['frameworks']} /* Frameworks */,
				{ids['resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = MacBookFaceID;
			productName = "MacBook FaceID";
			productReference = {ids['product_ref']} /* MacBook FaceID.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */"""

    def project_section() -> str:
        return f"""/* Begin PBXProject section */
		{ids['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{ids['target']} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {ids['project_cfg']} /* Build configuration list for PBXProject "MacBookFaceID" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids['main_group']};
			productRefGroup = {ids['products']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids['target']} /* MacBookFaceID */,
			);
		}};
/* End PBXProject section */"""

    def resources_phase() -> str:
        return f"""/* Begin PBXResourcesBuildPhase section */
		{ids['resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids['assets_build']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */"""

    def sources_phase() -> str:
        files = "".join(
            f"\t\t\t\t{build_ids[p]} /* {p.split('/')[-1]} in Sources */,\n" for p in SWIFT_FILES
        )
        return f"""/* Begin PBXSourcesBuildPhase section */
		{ids['sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{files}			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */"""

    common_proj = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
"""

    debug_proj = f"""		{ids['debug_proj']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{common_proj}
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};"""

    release_proj = f"""		{ids['release_proj']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{common_proj}
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Release;
		}};"""

    target_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = MacBookFaceID/Resources/MacBookFaceID.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 2;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = MacBookFaceID/Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 0.2.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.plut0000.MacBookFaceID;
				PRODUCT_NAME = "MacBook FaceID";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_OBJC_BRIDGING_HEADER = MacBookFaceID/Support/CGSessionBridge.h;
				SWIFT_VERSION = 5.0;
"""

    debug_tgt = f"""		{ids['debug_tgt']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{target_settings}			}};
			name = Debug;
		}};"""

    release_tgt = f"""		{ids['release_tgt']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{target_settings}			}};
			name = Release;
		}};"""

    cfg_lists = f"""/* Begin XCConfigurationList section */
		{ids['project_cfg']} /* Build configuration list for PBXProject "MacBookFaceID" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['debug_proj']} /* Debug */,
				{ids['release_proj']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['target_cfg']} /* Build configuration list for PBXNativeTarget "MacBookFaceID" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['debug_tgt']} /* Debug */,
				{ids['release_tgt']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */"""

    pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

{build_file_section()}

{file_ref_section()}

{frameworks_phase()}

{groups()}

{native_target()}

{project_section()}

{resources_phase()}

{sources_phase()}

/* Begin XCBuildConfiguration section */
{debug_proj}

{release_proj}

{debug_tgt}

{release_tgt}
/* End XCBuildConfiguration section */

{cfg_lists}
	}};
	rootObject = {ids['project']} /* Project object */;
}}
"""

    PROJ.mkdir(parents=True, exist_ok=True)
    (PROJ / "project.pbxproj").write_text(pbxproj, encoding="utf-8")

    workspace = PROJ / "project.xcworkspace"
    workspace.mkdir(parents=True, exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
        encoding="utf-8",
    )

    scheme_dir = PROJ / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "MacBookFaceID.xcscheme").write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['target']}"
               BuildableName = "MacBook FaceID.app"
               BlueprintName = "MacBookFaceID"
               ReferencedContainer = "container:MacBookFaceID.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['target']}"
            BuildableName = "MacBook FaceID.app"
            BlueprintName = "MacBookFaceID"
            ReferencedContainer = "container:MacBookFaceID.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['target']}"
            BuildableName = "MacBook FaceID.app"
            BlueprintName = "MacBookFaceID"
            ReferencedContainer = "container:MacBookFaceID.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""",
        encoding="utf-8",
    )

    print(f"Wrote project to {PROJ}")
    print(f"Target ID {ids['target']}")


if __name__ == "__main__":
    main()
