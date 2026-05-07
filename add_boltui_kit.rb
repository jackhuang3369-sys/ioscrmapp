#!/usr/bin/env ruby
# Add BoltUIKit to Xcode project (without BoltUIKit.swift wrapper)

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main app target
target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Remove existing BoltUIKit group if any
existing_bolt = main_group.groups.find { |g| g.display_name == 'BoltUIKit' }
if existing_bolt
  puts "Removing existing BoltUIKit group"
  existing_bolt.remove_from_project
end

# Add BoltUIKit group
bolt_folder = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/BoltUIKit'
bolt_group = main_group.new_group('BoltUIKit', 'BoltUIKit')

# Add all Swift files recursively (skipping BoltUIKit.swift)
def add_swift_files(group, folder_path, target)
  Dir.entries(folder_path).each do |entry|
    next if entry.start_with?('.')
    next if entry == 'BoltUIKit.swift'  # Skip wrapper file
    full_path = File.join(folder_path, entry)
    if File.directory?(full_path)
      sub_group = group.groups.find { |g| g.display_name == entry }
      unless sub_group
        sub_group = group.new_group(entry, entry)
      end
      add_swift_files(sub_group, full_path, target)
    elsif entry.end_with?('.swift')
      file_ref = group.new_file(full_path)
      target.source_build_phase.add_file_reference(file_ref)
      puts "  Added: #{entry}"
    end
  end
end

puts "Adding BoltUIKit files to project..."
add_swift_files(bolt_group, bolt_folder, target)

project.save
puts "\nBoltUIKit added to Xcode project successfully"