import joblib
import pandas as pd

# Charger le modèle et les données
clf = joblib.load('dataset/ztsc_model.pkl')
df = pd.read_csv('dataset/features.csv')

# Tester les deux premiers paquets du dataset
test_samples = df.head(2) 

for i, row in test_samples.iterrows():
    features = row[['files', 'install_scripts', 'net_calls', 'obfuscation', 'exec']].values.reshape(1, -1)
    prediction = clf.predict(features)[0]
    prob = clf.predict_proba(features)[0]
    
    status = "MALVEILLANT" if prediction == 1 else "LEGITIME"
    print(f"Fichier: {row['file']}")
    print(f"Prédiction: {status} (Confiance: {prob[prediction]:.2%})\n")
