#!/usr/bin/env python3
"""
OCR Test Harness for MeterScience
Tests the digit filtering logic with sample meter images.

Usage:
    python test_ocr.py [image_path]

If no image path given, downloads sample meter images for testing.
"""

import sys
import re
from pathlib import Path

# Simulated OCR results - what Vision framework might return
SAMPLE_OCR_RESULTS = [
    # Test case: 6-digit electric meter
    {
        "image": "electric_meter_1.jpg",
        "expected_digits": 6,
        "last_reading": 12345.0,
        "ocr_texts": [
            {"text": "123456", "confidence": 0.95},  # Correct reading
            {"text": "1234567", "confidence": 0.88},  # Too many digits
            {"text": "12345", "confidence": 0.82},   # Too few digits
            {"text": "SN-89012345", "confidence": 0.91},  # Serial number
            {"text": "kWh", "confidence": 0.99},
        ]
    },
    # Test case: 5-digit gas meter with last reading
    {
        "image": "gas_meter_1.jpg",
        "expected_digits": 5,
        "last_reading": 45678.0,
        "ocr_texts": [
            {"text": "45692", "confidence": 0.92},  # Plausible (slight increase)
            {"text": "12345", "confidence": 0.87},  # Implausible (way lower)
            {"text": "99999", "confidence": 0.85},  # Implausible (way higher)
            {"text": "45700", "confidence": 0.78},  # Plausible
        ]
    },
    # Test case: 7-digit water meter, no history
    {
        "image": "water_meter_1.jpg",
        "expected_digits": 7,
        "last_reading": None,
        "ocr_texts": [
            {"text": "0087234", "confidence": 0.89},  # Correct 7 digits
            {"text": "87234", "confidence": 0.94},    # Wrong (5 digits)
            {"text": "08723456", "confidence": 0.86}, # Wrong (8 digits)
        ]
    },
]


def filter_ocr_results(ocr_texts, expected_digits, last_reading=None):
    """
    Simulate the Swift OCR filtering logic.

    1. STRICT: Only keep readings with exact digit count
    2. PLAUSIBILITY: Filter based on last reading if available
    """
    print(f"\n--- Filtering for {expected_digits} digits ---")
    if last_reading:
        print(f"    Last reading: {last_reading}")

    # Step 1: Filter to exact digit count
    digit_readings = []
    for result in ocr_texts:
        digits_only = re.sub(r'[^0-9]', '', result["text"])

        if len(digits_only) != expected_digits:
            print(f"  REJECTED (digit count): '{digits_only}' has {len(digits_only)} digits, need {expected_digits}")
            continue

        digit_readings.append({
            "text": result["text"],
            "digits_only": digits_only,
            "confidence": result["confidence"]
        })
        print(f"  ACCEPTED (digit count): '{digits_only}'")

    print(f"\n  After digit filter: {len(digit_readings)} candidates")

    # Step 2: Plausibility filter if we have history
    plausible_readings = digit_readings
    if last_reading and last_reading > 0:
        min_acceptable = last_reading * 0.95
        max_acceptable = last_reading * 1.5

        plausible_readings = []
        for reading in digit_readings:
            try:
                numeric_value = float(reading["digits_only"])
            except ValueError:
                plausible_readings.append(reading)
                continue

            if min_acceptable <= numeric_value <= max_acceptable:
                plausible_readings.append(reading)
                print(f"  PLAUSIBLE: '{reading['digits_only']}' = {numeric_value} (range: {min_acceptable:.0f}-{max_acceptable:.0f})")
            else:
                print(f"  IMPLAUSIBLE: '{reading['digits_only']}' = {numeric_value} (outside {min_acceptable:.0f}-{max_acceptable:.0f})")

        print(f"\n  After plausibility filter: {len(plausible_readings)} candidates")

        # If everything filtered out, fall back to digit-correct readings
        if not plausible_readings and digit_readings:
            print("  WARNING: All filtered as implausible, showing all digit-correct candidates")
            plausible_readings = digit_readings

    # Sort by confidence
    sorted_readings = sorted(plausible_readings, key=lambda x: x["confidence"], reverse=True)

    return sorted_readings


def run_tests():
    """Run all test cases and report results."""
    print("=" * 60)
    print("MeterScience OCR Filter Test Harness")
    print("=" * 60)

    for i, test_case in enumerate(SAMPLE_OCR_RESULTS):
        print(f"\n\nTEST CASE {i+1}: {test_case['image']}")
        print("-" * 40)
        print(f"Expected digits: {test_case['expected_digits']}")
        print(f"Last reading: {test_case['last_reading']}")
        print(f"OCR returned {len(test_case['ocr_texts'])} text regions")

        results = filter_ocr_results(
            test_case["ocr_texts"],
            test_case["expected_digits"],
            test_case["last_reading"]
        )

        print(f"\n  FINAL RESULTS ({len(results)} candidates):")
        for j, r in enumerate(results[:5]):
            marker = ">>> BEST" if j == 0 else "   "
            print(f"    {marker} '{r['digits_only']}' (confidence: {r['confidence']:.2f})")

        if not results:
            print("    (No valid readings - would prompt for manual entry)")

    print("\n" + "=" * 60)
    print("Tests complete!")
    print("=" * 60)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Test with specific image
        image_path = sys.argv[1]
        print(f"Testing with image: {image_path}")
        print("(Vision framework not available in Python - use iOS simulator)")
    else:
        # Run simulated tests
        run_tests()
