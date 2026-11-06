extends RefCounted

const DATA := {
    "P01": {"name": "贯星导轨", "weapon": "pulse", "damage": 0.85, "pierce": 2, "note": "额外穿透2个目标；伤害 −15%"},
    "P02": {"name": "回响棱镜", "weapon": "pulse", "damage": 0.75, "note": "最终命中后跳向新目标一次；伤害 −25%，跳弹60%"},
    "P03": {"name": "近卫轴承", "weapon": "orbit", "damage": 1.3, "radius": 0.8, "note": "伤害 +30%；环绕半径 −20%"},
    "P04": {"name": "远弧支架", "weapon": "orbit", "damage": 0.8, "radius": 1.25, "rotation": 0.9, "note": "环绕半径 +25%；伤害 −20%，角速度 −10%"},
    "P05": {"name": "急放线圈", "weapon": "nova", "damage": 0.72, "cooldown": 0.75, "radius": 0.85, "note": "冷却 −25%；伤害 −28%，半径 −15%"},
    "P06": {"name": "广域振片", "weapon": "nova", "damage": 0.85, "cooldown": 1.2, "radius": 1.3, "knockback": 1.4, "note": "半径 +30%，普通怪击退 +40%；伤害 −15%，冷却延长20%"},
    "P07": {"name": "急速齿轮", "weapon": "turret", "damage": 0.8, "shot_cooldown": 0.75, "lifetime": 0.85, "note": "射击冷却 −25%；伤害 −20%，持续时间 −15%"},
    "P08": {"name": "长焦灯罩", "weapon": "turret", "range": 1.5, "shot_cooldown": 1.25, "note": "射程 +50%；射击冷却延长25%"}
}
