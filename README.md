# Hospital Visit Time Predictor

## 1. Mission and problem

> DRAFT: rewrite these lines in your own words (4 lines maximum).

My mission is a single system that links hospitals, so a patient booking a visit is told roughly how long it will take instead of waiting all day without knowing.
This project predicts the **total time a patient spends in the emergency department** (arrival to leaving, in minutes) from details known on arrival.
Patients and front-desk staff can use it to plan their day and manage crowding.

## 2. Dataset

**NHAMCS 2022 Emergency Department public use file**, from the US CDC / National Center for Health Statistics.
Link: https://www.cdc.gov/nchs/nhamcs/about/index.html (download: https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NHAMCS/ , file `ed2022.zip`).
It holds 16,025 real visit records sampled from US hospital emergency departments. `summative/linear_regression/make_dataset.py` converts the CDC fixed-width file into `ed_visits.csv` (8,488 visits where every needed answer is known and the stay was 24 hours or less).
The data is US emergency-department data used as a stand-in for the visit-time problem; it is not African hospital data.

## 3. Public API (Swagger UI)

https://YOUR-SERVICE.onrender.com/docs

(Free Render plan: the first request after 15 minutes of silence can take up to a minute.)

## 4. Video demo

YOUR YOUTUBE LINK

## 5. Run the mobile app

You need Flutter installed (`flutter doctor` shows no errors) and an Android emulator or a phone.

1. Open a terminal in `summative/FlutterApp`.
2. Generate the Android/iOS folders (this repo only contains the app code):
   ```
   flutter create --project-name hospital_visit_time .
   flutter pub get
   ```
   If `test/widget_test.dart` was created, delete it.
3. Allow internet access. In `android/app/src/main/AndroidManifest.xml`, add this line directly under the `<manifest ...>` line:
   ```
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
4. Put your Render address in `lib/main.dart` (`defaultValue` of `apiBaseUrl`), or pass it when you run.
5. Start an emulator (Android Studio, Device Manager) or plug in a phone, then:
   ```
   flutter devices
   flutter run
   ```
   To test against the API running on your own computer (Android emulator only):
   ```
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```
   For that local test only, also add `android:usesCleartextTraffic="true"` inside the `<application` tag of the manifest, and remove it afterwards.

How to use the app: type the age and arrival hour, tap the other six fields to choose a value, then tap **Predict**. A missing, non-whole-number or out-of-range value shows the API's error message in the result box.

---

## Project layout

```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml, uv.lock, .python-version
    ├── linear_regression/   multivariate.ipynb, ed_visits.csv, make_dataset.py, new_visits_sample.csv
    ├── API/                 prediction.py, requirements.txt, best_model.pkl, training_data.csv
    └── FlutterApp/          lib/main.dart, pubspec.yaml
```
`training_data.csv` holds the rows the model was trained on; `/retrain` needs them to refit models other than SGDRegressor.

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
`requirements.txt` was exported with `uv export --format requirements.txt --no-hashes --no-dev -o API/requirements.txt`.
