#!/usr/bin/env python3
"""
意图识别测试运行器 - 模拟方案1相似度匹配引擎
验证所有测试用例的预期结果
"""

import json
import os
import sys

# ── 意图词集（与 Swift LocalIntentMatcher 一致）──
INTENT_PROFILES_EN = {
    "flight_info": {
        "flight", "tickets", "ticket", "airline", "fly", "airport",
        "book flight", "flight to", "fly to", "book", "flights"
    },
    "hotel_info": {
        "hotel", "accommodation", "room", "stay", "resort",
        "hotel in", "hotel booking", "book hotel",
        "hotels", "booking"
    },
    "itinerary_query": {
        "travel", "trip", "itinerary", "visit", "tour", "journey",
        "go to", "travel to", "trip to", "booking", "ticket", "go",
        "traveling", "travelling"
    },
    "data_usage_query": {
        "data", "usage", "consumption", "remaining", "left", "internet",
        "gb", "mb", "package", "enough", "running", "low", "left",
        "how much data", "my data", "data package", "data usage",
        "data left", "data remaining", "data balance",
        "check data", "check my data", "data consumption",
        "running out", "internet data", "how much", "have left",
        "much data", "data enough"
    },
    "voice_usage_query": {
        "voice", "call", "calls", "minutes", "talk time", "call usage",
        "voice usage", "remaining minutes", "minutes left", "call balance",
        "voice balance", "how many minutes"
    },
    "sms_usage_query": {
        "sms", "text", "texts", "message", "messages", "mms",
        "sms usage", "message usage", "remaining texts", "texts left",
        "sms balance", "how many texts"
    },
    "balance_inquiry": {
        "balance", "credit", "wallet", "check balance", "my balance",
        "remaining balance", "current balance", "account balance",
        "remaining credit", "credit balance"
    },
    "recharge_account": {
        "recharge", "top up", "refill", "add credit", "top", "up",
        "recharge account", "top up account", "recharge my", "my account",
        "topup"
    },
    "view_offers": {
        "offer", "offers", "promotions", "deals", "plans", "packages",
        "available", "view offers", "show offers", "roaming",
        "what offers", "promotions", "deals", "plan"
    },
    "subscribe_offer": {
        "subscribe", "activate", "purchase", "buy", "order",
        "subscribe offer", "buy offer", "activate package",
        "want buy", "need bigger", "data plan", "buy data",
        "new plan", "get plan"
    },
    "view_bill": {
        "bill", "billing", "invoice", "statement", "charges",
        "view bill", "my bill", "billing statement", "monthly bill"
    },
    "account_help": {
        "help", "support", "account", "profile", "settings",
        "service", "complaint", "network issue", "account help",
        "account settings"
    },
    "make_payment": {
        "pay", "payment", "pay now", "make payment", "settle", "due",
        "pay bill", "pay", "make", "pay my"
    },
    "payment_history": {
        "history", "past payments", "payment records", "transaction",
        "payment history", "receipts", "payments"
    },
}

INTENT_PROFILES_ZH = {
    "flight_info": {"机票", "航班", "飞机", "航空", "飞", "订票", "订机票"},
    "hotel_info": {"酒店", "宾馆", "住宿", "房间", "民宿", "订酒店"},
    "itinerary_query": {"旅行", "行程", "出行", "旅游", "预订", "订票", "去", "香港", "游玩"},
    "data_usage_query": {
        "流量", "数据", "剩余", "使用", "消耗", "还有", "多少", "不够",
        "本月", "当前", "查流量", "流", "量", "剩", "用",
    },
    "voice_usage_query": {"语音", "通话", "分钟", "查语音", "查通话", "剩余分钟", "通话时长"},
    "sms_usage_query": {"短信", "彩信", "查短信", "剩余短信", "短信条数", "短信用量"},
    "balance_inquiry": {"余额", "话费", "查询", "查余额", "剩多少钱", "查询余额"},
    "recharge_account": {"充值", "充话费", "充钱", "缴费", "重新充值", "我要充值", "我要", "要充值"},
    "view_offers": {"优惠", "活动", "资费", "套餐", "查看优惠", "可用套餐", "有什么优惠"},
    "subscribe_offer": {"订阅", "办理", "激活", "购买", "订购", "开通", "订阅套餐"},
    "view_bill": {"账单", "发票", "月账单", "查看账单", "消费明细", "查看", "账单"},
    "make_payment": {"支付", "付款", "缴费", "立即支付", "我要支付", "付", "款"},
    "payment_history": {"历史", "记录", "支付记录", "交易记录", "付款历史", "支", "付"},
}

MIN_SCORE = 0.15


def is_chinese(text):
    return any('一' <= c <= '鿿' for c in text)


def tokenize(text, lang="en"):
    """与 Swift 一致的 tokenization"""
    import re
    text = normalize_text(text)
    text = re.sub(r'[^a-z0-9一-鿿؀-ۿ\s]', ' ', text)
    words = text.split()

    tokens = set()
    if lang == "en":
        tokens.update(w for w in words if len(w) >= 2)
        for i in range(len(words) - 1):
            tokens.add(f"{words[i]} {words[i+1]}")
    else:
        # 中文：保留单字 + bigram + 原始词
        chars = list(''.join(words))
        tokens.update(chars)
        for i in range(len(chars) - 1):
            tokens.add(f"{chars[i]}{chars[i+1]}")
        # 也保留原始词组
        tokens.update(words)
    return tokens


def normalize_text(text):
    import re
    normalized = text.lower()
    typo_map = {
        r"\bpakage\b": "package",
        r"\benuff\b": "enough",
        r"\benogh\b": "enough",
        r"\binterent\b": "internet",
        r"\bremaing\b": "remaining",
        r"\blef\b": "left",
    }
    for source, target in typo_map.items():
        normalized = re.sub(source, target, normalized)
    return normalized


def classify(text):
    """模拟 LocalIntentMatcher 相似度分类"""
    lang = "zh" if is_chinese(text) else "en"
    normalized = " ".join(normalize_text(text).split())

    high_certainty = high_certainty_match(normalized, lang)
    if high_certainty is not None:
        return high_certainty

    profiles = INTENT_PROFILES_ZH if lang == "zh" else INTENT_PROFILES_EN
    input_tokens = tokenize(text, lang)

    if not input_tokens:
        return "unknown", 0.0

    best_score = 0.0
    best_intent = "unknown"

    for intent_type, intent_tokens in profiles.items():
        intersect = len(input_tokens & intent_tokens)
        union = len(input_tokens | intent_tokens)

        jaccard = intersect / union if union > 0 else 0
        input_hit = intersect / len(input_tokens) if input_tokens else 0
        combined = jaccard * 0.5 + input_hit * 0.5

        if combined > best_score:
            best_score = combined
            best_intent = intent_type

    if best_score < MIN_SCORE:
        return "unknown", best_score

    confidence = min(0.55 + best_score * 0.50, 0.92)
    return best_intent, confidence


def high_certainty_match(normalized, lang):
    if lang == "en":
        if is_existing_data_package_status_question(normalized):
            return "data_usage_query", 0.92

        if is_balance_question(normalized):
            return "balance_inquiry", 0.90

        has_subscription_verb = any(p in normalized for p in ["subscribe", "activate", "purchase", "buy", "order", "get"])
        has_offer_object = any(p in normalized for p in ["offer", "plan", "package", "bundle", "data plan", "gb"])

        if "buy more data" in normalized or "need a bigger data package" in normalized or "need more data plan" in normalized or (has_subscription_verb and has_offer_object):
            return "subscribe_offer", 0.90

        if (any(p in normalized for p in ["pay", "payment", "settle"]) and any(p in normalized for p in ["bill", "invoice", "statement", "due"])) or "pay my bill" in normalized:
            return "make_payment", 0.90

        if any(p in normalized for p in ["invoice", "billing statement", "monthly bill", "view my bill", "show my bill"]) and not any(p in normalized for p in ["pay", "payment", "settle"]):
            return "view_bill", 0.88

        if (any(p in normalized for p in ["offer", "offers", "promotion", "promotions", "deal", "deals", "plan", "plans", "package", "packages"]) and any(p in normalized for p in ["what", "any", "available", "show", "view", "current"])) or normalized == "promotions":
            return "view_offers", 0.88

        if "how much credit do i have" in normalized or ("credit" in normalized and any(p in normalized for p in ["how much", "remaining", "current", "check"])):
            return "balance_inquiry", 0.88

        if any(p in normalized for p in ["voice", "call", "calls", "minutes", "talk time"]) and any(p in normalized for p in ["check", "remaining", "left", "usage", "balance", "how many"]):
            return "voice_usage_query", 0.88

        if any(p in normalized for p in ["sms", "text", "texts", "message", "messages", "mms"]) and any(p in normalized for p in ["check", "remaining", "left", "usage", "balance", "how many"]):
            return "sms_usage_query", 0.88
    else:
        if normalized in ["余额", "الرصيد"] or any(p in normalized for p in ["查看余额", "查询余额", "查余额", "رصيد", "الرصيد"]):
            return "balance_inquiry", 0.90

        if ("支付" in normalized or "付款" in normalized) and ("账单" in normalized or "发票" in normalized):
            return "make_payment", 0.90

        if "查看账单" in normalized or "月账单" in normalized or "发票" in normalized:
            return "view_bill", 0.88

        if "订阅套餐" in normalized or "购买套餐" in normalized or "办理套餐" in normalized or "开通套餐" in normalized:
            return "subscribe_offer", 0.90

        if "有什么优惠" in normalized or "可用套餐" in normalized or "查看优惠" in normalized:
            return "view_offers", 0.88

        if "查余额" in normalized or "查询余额" in normalized or "话费余额" in normalized:
            return "balance_inquiry", 0.88

        if "查语音" in normalized or "剩余分钟" in normalized or "通话还剩多少" in normalized:
            return "voice_usage_query", 0.88

        if "查短信" in normalized or "剩余短信" in normalized or "短信还剩多少" in normalized:
            return "sms_usage_query", 0.88

    return None


def is_existing_data_package_status_question(normalized):
    has_data_package_object = any(p in normalized for p in [
        "data package", "data plan", "data bundle", "data allowance",
        "my data", "current data", "existing data",
    ])
    if not has_data_package_object:
        return False

    is_purchase_or_upgrade_request = any(p in normalized for p in [
        "subscribe", "activate", "purchase", "buy", "order",
        "buy more data", "need more data", "need a bigger",
        "upgrade", "add extra data", "get more data",
        "my data is running out", "data is running out",
    ])
    if is_purchase_or_upgrade_request:
        return False

    return any(p in normalized for p in [
        "my data package", "my data plan", "my data bundle",
        "current data package", "current data plan", "existing data package",
        "what about my data", "what about my data package",
        "how is my data package", "tell me about my data package",
        "data package status", "data package remaining", "data package left",
        "data package enough", "data allowance",
    ])


def is_balance_question(normalized):
    if "balance" not in normalized:
        return False
    if any(p in normalized for p in ["data balance", "sms balance", "voice balance", "call balance"]):
        return False
    return any(p in normalized for p in ["check", "my", "current", "remaining", "how much", "what is", "show", "view"])


def needs_confirmation(confidence):
    return confidence < 0.70


def run():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    test_path = os.path.join(script_dir, "intent_test_cases.json")

    with open(test_path, "r", encoding="utf-8") as f:
        test_data = json.load(f)

    print("=" * 75)
    print("  意图识别测试报告")
    print("  覆盖: 方案1(相似度匹配) + 方案2(增强模型) + 方案4(确认机制)")
    print("=" * 75)

    total = 0
    passed = 0
    failed = 0
    confirmation_needed = 0

    for suite in test_data["test_suites"]:
        print(f"\n── {suite['name']} ──")
        default_expected = suite.get("expected")

        for case in suite["cases"]:
            total += 1
            if isinstance(case, dict):
                text = case["text"]
                expected = case["expected"]
            else:
                text = case
                expected = default_expected

            predicted, confidence = classify(text)
            match = "✓" if predicted == expected else "✗"
            confirm = " [需确认]" if needs_confirmation(confidence) else ""

            if predicted == expected:
                passed += 1
            else:
                failed += 1

            if needs_confirmation(confidence):
                confirmation_needed += 1

            print(f"  {match} {text:<50} → {predicted:<22} ({confidence:.2f}){confirm}")

    print("\n" + "=" * 75)
    print(f"  总计: {total} | 通过: {passed} | 失败: {failed} | 准确率: {passed/total*100:.1f}%")
    print(f"  需确认(conf<0.70): {confirmation_needed}/{total} = {confirmation_needed/total*100:.0f}%")
    print("=" * 75)

    if failed:
        print(f"\n  失败用例 ({failed}):")
        # Re-run failed cases for clarity
        for suite in test_data["test_suites"]:
            default_expected = suite.get("expected")
            for case in suite["cases"]:
                if isinstance(case, dict):
                    text, expected = case["text"], case["expected"]
                else:
                    text, expected = case, default_expected
                predicted, _ = classify(text)
                if predicted != expected:
                    print(f"    ✗ '{text}' → {predicted} (expected: {expected})")


if __name__ == "__main__":
    run()
