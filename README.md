# Garment Worker Productivity Prediction

- **Mission:** Help workers in target-driven jobs through fair, evidence-based daily targets.
- **Problem:** Targets set without evidence push teams into overtime and burnout.
- **Solution:** A regression model predicts team productivity, served by an API and a mobile app.
- **Users:** Supervisors who check whether a target is realistic before a shift.

## Dataset

*Productivity Prediction of Garment Employees*, UCI Machine Learning Repository (CC BY 4.0):
https://archive.ics.uci.edu/dataset/597/productivity+prediction+of+garment+employees

It holds 1,197 records of daily team production data from a garment factory (January to March 2015) with 14 features, both categorical (department, day, quarter, team) and numeric (targeted productivity, standard minute value, work in progress, overtime, incentive, idle time, idle workers, style changes, number of workers).
The target is `actual_productivity`, a continuous value between 0 and 1.

## Public API (Swagger UI)

https://YOUR-SERVICE.onrender.com/docs

The service runs on Render's free plan. It sleeps after 15 minutes without traffic, so the first request can take up to a minute.

## Video demo

https://www.youtube.com/watch?v=YOUR_VIDEO_ID

## Run the mobile app

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install) and an Android emulator, an iOS simulator or a phone. The app does not run as a web app.

1. Clone the repository and open the app folder:
   ```bash
   git clone https://github.com/TetaCindy/-Regression-Analysis-Mobile-Application.git
   cd linear_regression_model/summative/FlutterApp
   ```
2. Generate the platform folders. This keeps the existing `lib/main.dart` and `pubspec.yaml`:
   ```bash
   flutter create --project-name garment_productivity_app .
   ```
3. Install the packages:
   ```bash
   flutter pub get
   ```
4. Android only: in `android/app/src/main/AndroidManifest.xml`, add this line inside the `<manifest>` tag:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
5. Check that `apiBaseUrl` in `lib/main.dart` is the public API address from the section above.
6. Start an emulator or connect a phone, then run:
   ```bash
   flutter devices
   flutter run
   ```
7. Fill in all 11 fields and press **Predict**. The predicted productivity appears under the button. An empty field, text in a number field or an out-of-range value shows an error message in the same place.

To use an API running on your own computer from the Android emulator, add `android:usesCleartextTraffic="true"` to the `<application>` tag and run:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## API inputs

`POST /predict` takes these 11 fields. Types and ranges are enforced with Pydantic, and any other value returns a validation error instead of a prediction.

| Field | Type | Allowed values |
|---|---|---|
| `department` | text | `sewing`, `finishing` |
| `day` | text | `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Saturday`, `Sunday` |
| `team` | integer | 1 to 12 |
| `targeted_productivity` | float | 0 to 1 |
| `smv` | float | 0 to 100 |
| `over_time` | integer | 0 to 30000 |
| `incentive` | integer | 0 to 5000 |
| `idle_time` | float | 0 to 500 |
| `idle_men` | integer | 0 to 100 |
| `no_of_style_change` | integer | 0 to 5 |
| `no_of_workers` | float | 1 to 100 |

`POST /retrain` takes a CSV file with the same columns as the training data plus `actual_productivity`. The upload triggers retraining immediately and `/predict` uses the updated model without a redeploy. A model retrained on Render is kept in memory only, so it is lost when the free service restarts.

## Repository layout

```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml
    ├── uv.lock
    ├── linear_regression/
    │   └── multivariate.ipynb      # exploration, four models, comparison, saving the best
    ├── API/
    │   ├── prediction.py           # FastAPI app: /predict, /retrain, /docs
    │   ├── requirements.txt        # used by Render
    │   └── best_model.pkl          # saved pipeline created by the notebook
    └── FlutterApp/                 # one-page mobile app
```

## Run the notebook and the API locally

```bash
cd summative
uv sync
uv run jupyter lab
```

Place `garments_worker_productivity.csv` (downloaded from the dataset link) next to the notebook and run all cells. The notebook saves the model to `API/best_model.pkl`. To start the API:

```bash
cd API
uv run uvicorn prediction:app --reload
```

The Swagger UI is then at http://127.0.0.1:8000/docs.

## Deploy on Render

- Root directory: `summative/API`
- Build command: `pip install -r requirements.txt`
- Start command: `uvicorn prediction:app --host 0.0.0.0 --port $PORT`
- Environment variable: `PYTHON_VERSION` = `3.12.3`
- `requirements.txt` is exported from `summative/` with:
  `uv export --format requirements.txt --no-hashes --no-dev -o API/requirements.txt`
