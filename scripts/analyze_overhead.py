import pandas as pd
import scipy.stats as stats
import json

df = pd.read_csv('results/overhead_data.csv')
bl = df[df['Pipeline']=='baseline']['DureeSeconds']
zt = df[df['Pipeline']=='ztsc']['DureeSeconds']

print('=== RESULTATS OVERHEAD ===')
print(f'Baseline : moyenne {bl.mean():.1f}s, mediane {bl.median():.1f}s, ecart-type {bl.std():.1f}s, n={len(bl)}')
print(f'ZTSC     : moyenne {zt.mean():.1f}s, mediane {zt.median():.1f}s, ecart-type {zt.std():.1f}s, n={len(zt)}')

overhead_moy = (zt.mean()/bl.mean() - 1) * 100
overhead_med = (zt.median()/bl.median() - 1) * 100
print(f'Overhead moyenne : {overhead_moy:+.1f} %')
print(f'Overhead mediane : {overhead_med:+.1f} %')

stat, pval = stats.mannwhitneyu(bl, zt, alternative='less')
print(f'Test Mann-Whitney U : statistic={stat:.1f}, p-value={pval:.2e}')
print(f'Hypothese nulle rejete : {"OUI" if pval < 0.05 else "NON"}')

# Sauver les resultats
results = {
'baseline_mean': float(bl.mean()), 'baseline_median': float(bl.median()), 'baseline_std': float(bl.std()),
'ztsc_mean': float(zt.mean()), 'ztsc_median': float(zt.median()), 'ztsc_std': float(zt.std()),
'overhead_mean_pct': float(overhead_moy), 'overhead_median_pct': float(overhead_med),
'pvalue': float(pval), 'n_baseline': int(len(bl)), 'n_ztsc': int(len(zt))
}
with open('results/overhead_stats.json', 'w') as f:
    json.dump(results, f, indent=2)
print('\nResultats sauvegardes dans results/overhead_stats.json')
