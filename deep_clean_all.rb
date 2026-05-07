#!/usr/bin/env ruby
# Deep clean all BoltUIKit and ONB duplicates from project

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Scanning project for duplicate BoltUIKit/ONB references..."

# Collect ALL objects that match our patterns
bolt_pattern = /(BoltTheme|BoltBaseCard|TravelModels|BoltTravel|BoltHotel|BoltFlight|BoltPackage|BoltActivity|BoltUIKit|ONBIntent|ONBPersona)/

# Remove duplicate PBXFileReference
file_refs = project.objects.select { |o| o.isa == 'PBXFileReference' }
file_refs.each do |ref|
  if ref.path && ref.path =~ bolt_pattern
    # Keep only those with proper nested path (BoltUIKit/...)
    if !ref.path.include?('BoltUIKit/') && !ref.path.include?('Services/')
      puts "  Removing file ref: #{ref.path}"
      ref.remove_from_project
    end
  end
end

# Remove duplicate PBXBuildFile
build_files = project.objects.select { |o| o.isa == 'PBXBuildFile' }
build_files.each do |bf|
  next unless bf.file_ref
  if bf.file_ref.path =~ bolt_pattern
    if !bf.file_ref.path.include?('BoltUIKit/') && !bf.file_ref.path.include?('Services/')
      puts "  Removing build file: #{bf.file_ref.path}"
      bf.remove_from_project
    end
  end
end

# Remove duplicate groups
main_group = project.main_group['ioscrmapp']
main_group.children.dup.each do |child|
  if child.display_name =~ bolt_pattern
    # Only remove if it's a root-level duplicate (not the proper nested one)
    if child.path && !child.path.include?('BoltUIKit/') && !child.path.include?('Services/')
      puts "  Removing group: #{child.display_name}"
      child.remove_from_project
    end
  end
end

# Clean up any orphaned objects
project.objects.each do |obj|
  if obj.isa == 'PBXFileReference' || obj.isa == 'PBXBuildFile'
    # Check if it's still referenced
    if obj.isa == 'PBXBuildFile' && !obj.file_ref
      puts "  Removing orphaned build file"
      obj.remove_from_project
    end
  end
end

project.save
puts "\nDeep cleanup complete"