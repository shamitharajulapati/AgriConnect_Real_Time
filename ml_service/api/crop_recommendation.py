import numpy as np

CROP_DB = [
    {'name': 'Tomato', 'emoji': '🍅', 'soils': ['Loamy', 'Sandy', 'Silt'], 'seasons': ['Kharif', 'Rabi'], 'temp_min': 18, 'temp_max': 35, 'rain_min': 600, 'rain_max': 1200, 'duration': '90-120 days', 'water': 'Medium'},
    {'name': 'Wheat', 'emoji': '🌾', 'soils': ['Loamy', 'Clay', 'Silt'], 'seasons': ['Rabi'], 'temp_min': 10, 'temp_max': 25, 'rain_min': 450, 'rain_max': 750, 'duration': '110-130 days', 'water': 'Medium'},
    {'name': 'Rice', 'emoji': '🌾', 'soils': ['Clay', 'Silt'], 'seasons': ['Kharif'], 'temp_min': 22, 'temp_max': 37, 'rain_min': 1000, 'rain_max': 2000, 'duration': '120-150 days', 'water': 'High'},
    {'name': 'Cotton', 'emoji': '🌿', 'soils': ['Black Cotton', 'Loamy'], 'seasons': ['Kharif'], 'temp_min': 21, 'temp_max': 37, 'rain_min': 500, 'rain_max': 850, 'duration': '150-180 days', 'water': 'Medium'},
    {'name': 'Soybean', 'emoji': '🫘', 'soils': ['Loamy', 'Black Cotton'], 'seasons': ['Kharif'], 'temp_min': 20, 'temp_max': 32, 'rain_min': 600, 'rain_max': 1000, 'duration': '90-100 days', 'water': 'Low'},
    {'name': 'Maize', 'emoji': '🌽', 'soils': ['Sandy', 'Loamy', 'Silt'], 'seasons': ['Kharif', 'Rabi', 'Zaid'], 'temp_min': 18, 'temp_max': 33, 'rain_min': 500, 'rain_max': 900, 'duration': '80-110 days', 'water': 'Medium'},
    {'name': 'Onion', 'emoji': '🧅', 'soils': ['Sandy', 'Loamy'], 'seasons': ['Rabi'], 'temp_min': 13, 'temp_max': 28, 'rain_min': 400, 'rain_max': 700, 'duration': '100-120 days', 'water': 'Low'},
    {'name': 'Chillies', 'emoji': '🌶️', 'soils': ['Loamy', 'Sandy', 'Silt'], 'seasons': ['Kharif', 'Rabi'], 'temp_min': 20, 'temp_max': 35, 'rain_min': 600, 'rain_max': 1200, 'duration': '150-180 days', 'water': 'Medium'},
]

def recommend(params: dict) -> dict:
    soil_type = params.get('soilType', 'Loamy')
    temperature = float(params.get('temperature', 28))
    rainfall = float(params.get('rainfall', 800))
    season = params.get('season', 'Kharif')

    scores = []
    for crop in CROP_DB:
        score = 0.0
        if soil_type in crop['soils']:
            score += 0.35
        if crop['temp_min'] <= temperature <= crop['temp_max']:
            score += 0.25
        if crop['rain_min'] <= rainfall <= crop['rain_max']:
            score += 0.25
        if season in crop['seasons']:
            score += 0.15
        scores.append((crop, round(score, 2)))

    scores.sort(key=lambda x: x[1], reverse=True)
    return {
        'recommendations': [
            {
                'crop': c['name'],
                'emoji': c['emoji'],
                'matchScore': s,
                'suitableSoils': c['soils'],
                'duration': c['duration'],
                'waterRequirement': c['water'],
                'reason': f"Suits {soil_type} soil, {season} season, {temperature:.0f}°C and {rainfall:.0f}mm rainfall.",
            }
            for c, s in scores[:5]
        ],
        'inputs': {'soilType': soil_type, 'temperature': temperature, 'rainfall': rainfall},
    }
