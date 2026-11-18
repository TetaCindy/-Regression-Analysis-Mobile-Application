# Hospital Visit Time Predictor

## 1. Mission and problem

My mission is to help hospitals in Rwanda work better for patients, so nobody has to wait all day without knowing what is going on.
This project predicts how long a patient will spend in the emergency department, from arrival to leaving, using details known when they arrive.
A patient or a front-desk nurse can use the estimate to plan the day and prepare for busy times.

## 2. Dataset

**NHAMCS 2022 Emergency Department public use file**, from the US CDC / National Center for Health Statistics.
Link: https://www.cdc.gov/nchs/nhamcs/about/index.html (download: https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NHAMCS/ , file `ed2022.zip`).
It holds 16,025 real visit records sampled from US hospital emergency departments. `summative/linear_regression/make_dataset.py` converts the CDC fixed-width file into `ed_visits.csv` (8,488 visits where every needed answer is known and the stay was 24 hours or less).
The data is US emergency-department data used as a stand-in for the visit-time problem; it is not African hospital data.

## 3. Public API (Swagger UI)

https://er-visit-time-api.onrender.com/docs

(Free Render plan: the first request after 15 minutes of silence can take up to a minute.)

## 4. Video demo

YOUR YOUTUBE LINK

## 5. Run the mobile app

You need Flutter installed (`flutter doctor` shows no errors) and an Android emulator or a phone.

1. Open a terminal in `summative/FlutterApp`.
2. Install the packages:
   ```
   flutter pub get
   ```
   The Android, iOS and web folders are already in the repo, and the internet permission is already in `android/app/src/main/AndroidManifest.xml`.
3. The app calls the deployed API. The address is set in `lib/main.dart` (`defaultValue` of `apiBaseUrl`); you can also pass it when you run.
4. Start an emulator (Android Studio, Device Manager) or plug in a phone, then:
   ```
   flutter devices
   flutter run
   ```
   To test against the API running on your own computer (Android emulator only):
   ```
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```
   That local test needs `android:usesCleartextTraffic="true"` inside the `<application` tag of the manifest. Remove it again for the final version that talks to Render.

How to use the app: type the age and arrival hour, tap the other six fields to choose a value, then tap **Predict**. A missing, non-whole-number or out-of-range value shows the API's error message in the result box.

---

## Project layout

```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml
    ├── uv.lock
    ├── linear_regression/
    │   ├── multivariate.ipynb
    │   ├── ed_visits.csv         (the cleaned dataset)
    │   └── make_dataset.py       (how ed_visits.csv was made from the CDC file)
    ├── API/
    │   ├── prediction.py
    │   ├── requirements.txt
    │   └── best_model.pkl        (the saved pipeline; it also carries the training rows that /retrain needs)
    └── FlutterApp/               (lib/main.dart, pubspec.yaml and the Android/iOS/web folders)
```

## Run the notebook and the API

```
cd summative
uv sync
cd linear_regression
uv run jupyter lab          # open multivariate.ipynb and run all cells (writes ../API/best_model.pkl)
cd ../API
uv run uvicorn prediction:app --reload     # http://127.0.0.1:8000/docs
```

## Deploy on Render

Web service from this GitHub repo. Root directory `summative/API`, build command `pip install -r requirements.txt`, start command `uvicorn prediction:app --host 0.0.0.0 --port $PORT`, environment variable `PYTHON_VERSION` = `3.12.3`.
`requirements.txt` was exported with `uv export --format requirements.txt --no-hashes --no-dev -o API/requirements.txt` (run from `summative`).
