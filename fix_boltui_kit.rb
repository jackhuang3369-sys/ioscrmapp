#!/usr/bin/env ruby
# Remove stale BoltUIKit.swift reference and fix the project

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main app target
target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Remove BoltUIKit.swift file reference if it exists
boltui_kit_swift = main_group.files.find { |f| f.display_name == 'BoltUIKit.swift' }
if boltui_kit_swift
  puts "Removing stale BoltUIKit.swift reference"
  boltui_kit_swift.remove_from_project
end

# Find BoltUIKit group
bolt_group = main_group.groups.find { |g| g.display_name == 'BoltUIKit' }
if bolt_group
  # Remove all file references from build phase
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.display_name =~ /BoltUIKit/
      puts "Removing build file: #{build_file.file_ref.display_name}"
      build_file.remove_from_project
    end
  end
end

project.save
puts "Project cleaned up successfully"