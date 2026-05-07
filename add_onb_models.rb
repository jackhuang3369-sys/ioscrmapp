#!/usr/bin/env ruby
# Add ONBPersonaModels.swift to Xcode project

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'ioscrmapp' }
main_group = project.main_group['ioscrmapp']

# Find Modules group
modules_group = main_group.groups.find { |g| g.display_name == 'Modules' || g.name == 'Modules' }
if modules_group
  puts "Found Modules group"
  # Find AI group inside Modules
  ai_group = modules_group.groups.find { |g| g.display_name == 'AI' || g.name == 'AI' }
  if ai_group
    puts "Found AI group"
    models_group = ai_group.groups.find { |g| g.display_name == 'Models' || g.name == 'Models' }
    if models_group
      puts "Found Models group"
      file_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/Modules/AI/Models/ONBPersonaModels.swift'
      if File.exist?(file_path)
        # Check if already exists
        existing = project.objects.find { |o| o.isa == 'PBXFileReference' && o.path == 'ONBPersonaModels.swift' }
        if existing
          puts "Already in project: ONBPersonaModels.swift"
        else
          file_ref = models_group.new_file(file_path)
          target.source_build_phase.add_file_reference(file_ref)
          puts "Added: ONBPersonaModels.swift"
        end
      else
        puts "File not found: #{file_path}"
      end
    else
      puts "Models group not found in AI"
      # List all groups in AI
      ai_group.groups.each { |g| puts "  - #{g.display_name}" }
    end
  else
    puts "AI group not found in Modules"
    # List all groups in Modules
    modules_group.groups.each { |g| puts "  - #{g.display_name}" }
  end
else
  puts "Modules group not found"
  # List all groups in main_group
  main_group.groups.each { |g| puts "  - #{g.display_name}" }
end

project.save
puts "Done"