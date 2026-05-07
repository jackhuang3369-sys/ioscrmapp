#!/usr/bin/env ruby
# add_files_to_xcode.rb - 自动添加意图识别系统文件到 Xcode 项目

require 'xcodeproj'

# 项目路径（相对于脚本执行位置）
project_path = 'ioscrmapp.xcodeproj'

# 打开项目
project = Xcodeproj::Project.open(project_path)

# 获取主 Target
main_target = project.targets.find { |t| t.name == 'ioscrmapp' }

# 获取 Test Target（如果存在）
test_target = project.targets.find { |t| t.name.include?('Test') }

# 定义要添加的文件列表（相对于 ioscrmapp 目录）
files_to_add = {
  # Models - 添加到 Modules/AI/Models 组
  models_files: [
    'ioscrmapp/Modules/AI/Models/IntentModels.swift',
    'ioscrmapp/Modules/AI/Models/IntentClassificationModels.swift'
  ],

  # Services - 添加到 Services 组
  services_files: [
    'ioscrmapp/Services/IntentRecognitionService.swift',
    'ioscrmapp/Services/IntentRecognitionIntegrationExample.swift'
  ],

  # Utilities - 添加到 Utilities 组
  utilities_files: [
    'ioscrmapp/Utilities/LocalIntentMatcher.swift',
    'ioscrmapp/Utilities/IntentConfidenceCalculator.swift'
  ],

  # Views - 添加到 Modules/AI/Views 组
  views_files: [
    'ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift'
  ]
}

# 测试文件列表
test_files = [
    'Tests/AIModelsTests/IntentModelsTests.swift',
    'Tests/AIModelsTests/IntentClassificationModelsTests.swift',
    'Tests/AIModelsTests/IntentRecognitionIntegrationTests.swift',
    'Tests/AIModelsTests/IntentRecognitionPerformanceTests.swift',
    'Tests/AIModelsTests/IntentModelsXCTests.swift'
]

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

# 辅助函数：添加文件引用到组和 Target
def add_file_to_project(file_path, group, target, project)
  # 检查文件是否存在
  unless File.exist?(file_path)
    puts "⚠️  文件不存在: #{file_path}"
    return false
  end

  # 检查文件是否已在项目中
  existing_file = project.files.find { |f| f.display_name == File.basename(file_path) }
  if existing_file
    puts "✅ 文件已在项目中: #{File.basename(file_path)}"
    return true
  end

  # 创建文件引用
  file_ref = group.new_file(file_path)

  # 添加到 Target 的 Build Phase
  if target
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ 已添加: #{File.basename(file_path)} -> #{group.display_name}"
  end

  true
end

puts "=========================================="
puts "开始添加文件到 Xcode 项目"
puts "=========================================="
puts ""

# 添加源文件
files_added_count = 0
files_failed_count = 0

files_to_add.each do |group_type, file_list|
  puts "添加 #{group_type} 文件..."

  case group_type
  when :models_files
    group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'AI', 'Models'])
  when :services_files
    group = find_or_create_group(project, ['ioscrmapp', 'Services'])
  when :utilities_files
    group = find_or_create_group(project, ['ioscrmapp', 'Utilities'])
  when :views_files
    group = find_or_create_group(project, ['ioscrmapp', 'Modules', 'AI', 'Views'])
  else
    group = project.main_group
  end

  file_list.each do |file_path|
    if add_file_to_project(file_path, group, main_target, project)
      files_added_count += 1
    else
      files_failed_count += 1
    end
  end

  puts ""
end

# 添加测试文件（如果有 Test Target）
if test_target
  puts "添加测试文件..."

  test_group = find_or_create_group(project, ['Tests', 'AIModelsTests'])

  test_files.each do |file_path|
    if add_file_to_project(file_path, test_group, test_target, project)
      files_added_count += 1
    else
      files_failed_count += 1
    end
  end

  puts ""
else
  puts "⚠️  未找到 Test Target，测试文件暂不添加"
  puts ""
end

# 保存项目
puts "保存项目更改..."
project.save

puts ""
puts "=========================================="
puts "文件添加完成"
puts "=========================================="
puts ""
puts "统计结果："
puts "- 成功添加文件: #{files_added_count}"
puts "- 添加失败文件: #{files_failed_count}"
puts ""

if files_failed_count == 0
  puts "✅ 所有文件已成功添加到 Xcode 项目！"
  puts ""
  puts "📋 下一步操作："
  puts "1. 打开 Xcode 验证文件:"
  puts "   open ioscrmapp/ioscrmapp.xcodeproj"
  puts ""
  puts "2. 编译验证:"
  puts "   xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop clean build"
  puts ""
  puts "3. 检查 Target Membership:"
  puts "   在 Xcode 中选择每个文件，确认 Target Membership 正确"
end

puts ""
puts "=========================================="
puts "脚本执行完成"
puts "=========================================="

exit files_failed_count