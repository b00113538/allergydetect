from services.macro_calculator import calculate_tdee, recommend_macros


def test_tdee_male_moderate_activity():
    # BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780; *1.55 = 2759
    assert calculate_tdee(80, 180, 30, "male", "moderate") == 2759


def test_tdee_female_sedentary():
    # BMR = 10*60 + 6.25*165 - 5*30 - 161 = 1320.25; *1.2 = 1584.3 -> 1584
    assert calculate_tdee(60, 165, 30, "female", "sedentary") == 1584


def test_macro_split_lose_fat():
    m = recommend_macros(2500, "lose_fat")
    assert m["calories"] == 2000  # 2500 - 500 deficit
    assert m["protein_g"] == round(2000 * 0.35 / 4)  # 175
    assert m["fat_g"] == round(2000 * 0.30 / 9)  # 67


def test_macro_split_gain_muscle():
    m = recommend_macros(2500, "gain_muscle")
    assert m["calories"] == 2800  # +300 surplus
    assert m["protein_g"] == round(2800 * 0.35 / 4)
    assert m["carbs_g"] == round(2800 * 0.40 / 4)
