#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
base_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |target| target.name == 'ioscrmapp' }
test_target = project.targets.find { |target| target.name == 'ioscrmappTests' }

def find_or_create_group(project, path_components)
  current_group = project.main_group
  path_components.each do |component|
    child = current_group.children.find { |group| group.display_name == component || group.name == component }
    current_group = if child&.is_a?(Xcodeproj::Project::Object::PBXGroup)
      child
    else
      current_group.new_group(component)
    end
  end
  current_group
end

def add_file(group, target, path)
  return unless File.exist?(path)

  existing = group.files.find { |file| file.path == path || file.real_path.to_s == path }
  file_ref = existing || group.new_file(path)
  target.source_build_phase.add_file_reference(file_ref, true)
end

models_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Models'])
service_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Services'])
view_model_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'ViewModels'])
view_group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'Onboarding', 'Views'])
root_services_group = find_or_create_group(project, ['ioscrmapp', 'Services'])
uae_pass_group = find_or_create_group(project, ['ioscrmapp', 'Services', 'UAEPass'])
test_group = find_or_create_group(project, ['OnboardingTests'])
mock_group = find_or_create_group(project, ['OnboardingTests', 'Mocks'])

add_file(models_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Models/EKYCModels.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCServicing.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCRiskEngineServicing.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCDeviceContextEncryptor.swift")
add_file(service_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Services/EKYCService.swift")
add_file(view_model_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/ViewModels/EKYCViewModel.swift")
add_file(view_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Views/EKYCComponents.swift")
add_file(view_group, main_target, "#{base_path}/ioscrmapp/Modules/Onboarding/Views/EKYCView.swift")
add_file(root_services_group, main_target, "#{base_path}/ioscrmapp/Services/DeviceBiometricServicing.swift")
add_file(root_services_group, main_target, "#{base_path}/ioscrmapp/Services/DocumentOCRServicing.swift")
add_file(uae_pass_group, main_target, "#{base_path}/ioscrmapp/Services/UAEPass/UAEPassOAuthHandling.swift")
add_file(uae_pass_group, main_target, "#{base_path}/ioscrmapp/Services/UAEPass/DemoUAEPassOAuthHandler.swift")

add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCModelsTests.swift")
add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCServiceTests.swift")
add_file(test_group, test_target, "#{base_path}/Tests/OnboardingTests/EKYCViewModelTests.swift")
add_file(mock_group, test_target, "#{base_path}/Tests/OnboardingTests/Mocks/MockEKYCDependencies.swift")

project.save
puts 'Added eKYC files.'
