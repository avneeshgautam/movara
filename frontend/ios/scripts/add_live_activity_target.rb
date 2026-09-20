require 'xcodeproj'

project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

ext_name = 'MovaraLiveActivity'
team = '5WYH7Z7786'
app_bundle = 'com.avneesh.movaraApp'
ext_bundle = "#{app_bundle}.MovaraLiveActivity"

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

if project.targets.any? { |t| t.name == ext_name }
  puts "Target #{ext_name} already exists — nothing to do."
  exit 0
end

# 1. The app-extension target (iOS 16.1 for Live Activities).
ext = project.new_target(:app_extension, ext_name, :ios, '16.1')

ext.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => ext_bundle,
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'INFOPLIST_FILE' => 'MovaraLiveActivity/Info.plist',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.1',
    'SWIFT_VERSION' => '5.0',
    'DEVELOPMENT_TEAM' => team,
    'CODE_SIGN_STYLE' => 'Automatic',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CURRENT_PROJECT_VERSION' => '1',
    'MARKETING_VERSION' => '1.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SKIP_INSTALL' => 'NO',
    'ENABLE_BITCODE' => 'NO',
    'CLANG_ANALYZER_NONNULL' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  )
end

# 2. File groups + references.
ext_group = project.main_group.find_subpath('MovaraLiveActivity', true)
ext_group.set_source_tree('SOURCE_ROOT')
ext_group.path = 'MovaraLiveActivity'
widget_ref = ext_group.new_reference('MovaraLiveActivityWidget.swift')
bundle_ref = ext_group.new_reference('MovaraLiveActivityBundle.swift')
ext_group.new_reference('Info.plist')
ext.add_file_references([widget_ref, bundle_ref])

# Shared attributes — compiled into BOTH the app and the extension.
shared_group = project.main_group.find_subpath('Shared', true)
shared_group.set_source_tree('SOURCE_ROOT')
shared_group.path = 'Shared'
attrs_ref = shared_group.new_reference('MovaraActivityAttributes.swift')
ext.add_file_references([attrs_ref])
runner.add_file_references([attrs_ref])

# Bridge — app side only, lives next to AppDelegate in the Runner group.
runner_group = project.main_group['Runner'] || project.main_group.find_subpath('Runner', true)
bridge_ref = runner_group.new_reference('LiveActivityBridge.swift')
runner.add_file_references([bridge_ref])

# 3. Embed the extension into the app and depend on it.
runner.add_dependency(ext)

embed_phase = runner.build_phases.find do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.symbol_dst_subfolder_spec == :plug_ins
end
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed Foundation Extensions'
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  runner.build_phases << embed_phase
end
appex_build_file = embed_phase.add_file_reference(ext.product_reference)
appex_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts "Added #{ext_name} extension target, embedded it in Runner, and wired shared sources."
