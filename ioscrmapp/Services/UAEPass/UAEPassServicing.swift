import Foundation

/// UAE Pass 认证服务协议
protocol UAEPassServicing: Sendable {
    /// 获取 UAE Pass 登录配置
    func getConfig() async throws -> UAEPassConfig

    /// 使用授权码完成登录
    func loginWithCode(code: String, state: String, requestId: String) async throws -> CustSubInfo
}