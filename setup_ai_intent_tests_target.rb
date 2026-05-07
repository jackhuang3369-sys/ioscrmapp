#!/usr/bin/env ruby

require 'xcodeproj'

PROJECT_PATH = 'ioscrmapp.xcodeproj'
APP_TARGET_NAME = 'ioscrmapp'
TEST_TARGET_NAME = 'ioscrmappTests'
TEST_BUNDLE_ID = 'com.inspur.crmiosapp.tests'
TEST_FILES = [
  'Tests/AIModelsTests/IntentModelsTests.swift',
  'Tests/AIModelsTests/IntentClassificationModelsTests.swift',
  'Tests/AIModelsTests/IntentRecognitionIntegrationTests.swift',
  'Tests/AIModelsTests/IntentRecognitionPerformanceTests.swift',
  'Tests/AIModelsTests/IntentModelsXCTests.swift'
].freeze

def find_or_create_group(root_group, path_components)
  current = root_group

  path_components.each do |component|
    child = current.children.find do |candidate|
      candidate.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
        (candidate.name == component || candidate.path == component || candidate.display_name == component)
    end

    current = child || current.new_group(component)
  end

  current
end

def ensure_file_reference(group, project, file_path)
  existing = project.files.find { |file| file.path == file_path || file.real_path.to_s.end_with?(file_path) }
  return existing if existing

  group.new_file(file_path)
end

def ensure_build_file(target, file_reference)
  return if target.source_build_phase.files_references.include?(file_reference)

  target.source_build_phase.add_file_reference(file_reference)
end

def ensure_target_dependency(target, dependency_target)
  return if target.dependencies.any? { |dependency| dependency.target == dependency_target }

  target.add_dependency(dependency_target)
end

def ensure_test_target(project, app_target)
  target = project.targets.find { |candidate| candidate.name == TEST_TARGET_NAME }
  return target if target

  deployment_target =
    app_target.build_configurations
      .map { |config| config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] }
      .compact
      .first || '15.6'

  target = project.new_target(:unit_test_bundle, TEST_TARGET_NAME, :ios, deployment_target)
  ensure_target_dependency(target, app_target)

  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = TEST_BUNDLE_ID
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/du App.app/du App'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@loader_path/Frameworks'
    ]
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target
  end

  target
end

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |target| target.name == APP_TARGET_NAME }
raise "Unable to find app target #{APP_TARGET_NAME}" unless app_target

test_target = ensure_test_target(project, app_target)
tests_group = find_or_create_group(project.main_group, ['Tests', 'AIModelsTests'])

TEST_FILES.each do |file_path|
  file_reference = ensure_file_reference(tests_group, project, file_path)
  ensure_build_file(test_target, file_reference)
end

project.save

puts "Configured #{TEST_TARGET_NAME} with #{TEST_FILES.size} test files."
