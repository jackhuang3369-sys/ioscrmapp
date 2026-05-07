#!/usr/bin/env python3
"""
数据增强脚本：对训练数据进行同义替换、句式变换和拼写容错，
将样本从 215 条扩展到 800+ 条，提升 Core ML 模型泛化能力。
"""

import json
import os
import random
import sys

random.seed(42)

# ── 英文同义替换映射 ──
SYNONYM_MAP = {
    "check": ["see", "view", "look at", "show", "display"],
    "how much": ["how many", "what's my", "what is my", "tell me my"],
    "how can i": ["how do i", "how to", "can i", "help me"],
    "remaining": ["left", "available", "still have", "unused"],
    "data": ["internet data", "mobile data", "cellular data", "data plan"],
    "usage": ["consumption", "used", "utilization"],
    "balance": ["credit", "remaining balance", "account balance", "wallet"],
    "recharge": ["top up", "refill", "add credit to", "load"],
    "account": ["my account", "mobile account", "phone account"],
    "offers": ["deals", "promotions", "plans", "packages"],
    "subscribe": ["sign up for", "activate", "get", "purchase", "buy"],
    "bill": ["invoice", "statement", "billing", "charges"],
    "payment": ["pay", "settle", "clear"],
    "enough": ["sufficient", "adequate", "running out", "running low"],
    "package": ["plan", "bundle", "data package"],
    "help": ["support", "assistance", "help me with"],
    "travel": ["trip", "journey", "visit", "go"],
    "flight": ["plane", "air ticket", "airline"],
    "hotel": ["accommodation", "room", "place to stay"],
    "want": ["need", "would like to", "wish to", "looking to"],
    "tell me": ["let me know", "show me", "inform me about"],
    "can i": ["may i", "is it possible to", "am i able to"],
}

# ── 中文同义替换映射 ──
ZH_SYNONYM_MAP = {
    "查询": ["查看", "查", "看一下", "帮我查"],
    "流量": ["数据流量", "上网流量", "移动数据", "网络流量"],
    "剩余": ["剩下", "还有", "可用", "未用"],
    "余额": ["话费余额", "账户余额", "剩余话费", "钱"],
    "充值": ["充话费", "缴费", "充钱", "续费"],
    "优惠": ["活动", "折扣", "特惠", "促销"],
    "套餐": ["资费", "流量包", "套餐包"],
    "账单": ["月账单", "消费单", "发票"],
    "支付": ["付款", "缴费", "交费"],
    "怎么": ["如何", "怎样", "咋"],
    "多少": ["几多", "多少了", "有多少"],
}

# ── 常见拼写错误 ──
TYPO_MAP = {
    "check": ["chek", "chekc", "chcek"],
    "balance": ["balence", "balanc", "balnace"],
    "remaining": ["remainig", "remainning", "remaing"],
    "recharge": ["rechage", "rechrge", "recharj"],
    "account": ["acount", "accont", "accout"],
    "subscribe": ["subscibe", "subscrib", "suscribe"],
    "payment": ["paymnet", "paymet", "paymen"],
    "history": ["histroy", "histoyr", "histry"],
    "flight": ["fligth", "flihgt", "fllight"],
    "hotel": ["hotle", "hoetl", "hotal"],
    "travel": ["travle", "traval", "travvel"],
    "ticket": ["tiket", "tickt", "tickit"],
    "enough": ["enouhg", "enogh", "enuf", "enuff"],
    "package": ["pakage", "pakcage", "pakg"],
    "internet": ["interent", "intrenet", "internat"],
    "roaming": ["roamingg", "roamin", "roaing"],
    "offers": ["ofer", "offrs", "ofers"],
    "itinerary": ["itinery", "itinarery", "itinari"],
}


def synonym_augment(text, lang):
    """对单个文本进行同义替换，生成 3-5 个变体"""
    if lang != "english" and lang != "simplifiedChinese":
        return []

    syn_map = SYNONYM_MAP if lang == "english" else ZH_SYNONYM_MAP
    text_lower = text.lower()
    variants = []

    # 对每个可替换的词，生成一个变体
    for original, synonyms in syn_map.items():
        if original in text_lower:
            for syn in random.sample(synonyms, min(3, len(synonyms))):
                variants.append(text_lower.replace(original, syn))

    return list(set(variants))  # 去重


def typo_augment(text, lang):
    """对英文文本注入常见拼写错误，生成 1-2 个变体"""
    if lang != "english":
        return []

    text_lower = text.lower()
    variants = []

    for correct, typos in TYPO_MAP.items():
        if correct in text_lower:
            for typo in random.sample(typos, min(1, len(typos))):
                variants.append(text_lower.replace(correct, typo))

    return variants


def structure_augment(text, lang):
    """句式变换：调整词序或添加/移除功能词"""
    if lang != "english":
        return []

    variants = []
    text_lower = text.lower()

    # 加问号
    if not text_lower.endswith("?"):
        variants.append(text_lower + "?")

    # 加 please
    if not text_lower.startswith("please") and not text_lower.startswith("can"):
        variants.append("please " + text_lower)

    # I want to / I need to / Can I 等等
    if text_lower.startswith("check"):
        variants.append("can i " + text_lower + "?")
        variants.append("i want to " + text_lower)
        variants.append("i need to " + text_lower)
    elif text_lower.startswith("view"):
        variants.append("can you show me " + text_lower.replace("view ", ""))
        variants.append("let me " + text_lower)
    elif text_lower.startswith("show"):
        variants.append("could you " + text_lower + "?")

    return variants


def augment_training_data(input_path, output_path):
    """主增强函数"""
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    original_count = 0
    augmented_count = 0

    for item in data["training_data"]:
        intent = item["intent_type"]
        original_samples = list(item["samples"])
        original_count += len(original_samples)

        new_samples = []
        existing_texts = {s["text"].lower() for s in original_samples}

        for sample in original_samples:
            text = sample["text"]
            lang = sample.get("language", "english")

            # 同义替换变体
            for variant in synonym_augment(text, lang):
                if variant not in existing_texts and len(variant) > 3:
                    existing_texts.add(variant)
                    new_samples.append({"text": variant, "language": lang})

            # 拼写容错变体（仅英文）
            for variant in typo_augment(text, lang):
                if variant not in existing_texts and len(variant) > 3:
                    existing_texts.add(variant)
                    new_samples.append({"text": variant, "language": lang})

            # 句式变换（仅英文）
            for variant in structure_augment(text, lang):
                if variant not in existing_texts and len(variant) > 3:
                    existing_texts.add(variant)
                    new_samples.append({"text": variant, "language": lang})

        item["samples"].extend(new_samples)
        augmented_count += len(new_samples)

        print(f"  {intent}: {len(original_samples)} → {len(original_samples) + len(new_samples)} (+{len(new_samples)})")

    # 更新 intent_types
    all_intents = sorted(set(item["intent_type"] for item in data["training_data"]))
    data["intent_types"] = all_intents
    data["version"] = "2.1"

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    total = original_count + augmented_count
    print(f"\nTotal: {original_count} original → {total} augmented ({augmented_count} new)")


def export_csv(json_path, csv_path):
    """导出为 CreateML 格式 CSV"""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    with open(csv_path, "w") as f:
        f.write("text,label\n")
        for item in data["training_data"]:
            for sample in item["samples"]:
                text = sample["text"].replace('"', '""')
                f.write(f'"{text}",{item["intent_type"]}\n')

    print(f"CSV exported: {csv_path}")


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_path = os.path.join(script_dir, "intent_training_data_v2.json")
    output_path = os.path.join(script_dir, "intent_training_data_v2_augmented.json")
    csv_path = os.path.join(script_dir, "training_data_augmented.csv")

    print("Augmenting training data...\n")
    augment_training_data(input_path, output_path)
    print(f"\nAugmented JSON saved: {output_path}")

    print("\nExporting CSV...")
    export_csv(output_path, csv_path)
    print("\nDone.")
