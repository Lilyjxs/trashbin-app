import os
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import tensorflow as tf
import numpy as np
import json
from PIL import Image

# ================================
# KONFIGURASI
# ================================
# Path absolut berdasarkan lokasi file classify.py itu sendiri
BASE_DIR         = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH       = os.path.join(BASE_DIR, "model", "model_sampah.h5")
CLASS_INDEX_PATH = os.path.join(BASE_DIR, "model", "class_indices.json")
IMG_SIZE         = (224, 224)
CONFIDENCE_MIN   = 0.7  # minimum confidence, di bawah ini = tidak diketahui

# ================================
# LOAD MODEL & CLASS INDICES
# ================================
model = tf.keras.models.load_model(MODEL_PATH)

with open(CLASS_INDEX_PATH, "r") as f:
    class_indices = json.load(f)

# Balik mapping: {0: 'botol_plastik', 1: 'kaleng'}
index_to_class = {v: k for k, v in class_indices.items()}

def classify_image(image_path):
    """
    Input  : path gambar hasil capture
    Output : (label, confidence)
    """
    img = Image.open(image_path).convert("RGB")
    img = img.resize(IMG_SIZE)
    img_array = np.array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)

    predictions = model.predict(img_array, verbose=0)
    confidence  = float(np.max(predictions))
    class_idx   = int(np.argmax(predictions))
    label       = index_to_class[class_idx]

    if confidence < CONFIDENCE_MIN:
        return "tidak_diketahui", confidence

    return label, confidence


# ================================
# TEST STANDALONE (opsional)
# ================================
if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python classify.py <path_gambar>")
    else:
        path = sys.argv[1]
        label, conf = classify_image(path)
        print(f"Hasil    : {label}")
        print(f"Confidence: {conf:.2%}")