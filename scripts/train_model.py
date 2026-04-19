import pandas as pd
import json
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, confusion_matrix
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import joblib

# Charger les données
df = pd.read_csv('dataset/features.csv')
X = df[['files', 'install_scripts', 'net_calls', 'obfuscation', 'exec']]
y = df['label']

# Split 70% train / 30% test
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)

# Entraînement
clf = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
clf.fit(X_train, y_train)

# Évaluation
y_pred = clf.predict(X_test)
metrics = {
    "accuracy": accuracy_score(y_test, y_pred),
    "precision": precision_score(y_test, y_pred),
    "recall": recall_score(y_test, y_pred),
    "f1_score": f1_score(y_test, y_pred)
}

print("\n=== RESULTATS ML ===")
for k, v in metrics.items(): print(f"{k.capitalize()}: {v:.2f}")

# Sauvegardes
with open('results/ml_metrics.json', 'w') as f: json.dump(metrics, f, indent=2)
joblib.dump(clf, 'dataset/ztsc_model.pkl')

# Matrice de confusion
cm = confusion_matrix(y_test, y_pred)
plt.figure(figsize=(5,4))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=['Légitime', 'Malveillant'], yticklabels=['Légitime', 'Malveillant'])
plt.ylabel('Vrai Label')
plt.xlabel('Prédiction')
plt.title('Matrice de Confusion - Random Forest')
plt.savefig('results/confusion_matrix.png', dpi=200, bbox_inches='tight')

print("\nModèle sauvegardé : dataset/ztsc_model.pkl")
print("Graphique sauvegardé : results/confusion_matrix.png")
