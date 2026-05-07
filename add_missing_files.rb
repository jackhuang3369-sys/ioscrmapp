#!/usr/bin/env ruby
# Add all missing Service and BoltUIKit files to Xcode project

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Find Services group
services_group = main_group.groups.find { |g| g.display_name == 'Services' }
unless services_group
  puts "Creating Services group"
  services_group = main_group.new_group('Services', 'Services')
end

# Add missing Service files
services_folder = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/Services'
missing_services = ['ONBIntentFusionService.swift', 'ONBPersonaClassifierService.swift']

missing_services.each do |filename|
  full_path = File.join(services_folder, filename)
  if File.exist?(full_path)
    # Check if already in project
    existing = project.objects.find { |o| o.isa == 'PBXFileReference' && o.path == filename }
    unless existing
      file_ref = services_group.new_file(full_path)
      target.source_build_phase.add_file_reference(file_ref)
      puts "  Added: #{filename}"
    else
      puts "  Already exists: #{filename}"
    end
  else
    puts "  File not found: #{filename}"
  end
end

# Add BoltUIKit group and files
bolt_folder = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/BoltUIKit'

# Remove existing BoltUIKit if present
existing_bolt = main_group.groups.find { |g| g.display_name == 'BoltUIKit' }
if existing_bolt
  puts "\nRemoving existing BoltUIKit group..."
  existing_bolt.remove_from_project
end

# Create new BoltUIKit group
bolt_group = main_group.new_group('BoltUIKit', 'BoltUIKit')

def add_swift_files(group, folder_path, target)
  Dir.entries(folder_path).each do |entry|
    next if entry.start_with?('.')
    full_path = File.join(folder_path, entry)
    if File.directory?(full_path)
      sub_group = group.new_group(entry, entry)
      add_swift_files(sub_group, full_path, target)
    elsif entry.end_with?('.swift')
      file_ref = group.new_file(full_path)
      target.source_build_phase.add_file_reference(file_ref)
      puts "  Added: #{entry}"
    end
  end
end

puts "\nAdding BoltUIKit files..."
add_swift_files(bolt_group, bolt_folder, target)

project.save
puts "\nAll files added successfully"