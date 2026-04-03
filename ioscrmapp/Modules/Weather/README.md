首页：
- 当前天气（温度/体感/天气状态） + 核心3D动态展示（风雨雷电昼夜变化）
- 今日/逐小时预报（简化版）
- 日期切换

详情页：
- 完整天气数据展开（温度曲线/体感/最高最低）
- 逐小时&未来多日预报（完整）
- 多维度拆解
  - 分钟级降雨详细时间轴
  - 空气质量AQI+花粉
  - 风向风速+阵风
  - 湿度/气压/能见度/云量/UV等全量指标
  - 天气预警详细内容


cd /Volumes/Inspur/OBDCRM/ioscrmapp/ioscrmapp && \
xcodebuild -project ioscrmapp.xcodeproj -scheme ioscrmapp-Develop \
  -destination "platform=iOS Simulator,id=C84EB816-4CF8-4CA9-BD25-9CCDD0EDD6E4" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3 && \
rm -rf /tmp/DuApp2.app && \
cp -r "/Users/mac/Library/Developer/Xcode/DerivedData/ioscrmapp-aguiclexddelbnfuzuqsqzertipg/Build/Products/Debug-iphonesimulator/Du App.app" /tmp/DuApp2.app && \
cp "/tmp/DuApp2.app/Du App" /tmp/DuApp2.app/DuApp2 && rm "/tmp/DuApp2.app/Du App" && \
python3 -c "
import plistlib
with open('/tmp/DuApp2.app/Info.plist','rb') as f: p=plistlib.load(f)
p['CFBundleExecutable']='DuApp2'; p['CFBundleVersion']='1'
with open('/tmp/DuApp2.app/Info.plist','wb') as f: plistlib.dump(p,f,fmt=plistlib.FMT_XML)
" && \
codesign --force --sign "iPhone Developer" --identifier "com.inspur.ioscrmapp" /tmp/DuApp2.app && \
xcrun simctl uninstall C84EB816-4CF8-4CA9-BD25-9CCDD0EDD6E4 com.inspur.ioscrmapp 2>/dev/null; \
xcrun simctl install C84EB816-4CF8-4CA9-BD25-9CCDD0EDD6E4 /tmp/DuApp2.app && \
xcrun simctl launch C84EB816-4CF8-4CA9-BD25-9CCDD0EDD6E4 com.inspur.ioscrmapp

1. 旋转到侧面 看着天气靠前 文本靠后
2. 天气稍微靠下一点
3. 在正面云彩完全看不到轮廓
4. 文字的线条太细 并且转折比较多 能否抽象一点文本的线条
5. 切换时