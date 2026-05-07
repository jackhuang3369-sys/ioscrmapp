#!/usr/bin/env ruby
# fix_file_references.rb - 修正 Xcode 项目中的文件路径引用

require 'xcodeproj'

# 项目路径
project_path = 'ioscrmapp.xcodeproj'

# 打开项目
project = Xcodeproj::Project.open(project_path)

# 获取主 Target
main_target = project.targets.find { |t| t.name == 'ioscrmapp' }

# 正确的文件路径映射（相对于 ioscrmapp 目录）
correct_file_paths = {
  'IntentModels.swift' => 'ioscrmapp/Modules/AI/Models/IntentModels.swift',
  'IntentClassificationModels.swift' => 'ioscrmapp/Modules/AI/Models/IntentClassificationModels.swift',
  'IntentRecognitionService.swift' => 'ioscrmapp/Services/IntentRecognitionService.swift',
  'IntentRecognitionIntegrationExample.swift' => 'ioscrmapp/Services/IntentRecognitionIntegrationExample.swift',
  'LocalIntentMatcher.swift' => 'ioscrmapp/Utilities/LocalIntentMatcher.swift',
  'IntentConfidenceCalculator.swift' => 'ioscrmapp/Utilities/IntentConfidenceCalculator.swift',
  'IntentFeedbackView.swift' => 'ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift'
}

puts "=========================================="
puts "修正文件路径引用"
puts "=========================================="
puts ""

# 查找并修正文件引用
fixed_count = 0
failed_count = 0

project.files.each do |file|
  file_name = file.display_name

  if correct_file_paths.key?(file_name)
    correct_path = correct_file_paths[file_name]

    # 检查当前路径是否正确
    current_path = file.path

    if current_path != correct_path
      puts "修正 #{file_name}:"
      puts "  当前路径: #{current_path}"
      puts "  正确路径: #{correct_path}"

      # 设置正确的路径
      file.path = correct_path
      puts "  ✅ 已修正"
      fixed_count += 1
    else
      puts "✅ #{file_name} 路径已正确"
    end
  end
end

puts ""
puts "=========================================="
puts "修正完成"
puts "=========================================="
puts ""
puts "统计结果："
puts "- 修正文件: #{fixed_count}"
puts "- 失败文件: #{failed_count}"
puts ""

# 保存项目
puts "保存项目更改..."
project.save

puts ""
puts "✅ 项目已保存"
puts ""
puts "📋 下一步操作："
puts "1. 重新编译验证:"
puts "   xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop clean build"
puts ""

exit failed_count