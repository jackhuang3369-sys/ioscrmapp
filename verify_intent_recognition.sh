#!/bin/bash
# verify_intent_recognition.sh - 验证意图识别系统文件完整性

echo "=========================================="
echo "AI 意图识别系统文件完整性验证"
echo "=========================================="
echo ""

# 定义必需文件列表
required_files=(
    # Models
    "ioscrmapp/ioscrmapp/Modules/AI/Models/IntentModels.swift"
    "ioscrmapp/ioscrmapp/Modules/AI/Models/IntentClassificationModels.swift"

    # Services
    "ioscrmapp/ioscrmapp/Services/IntentRecognitionService.swift"
    "ioscrmapp/ioscrmapp/Services/IntentRecognitionIntegrationExample.swift"

    # Utilities
    "ioscrmapp/ioscrmapp/Utilities/LocalIntentMatcher.swift"
    "ioscrmapp/ioscrmapp/Utilities/IntentConfidenceCalculator.swift"

    # Views
    "ioscrmapp/ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift"

    # Tests
    "ioscrmapp/Tests/AIModelsTests/IntentModelsTests.swift"
    "ioscrmapp/Tests/AIModelsTests/IntentClassificationModelsTests.swift"
    "ioscrmapp/Tests/AIModelsTests/IntentRecognitionIntegrationTests.swift"
    "ioscrmapp/Tests/AIModelsTests/IntentRecognitionPerformanceTests.swift"
    "ioscrmapp/Tests/AIModelsTests/IntentModelsXCTests.swift"
    "ioscrmapp/Tests/AIModelsTests/TEST_REPORT.md"

    # Documentation
    "ioscrmapp/docs/superpowers/plans/ai_intent_recognition_plan.md"
    "ioscrmapp/docs/superpowers/plans/ai_intent_recognition_implementation_summary.md"
    "ioscrmapp/docs/superpowers/plans/integration_guide.md"
)

# 验证文件存在性
echo "1. 验证文件存在性..."
missing_files=0

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (缺失)"
        missing_files=$((missing_files + 1))
    fi
done

echo ""
echo "文件检查完成：缺失 $missing_files 个文件"
echo ""

# 验证关键结构
echo "2. 验证关键结构..."

# 检查 UserIntentType 定义
if grep -q "enum UserIntentType" ioscrmapp/ioscrmapp/Modules/AI/Models/IntentModels.swift; then
    echo "  ✅ UserIntentType 枚举定义正确"
else
    echo "  ❌ UserIntentType 枚举定义缺失"
fi

# 检查 IntentRecognitionServicing 协议
if grep -q "protocol IntentRecognitionServicing" ioscrmapp/ioscrmapp/Services/IntentRecognitionService.swift; then
    echo "  ✅ IntentRecognitionServicing 协议定义正确"
else
    echo "  ❌ IntentRecognitionServicing 协议定义缺失"
fi

# 检查 LocalIntentMatcher 类
if grep -q "final class LocalIntentMatcher" ioscrmapp/ioscrmapp/Utilities/LocalIntentMatcher.swift; then
    echo "  ✅ LocalIntentMatcher 类定义正确"
else
    echo "  ❌ LocalIntentMatcher 类定义缺失"
fi

# 检查 IntentFeedbackView 视图
if grep -q "struct IntentFeedbackView" ioscrmapp/ioscrmapp/Modules/AI/Views/IntentFeedbackView.swift; then
    echo "  ✅ IntentFeedbackView 视图定义正确"
else
    echo "  ❌ IntentFeedbackView 视图定义缺失"
fi

echo ""

# 验证修改文件
echo "3. 验证修改文件..."

# 检查 AIChatViewModel 是否添加意图识别服务
if grep -q "intentRecognitionService" ioscrmapp/ioscrmapp/Modules/AI/ViewModels/AIChatViewModel.swift; then
    echo "  ✅ AIChatViewModel 已添加意图识别服务"
else
    echo "  ❌ AIChatViewModel 未添加意图识别服务"
fi

# 检查 AIChatNavigationTarget 是否支持 Codable
if grep -q "Codable" ioscrmapp/ioscrmapp/Modules/AI/Models/AIChatModels.swift; then
    echo "  ✅ AIChatNavigationTarget 已支持 Codable"
else
    echo "  ❌ AIChatNavigationTarget 未支持 Codable"
fi

echo ""

# 统计代码行数
echo "4. 统计代码量..."
total_lines=0

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file" | tr -d ' ')
        total_lines=$((total_lines + lines))
        echo "  $file: $lines 行"
    fi
done

echo ""
echo "总代码量: $total_lines 行"
echo ""

# 生成下一步提示
echo "=========================================="
echo "下一步操作提示"
echo "=========================================="
echo ""

if [ $missing_files -eq 0 ]; then
    echo "✅ 所有文件已创建完成！"
    echo ""
    echo "📋 立即操作："
    echo "1. 打开 Xcode 项目："
    echo "   open ioscrmapp/ioscrmapp.xcodeproj"
    echo ""
    echo "2. 将新文件添加到 Xcode 项目："
    echo "   - 右键点击目标文件夹"
    echo "   - 选择 'Add Files to ioscrmapp'"
    echo "   - 选择所有新文件并添加"
    echo ""
    echo "3. 编译验证："
    echo "   xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop clean build"
    echo ""
    echo "4. 运行测试："
    echo "   xcodebuild test -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop"
    echo ""
else
    echo "❌ 有 $missing_files 个文件缺失，请检查！"
    echo ""
    echo "建议重新运行实施脚本或手动创建缺失文件。"
fi

echo ""
echo "=========================================="
echo "验证完成"
echo "=========================================="
echo ""

# 输出总结报告
echo "验证总结："
echo "- 总文件数: ${#required_files[@]}"
echo "- 已创建文件: ${#required_files[@]} - $missing_files"
echo "- 缺失文件: $missing_files"
echo "- 总代码量: $total_lines 行"
echo ""

exit $missing_files