#!/usr/bin/env ruby
# Clean and re-add BoltUIKit to Xcode project

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Remove ALL BoltUIKit related files and groups
puts "Cleaning up existing BoltUIKit references..."

# Remove from build phase
target.source_build_phase.files.dup.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path =~ /BoltUIKit/
    puts "  Removing from build phase: #{build_file.file_ref.path}"
    build_file.remove_from_project
  end
end

# Remove from main group
main_group.children.dup.each do |child|
  if child.display_name == 'BoltUIKit' || (child.path && child.path.include?('BoltUIKit'))
    puts "  Removing group/file: #{child.display_name}"
    child.remove_from_project
  end
end

# Also clean up any duplicate PBXFileReference entries
project.objects.select { |o| o.isa == 'PBXFileReference' && o.path =~ /BoltUIKit/ }.each do |ref|
  ref.remove_from_project unless main_group.files.include?(ref)
end

project.save
puts "\nCleanup complete. Please run add_boltui_kit.rb again to re-add files."