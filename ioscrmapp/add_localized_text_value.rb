#!/usr/bin/env ruby
# add_localized_text_value.rb - 重新添加 LocalizedTextValue.swift

require 'xcodeproj'

project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'ioscrmapp' }

puts "=========================================="
puts "重新添加 LocalizedTextValue.swift"
puts "=========================================="
puts ""

# 查找或创建 Localization 组
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

base_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp'
file_path = "#{base_path}/ioscrmapp/Core/Localization/LocalizedTextValue.swift"

# 检查文件是否存在
if File.exist?(file_path)
  # 查找 Localization 组
  localization_group = find_or_create_group(project, ['ioscrmapp', 'Core', 'Localization'])

  # 添加文件引用
  file_ref = localization_group.new_file(file_path)
  main_target.source_build_phase.add_file_reference(file_ref)

  puts "✅ 已添加: LocalizedTextValue.swift"
  puts "   路径: #{file_path}"
  puts "   组: Localization"
else
  puts "❌ 文件不存在: #{file_path}"
end

puts ""
puts "保存项目更改..."
project.save

puts ""
puts "✅ 项目已保存"
puts ""
puts "📋 下一步：重新编译验证"