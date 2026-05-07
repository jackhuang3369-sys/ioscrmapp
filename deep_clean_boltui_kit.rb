#!/usr/bin/env ruby
# Deep cleanup of all BoltUIKit duplicate references

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Collect all paths that contain BoltUIKit or are BoltUIKit files
boltui_file_paths = [
  'BoltUIKit', 'BoltTheme.swift', 'BoltBaseCard.swift', 'TravelModels.swift',
  'BoltTravelShowcase.swift', 'BoltHotelCard.swift', 'BoltFlightCard.swift',
  'BoltTravelCard.swift', 'BoltPackageCard.swift', 'BoltActivityCard.swift',
  'BoltTravelCard', 'BoltUIKitCore', 'BoltUIKitTravel'
]

# Find and remove ALL duplicate objects
puts "Cleaning duplicate PBXFileReference entries..."
project.objects.select { |o| o.isa == 'PBXFileReference' && o.path =~ /(BoltTheme|BoltBaseCard|TravelModels|BoltTravel|BoltHotel|BoltFlight|BoltPackage|BoltActivity|BoltUIKit)/ }.each do |ref|
  # Only remove if path indicates it's a duplicate in root ioscrmapp folder
  if ref.path && !ref.path.include?('/') && ref.path =~ /^(Bolt|Travel)/
    puts "  Removing duplicate file ref: #{ref.path}"
    ref.remove_from_project
  end
end

puts "\nCleaning duplicate PBXBuildFile entries..."
project.objects.select { |o| o.isa == 'PBXBuildFile' && o.file_ref && o.file_ref.path =~ /(BoltTheme|BoltBaseCard|TravelModels|BoltTravel|BoltHotel|BoltFlight|BoltPackage|BoltActivity|BoltUIKit)/ }.each do |bf|
  if bf.file_ref.path && !bf.file_ref.path.include?('/') && bf.file_ref.path =~ /^(Bolt|Travel)/
    puts "  Removing duplicate build file: #{bf.file_ref.path}"
    bf.remove_from_project
  end
end

puts "\nRemoving any remaining BoltUIKit groups..."
main_group.children.dup.each do |child|
  if child.display_name =~ /BoltUIKit|BoltTheme|BoltBaseCard|TravelModels|BoltTravel|BoltHotel|BoltFlight|BoltPackage|BoltActivity/
    if child.path && !child.path.include?('/')
      puts "  Removing group: #{child.display_name}"
      child.remove_from_project
    end
  end
end

project.save
puts "\nDeep cleanup complete"