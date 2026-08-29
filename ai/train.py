import os
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import tensorflow as tf
import cv2
import numpy as np
import random
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
import matplotlib.pyplot as plt

# ================================
# SETUP GPU MEMORY GROWTH
# ================================
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    for gpu in gpus:
        tf.config.experimental.set_memory_growth(gpu, True)
    print(f"✅ GPU terdeteksi: {len(gpus)} device")
else:
    print("⚠️  GPU tidak terdeteksi, training akan jalan di CPU")

# ================================
# KONFIGURASI
# ================================
DATASET_DIR   = "dataset"
MODEL_DIR     = "model"
MODEL_PATH    = os.path.join(MODEL_DIR, "model_sampah.h5")
IMG_SIZE      = (224, 224)
BATCH_SIZE    = 16
EPOCHS        = 30
NUM_CLASSES   = 2

os.makedirs(MODEL_DIR, exist_ok=True)

# ================================
# CUSTOM AUGMENTATION: RANDOM BLUR
# ================================
def random_blur(img):
    """
    Menambahkan blur acak ke gambar saat training,
    supaya model lebih tahan terhadap foto buram dari webcam.
    img: array gambar dengan range 0-255 (sesuai default ImageDataGenerator)
    """
    if random.random() < 0.5:
        kernel_size = random.choice([3, 5, 7])
        img = cv2.GaussianBlur(img, (kernel_size, kernel_size), 0)
    return img


# ================================
# DATA AUGMENTATION
# ================================
train_datagen = ImageDataGenerator(
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest',
    preprocessing_function=random_blur
)

val_datagen = ImageDataGenerator()

train_generator = train_datagen.flow_from_directory(
    os.path.join(DATASET_DIR, "train"),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

val_generator = val_datagen.flow_from_directory(
    os.path.join(DATASET_DIR, "val"),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical'
)

print(f"\nKelas terdeteksi: {train_generator.class_indices}")


# ================================
# MODEL EfficientNetB0
# ================================
base_model = EfficientNetB0(
    weights='imagenet',
    include_top=False,
    input_shape=(224, 224, 3)
)

base_model.trainable = False

x = base_model.output
x = GlobalAveragePooling2D()(x)
x = Dropout(0.3)(x)
x = Dense(128, activation='relu')(x)
x = Dropout(0.2)(x)
output = Dense(NUM_CLASSES, activation='softmax')(x)

model = Model(inputs=base_model.input, outputs=output)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
    loss='categorical_crossentropy',
    metrics=['accuracy'],
    jit_compile=False
)

model.summary()

# ================================
# CALLBACKS
# ================================
callbacks = [
    ModelCheckpoint(
        MODEL_PATH,
        monitor='val_loss',
        mode='min',
        save_best_only=True,
        verbose=1
    ),
    EarlyStopping(
        monitor='val_loss',
        mode='min',
        patience=7,
        restore_best_weights=True,
        verbose=1
    ),
    ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=3,
        verbose=1
    )
]

# ================================
# TRAINING
# ================================
print("\n🚀 Memulai training...")
history = model.fit(
    train_generator,
    epochs=EPOCHS,
    validation_data=val_generator,
    callbacks=callbacks
)

# ================================
# SIMPAN CLASS INDICES
# ================================
import json
class_indices = train_generator.class_indices
with open(os.path.join(MODEL_DIR, "class_indices.json"), "w") as f:
    json.dump(class_indices, f)
print(f"\n✅ Class indices disimpan: {class_indices}")

# ================================
# PLOT HASIL TRAINING
# ================================
plt.style.use('seaborn-v0_8')

epochs_range = range(1, len(history.history['accuracy']) + 1)

# --- Plot 1: Accuracy ---
fig1, ax1 = plt.subplots(figsize=(8, 5))
ax1.plot(epochs_range, history.history['accuracy'],
         label='Train Accuracy', color='steelblue', linewidth=2)
ax1.plot(epochs_range, history.history['val_accuracy'],
         label='Validation Accuracy', color='darkorange', linewidth=2)
ax1.set_title('Accuracy over Epochs', fontsize=14, fontweight='bold', pad=12)
ax1.set_xlabel('Epochs', fontsize=12)
ax1.set_ylabel('Accuracy', fontsize=12)
ax1.legend(fontsize=11)
ax1.set_ylim([0, 1.05])
ax1.grid(True, linestyle='--', alpha=0.6)
fig1.tight_layout()
acc_path = os.path.join(MODEL_DIR, "accuracy_plot.png")
fig1.savefig(acc_path, dpi=150, bbox_inches='tight')
print(f"✅ Plot accuracy disimpan: {acc_path}")
plt.close(fig1)

# --- Plot 2: Loss ---
fig2, ax2 = plt.subplots(figsize=(8, 5))
ax2.plot(epochs_range, history.history['loss'],
         label='Train Loss', color='steelblue', linewidth=2)
ax2.plot(epochs_range, history.history['val_loss'],
         label='Validation Loss', color='darkorange', linewidth=2)
ax2.set_title('Loss over Epochs', fontsize=14, fontweight='bold', pad=12)
ax2.set_xlabel('Epochs', fontsize=12)
ax2.set_ylabel('Loss', fontsize=12)
ax2.legend(fontsize=11)
ax2.grid(True, linestyle='--', alpha=0.6)
fig2.tight_layout()
loss_path = os.path.join(MODEL_DIR, "loss_plot.png")
fig2.savefig(loss_path, dpi=150, bbox_inches='tight')
print(f"✅ Plot loss disimpan: {loss_path}")
plt.close(fig2)

# ================================
# CONFUSION MATRIX & CLASSIFICATION REPORT
# [FIX] Pakai generator terpisah dengan shuffle=False
# agar urutan prediksi sesuai dengan label aslinya
# ================================
from sklearn.metrics import confusion_matrix, classification_report, ConfusionMatrixDisplay

print("\n📊 Menghitung confusion matrix...")

pred_generator = val_datagen.flow_from_directory(
    os.path.join(DATASET_DIR, "val"),
    target_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    shuffle=False
)

y_pred_probs = model.predict(pred_generator, verbose=1)
y_pred = np.argmax(y_pred_probs, axis=1)
y_true = pred_generator.classes
class_names = list(pred_generator.class_indices.keys())

# --- Confusion Matrix ---
cm = confusion_matrix(y_true, y_pred)
fig3, ax3 = plt.subplots(figsize=(6, 5))
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=class_names)
disp.plot(ax=ax3, colorbar=False, cmap='Blues')
ax3.set_title('Confusion Matrix', fontsize=14, fontweight='bold', pad=12)
fig3.tight_layout()
cm_path = os.path.join(MODEL_DIR, "confusion_matrix.png")
fig3.savefig(cm_path, dpi=150, bbox_inches='tight')
print(f"✅ Confusion matrix disimpan: {cm_path}")
plt.close(fig3)

# --- Classification Report ---
report = classification_report(y_true, y_pred, target_names=class_names)
print("\n📋 Classification Report:")
print(report)

report_path = os.path.join(MODEL_DIR, "classification_report.txt")
with open(report_path, "w") as f:
    f.write(report)
print(f"✅ Classification report disimpan: {report_path}")

print("\n✅ Training selesai! Model tersimpan di:", MODEL_PATH)
print(f"📊 Plot tersimpan di folder: {MODEL_DIR}/")