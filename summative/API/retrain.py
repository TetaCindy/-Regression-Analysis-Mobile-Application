"""Model-update logic used by the /retrain route in prediction.py."""
import copy

import pandas as pd
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_squared_error


def update_model(current, new_X, new_y, train_df, features, target):
    """Return (updated_model, method_text, mse_before).

    mse_before: how well the CURRENT model predicts the new rows before learning from them.
    SGDRegressor: keep training the saved model on the new rows only (partial_fit).
    Any other model: refit on the original rows plus the new rows.
    """
    mse_before = float(mean_squared_error(new_y, current.predict(new_X)))

    if isinstance(current.named_steps["model"], SGDRegressor):
        updated = copy.deepcopy(current)
        updated.named_steps["model"].partial_fit(updated.named_steps["prep"].transform(new_X), new_y)
        method = "SGDRegressor: continued training with partial_fit on the new rows"
    else:
        new_rows = new_X.assign(**{target: new_y})
        combined = pd.concat([train_df, new_rows], ignore_index=True)
        updated = clone(current).fit(combined[features], combined[target])
        updated.training_rows_ = combined
        method = "refit on the original data plus the new rows"

    return updated, method, mse_before