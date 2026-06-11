require 'xcodeproj'
require 'pathname'
require 'fileutils'

project_path = File.expand_path('CustomerManagerApp.xcodeproj', __dir__)
FileUtils.rm_rf(project_path) if File.exist?(project_path)
project = Xcodeproj::Project.new(project_path)
project_root = File.dirname(project.path.to_s)

main_target = project.new_target(:application, 'CustomerManagerApp', :ios, '15.0')
test_target = project.new_target(:unit_test_bundle, 'CustomerManagerAppTests', :ios, '15.0')
test_target.add_dependency(main_target)

[main_target, test_target].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['DEVELOPMENT_TEAM'] = ''
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  end
end

main_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ray.CustomerManagerApp'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIRequiresFullScreen'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] = 'UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0.0'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ray.CustomerManagerAppTests'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/CustomerManagerApp.app/CustomerManagerApp'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end

app_group = project.main_group.new_group('CustomerManagerApp')
tests_group = project.main_group.new_group('CustomerManagerAppTests')

def add_files(project_root:, target:, group:, base_path:)
  Dir.glob(File.join(base_path, '**', '*.swift')).sort.each do |file|
    rel = Pathname(file).relative_path_from(Pathname(project_root)).to_s
    file_ref = group.new_file(rel)
    target.add_file_references([file_ref])
  end
end

add_files(project_root: project_root, target: main_target, group: app_group, base_path: File.join(__dir__, 'CustomerManagerApp'))
add_files(project_root: project_root, target: test_target, group: tests_group, base_path: File.join(__dir__, 'CustomerManagerAppTests'))

project.save
puts "Generated: #{project_path}"
