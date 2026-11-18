"""Turn the CDC fixed-width file (ed2022) into a readable CSV (ed_visits.csv).

Source: CDC / NCHS, National Hospital Ambulatory Medical Care Survey (NHAMCS),
2022 Emergency Department public use file.
  https://www.cdc.gov/nchs/nhamcs/about/index.html
  https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NHAMCS/ed2022.zip
Column positions come from the CDC's own SAS input statement (ed22inp.txt) and the
2022 documentation (doc22-ed-508.pdf).

Usage:  python make_dataset.py ed2022 ed_visits.csv
"""
import sys
import pandas as pd

# (new name, CDC name, start column (1-based), length)
FIELDS = [
    ("month", "VMONTH", 1, 2),
    ("day_code", "VDAYR", 3, 1),
    ("arrival_time", "ARRTIME", 4, 4),      # military time, e.g. 1430
    ("wait_minutes", "WAITTIME", 8, 4),     # minutes until a doctor/nurse practitioner/PA sees the patient
    ("visit_minutes", "LOV", 12, 4),        # length of visit: arrival to leaving, in minutes
    ("age", "AGE", 16, 3),
    ("sex_code", "SEX", 25, 1),
    ("ambulance_code", "ARREMS", 33, 2),
    ("insurance_code", "PAYTYPER", 46, 2),
    ("urgency_code", "IMMEDR", 67, 2),      # triage level 1-5
    ("injury_code", "INJURY", 100, 2),
    ("region_code", "REGION", 628, 1),
    ("metro_code", "MSA", 629, 1),
]

DAYS = {1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"}
SEX = {1: "Female", 2: "Male"}
YESNO = {1: "Yes", 2: "No"}
URGENCY = {1: "Immediate", 2: "Emergent", 3: "Urgent", 4: "Semi-urgent", 5: "Non-urgent"}
# 1 private, 2 Medicare, 3 Medicaid, 5 self-pay; 4 workers' comp, 6 no charge, 7 other -> "Other"
INSURANCE = {1: "Private", 2: "Medicare", 3: "Medicaid", 5: "Self-pay", 4: "Other", 6: "Other", 7: "Other"}
REGION = {1: "Northeast", 2: "Midwest", 3: "South", 4: "West"}


def main(src, out):
    rows = []
    with open(src, encoding="latin-1") as f:
        for line in f:
            rows.append({new: line[s - 1:s - 1 + n].strip() for new, _, s, n in FIELDS})
    df = pd.DataFrame(rows).apply(pd.to_numeric, errors="coerce")
    print("visits in the CDC file:", len(df))

    # keep only visits where every answer we need is known
    ok = (
        (df.visit_minutes >= 0) & (df.visit_minutes <= 1440)   # CDC flags stays over 24 h separately
        & (df.arrival_time >= 0)
        & df.sex_code.isin(SEX)
        & df.ambulance_code.isin(YESNO)
        & df.urgency_code.isin(URGENCY)
        & df.injury_code.isin([0, 1])
        & df.insurance_code.isin(INSURANCE)
    )
    df = df[ok].copy()
    print("visits kept after removing blanks / unknowns / stays over 24 h:", len(df))

    clean = pd.DataFrame({
        "age": df.age.astype(int),
        "sex": df.sex_code.map(SEX),
        "arrival_hour": (df.arrival_time // 100).astype(int),
        "day_of_week": df.day_code.map(DAYS),
        "arrived_by_ambulance": df.ambulance_code.map(YESNO),
        "urgency": df.urgency_code.map(URGENCY),
        "injury_related": df.injury_code.map({0: "No", 1: "Yes"}),
        "insurance": df.insurance_code.map(INSURANCE),
        # columns below are NOT used by the app; the notebook explains why they are dropped
        "month": df.month.astype(int),
        "region": df.region_code.map(REGION),
        "metro_area": df.metro_code.map({1: "Yes", 2: "No"}),
        "wait_minutes": df.wait_minutes.where(df.wait_minutes >= 0),   # blank/-7/-9 -> missing
        "visit_minutes": df.visit_minutes.astype(int),                 # TARGET
    })
    clean.to_csv(out, index=False)
    print("saved", out, clean.shape)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
