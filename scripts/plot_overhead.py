import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

df = pd.read_csv('results/overhead_data.csv')
bl = df[df['Pipeline']=='baseline']['DureeSeconds']
zt = df[df['Pipeline']=='ztsc']['DureeSeconds']

fig, ax = plt.subplots(figsize=(10, 5))
ax.boxplot([bl, zt], labels=['Baseline', 'ZTSC'], patch_artist=True,
            boxprops=dict(facecolor='#CBD5E1'),
            medianprops=dict(color='#DC2626', linewidth=2))
ax.set_ylabel('Duree (secondes)')
ax.set_title('Distribution des temps d execution - 30 runs par pipeline')
ax.grid(axis='y', alpha=0.3)
plt.savefig('results/overhead_boxplot.png', dpi=200, bbox_inches='tight')
print('Graphique sauve dans results/overhead_boxplot.png')
