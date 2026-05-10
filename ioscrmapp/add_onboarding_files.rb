#!/usr/bin/env ruby
# add_onboarding_files.rb - Add Onboarding module files to Xcode project

require 'xcodeproj'

# Project path (absolute path)
project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'

# Open the project
project = Xcodeproj::Project.open(project_path)

# Get main target
main_target = project.targets.find { |t| t.name == 'ioscrmapp' }

# Get test target
test_target = project.targets.find { |t| t.name == 'ioscrmappTests' }

# Base path
base_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp'

puts "=========================================="
puts "Adding Onboarding Module Files"
puts "=========================================="
puts ""

# Helper function: find or create group
def find_or_create_group(project, path_components)
  current_group = project.main_group

  path_components.each do |component|
    child = current_group.children.find { |c| c.display_name == component || c.name == component }

    if child && child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      current_group = child
    else
      current_group = current_group.new_group(component)
    end
  end

  current_group
end

# Step 1: Add implementation file to main target
puts "Step 1: Adding OnboardingModels.swift to main target..."

impl_file_path = "#{base_path}/ioscrmapp/Modules/Onboarding/Models/OnboardingModels.swift"

if File.exist?(impl_file_path)
  # Create Onboarding/Models group
  models_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Models'])

  # Add file reference
  file_ref = models_group.new_file(impl_file_path)

  # Add to build phase
  main_target.source_build_phase.add_file_reference(file_ref)

  puts "  Added: OnboardingModels.swift"
else
  puts "  ERROR: File not found: #{impl_file_path}"
end

puts ""

# Step 2: Add test file to test target
puts "Step 2: Adding OnboardingModelsTests.swift to test target..."

test_file_path = "#{base_path}/Tests/OnboardingTests/OnboardingModelsTests.swift"

if File.exist?(test_file_path)
  # Create OnboardingTests group (similar to AIModelsTests)
  # Find the parent group for test files
  tests_group = find_or_create_group(project, ['OnboardingTests'])

  # Add file reference
  test_file_ref = tests_group.new_file(test_file_path)

  # Add to test target build phase
  test_target.source_build_phase.add_file_reference(test_file_ref)

  puts "  Added: OnboardingModelsTests.swift"
else
  puts "  ERROR: File not found: #{test_file_path}"
end

puts ""

# Save project
puts "Saving project changes..."
project.save

puts ""
puts "=========================================="
puts "Files Added Successfully"
puts "=========================================="
puts ""
puts "Next steps:"
puts "1. Build the project to verify:"
puts "   xcodebuild -scheme ioscrmapp-Develop build"
puts "2. Run tests to verify:"
puts "   xcodebuild -scheme ioscrmapp-Test test"
puts ""

exit 0