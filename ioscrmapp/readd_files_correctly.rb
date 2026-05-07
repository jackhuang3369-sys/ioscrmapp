#!/usr/bin/env ruby
# readd_files_correctly.rb - 删除错误引用并重新正确添加文件

require 'xcodeproj'

# 项目路径（使用绝对路径）
project_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'

# 打开项目
project = Xcodeproj::Project.open(project_path)

# 获取主 Target
main_target = project.targets.find { |t| t.name == 'ioscrmapp' }

# 要添加的文件列表（使用绝对路径）
base_path = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp'

files_to_add = {
  models: [
    "#{base_path}/ioscrmapp/Modules/AI/Models/IntentModels.swift",
    "#{base_path}/ioscrmapp/Modules/AI/Models/IntentClassificationModels.swift"
  ],
  services: [
    "#{base_path}/ioscrmapp/Services/IntentRecognitionService.swift",
    "#{base_path}/ioscrmapp/Services/IntentRecognitionIntegrationExample.swift"
  ],
  utilities: [
    "#{base_path}/ioscrmapp/Utilities/LocalIntentMatcher.swift",
    "#{base_path}/ioscrmapp/Utilities/IntentConfidenceCalculator.swift"
  ],
  views: [
    "#{base_path}/ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift"
  ]
}

puts "=========================================="
puts "删除错误引用并重新添加文件"
puts "=========================================="
puts ""

# 步骤 1：删除所有意图识别相关的文件引用
puts "步骤 1：删除旧的文件引用..."

removed_count = 0

# 从 Build Phase 中移除
main_target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  if file_ref
    file_name = file_ref.display_name
    if file_name.include?('Intent') || file_name.include?('Local') || file_name.include?('Confidence')
      puts "  移除 Build File: #{file_name}"
      build_file.remove_from_project
      removed_count += 1
    end
  end
end

# 从项目中移除文件引用
project.files.each do |file|
  file_name = file.display_name
  if file_name.include?('Intent') || file_name.include?('Local') || file_name.include?('Confidence')
    puts "  移除 File Reference: #{file_name}"
    file.remove_from_project
    removed_count += 1
  end
end

puts ""
puts "已移除 #{removed_count} 个引用"
puts ""

# 步骤 2：重新正确添加文件
puts "步骤 2：重新正确添加文件..."

# 辅助函数：查找或创建组
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

added_count = 0

files_to_add.each do |group_type, file_list|
  puts "添加 #{group_type} 文件..."

  case group_type
  when :models
    group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'AI', 'Models'])
  when :services
    group = find_or_create_group(project, ['ioscrmapp', 'Services'])
  when :utilities
    group = find_or_create_group(project, ['ioscrmapp', 'Utilities'])
  when :views
    group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'AI', 'Views'])
  end

  file_list.each do |file_path|
    # 检查文件是否存在
    if File.exist?(file_path)
      file_ref = group.new_file(file_path)
      main_target.source_build_phase.add_file_reference(file_ref)
      puts "  ✅ 已添加: #{File.basename(file_path)}"
      added_count += 1
    else
      puts "  ❌ 文件不存在: #{file_path}"
    end
  end

  puts ""
end

# 保存项目
puts "保存项目更改..."
project.save

puts ""
puts "=========================================="
puts "重新添加完成"
puts "=========================================="
puts ""
puts "统计结果："
puts "- 移除引用: #{removed_count}"
puts "- 新添加文件: #{added_count}"
puts ""

if added_count == 7
  puts "✅ 所有文件已正确重新添加！"
  puts ""
  puts "📋 下一步操作："
  puts "1. 重新编译验证:"
  puts "   xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop clean build"
  puts ""
end

exit 0