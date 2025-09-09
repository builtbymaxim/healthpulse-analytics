"""Synthetic health data generation utilities.

This module provides a vectorised implementation for creating synthetic
patient health records. The previous version relied on triple nested loops
which became slow for large populations. The new approach leverages NumPy
arrays and pandas to generate all daily measurements for each patient in a
vectorised manner, significantly improving performance.
"""

from __future__ import annotations

from datetime import datetime, timedelta
import argparse
import random

import numpy as np
import pandas as pd


def _baseline_glucose(diabetes_type: int) -> float:
    """Return baseline glucose level based on diabetes type."""
    if diabetes_type == 0:  # Prediabetic
        level = np.random.normal(110, 10)
    elif diabetes_type == 1:  # Type 1
        level = np.random.normal(160, 30)
    else:  # Type 2
        level = np.random.normal(140, 25)
    return float(np.clip(level, 80, 300))


def generate_health_data(n_patients: int = 1000, days_per_patient: int = 90) -> pd.DataFrame:
    """Generate realistic synthetic health data for blood sugar prediction.

    The generation process is vectorised over daily measurements which keeps
    the function fast even for large numbers of patients.
    """

    np.random.seed(42)
    random.seed(42)

    records = []
    start_date = datetime(2024, 1, 1)
    measurement_hours = np.array([7, 12, 18, 22])

    for patient_id in range(1, n_patients + 1):
        # Patient baseline characteristics
        age = float(np.clip(np.random.normal(45, 15), 18, 80))
        diabetes_type = int(np.random.choice([0, 1, 2], p=[0.3, 0.1, 0.6]))
        baseline_glucose = _baseline_glucose(diabetes_type)

        # Generate timestamps for all measurements
        days = pd.date_range(start_date, periods=days_per_patient, freq="D")
        timestamps = np.repeat(days.values, 4) + np.tile(
            measurement_hours, days_per_patient
        ) * np.timedelta64(1, "h")

        n_measurements = len(timestamps)

        # Lifestyle factors
        sport_intensity = np.clip(np.random.exponential(2, n_measurements), 0, 10)
        meal_carbs = np.where(
            np.tile(measurement_hours, days_per_patient) != 22,
            np.clip(np.random.normal(45, 20, n_measurements), 0, None),
            np.random.exponential(10, n_measurements),
        )
        sleep_quality = np.clip(np.random.normal(7, 1.5, n_measurements), 1, 10)
        stress_level = np.clip(np.random.normal(5, 2, n_measurements), 1, 10)
        if diabetes_type > 0:
            medication_adherence = np.random.beta(8, 2, n_measurements)
        else:
            medication_adherence = np.zeros(n_measurements)

        # Calculate glucose deltas
        glucose_delta = (
            meal_carbs * 1.5
            - sport_intensity * 8
            - (sleep_quality - 5) * 3
            + (stress_level - 5) * 4
            - medication_adherence * 20
        )

        hour_effect = np.select(
            [
                np.tile(measurement_hours, days_per_patient) == 7,
                np.tile(measurement_hours, days_per_patient) == 22,
            ],
            [15, -10],
            default=0,
        )
        glucose_delta += hour_effect
        glucose_delta += np.random.normal(0, 15, n_measurements)

        glucose_level = np.clip(baseline_glucose + glucose_delta, 50, 400)
        glucose_level = np.round(glucose_level, 1)
        risk_flag = (glucose_level > 180).astype(int)

        df_patient = pd.DataFrame(
            {
                "patient_id": patient_id,
                "timestamp": timestamps,
                "age": np.round(age, 1),
                "diabetes_type": diabetes_type,
                "glucose_level": glucose_level,
                "sport_intensity": np.round(sport_intensity, 1),
                "meal_carbs": np.round(meal_carbs, 1),
                "sleep_quality": np.round(sleep_quality, 1),
                "stress_level": np.round(stress_level, 1),
                "medication_adherence": np.round(medication_adherence, 2),
                "risk_flag": risk_flag,
            }
        )

        records.append(df_patient)

    return pd.concat(records, ignore_index=True)


def main():
    """CLI entry-point to generate and save synthetic data."""

    parser = argparse.ArgumentParser(description="Generate synthetic health data")
    parser.add_argument("--patients", type=int, default=1000, help="Number of patients")
    parser.add_argument("--days", type=int, default=90, help="Days per patient")
    parser.add_argument(
        "--output", type=str, default="health_data.csv", help="Output CSV file"
    )
    args = parser.parse_args()

    df = generate_health_data(args.patients, args.days)
    df.to_csv(args.output, index=False)
    print(f"Saved synthetic data to {args.output}")


if __name__ == "__main__":
    main()
