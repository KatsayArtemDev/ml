import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import precision_recall_curve, average_precision_score, roc_curve, auc

np.random.seed(42)
n_samples = 10000
n_positive = 200

y_true = np.zeros(n_samples)
y_true[:n_positive] = 1
np.random.shuffle(y_true)

y_score_a = np.random.uniform(0, 0.6, n_samples)
y_score_a[y_true == 1] += np.random.uniform(0, 0.2, (y_true == 1).sum())

y_score_b = np.random.uniform(0.2, 0.6, n_samples)
y_score_b[y_true == 1] = np.random.uniform(0.3, 0.8, (y_true == 1).sum())

y_score_c = np.random.uniform(0.0, 0.6, n_samples)
y_score_c[y_true == 1] = np.random.uniform(0.5, 1.0, (y_true == 1).sum())

fpr_a, tpr_a, _ = roc_curve(y_true, y_score_a)
roc_auc_a = auc(fpr_a, tpr_a)

fpr_b, tpr_b, _ = roc_curve(y_true, y_score_b)
roc_auc_b = auc(fpr_b, tpr_b)

fpr_c, tpr_c, _ = roc_curve(y_true, y_score_c)
roc_auc_c = auc(fpr_c, tpr_c)

plt.figure(figsize=(8, 6))

plt.plot(fpr_a, tpr_a, label=f'Модель A (AUC = {roc_auc_a:.3f})', linewidth=2)
plt.plot(fpr_b, tpr_b, label=f'Модель B (AUC = {roc_auc_b:.3f})', linewidth=2)
plt.plot(fpr_c, tpr_c, label=f'Модель C (AUC = {roc_auc_c:.3f})', linewidth=2)
plt.plot([0, 1], [0, 1], 'k--', label='Случайный классификатор', linewidth=1)

plt.xlabel('False Positive Rate')
plt.ylabel('True Positive Rate')
plt.title('ROC-кривые для трёх моделей')
plt.legend(loc='lower right')
plt.grid(True, alpha=0.3)
plt.show()

print(f"ROC-AUC модели A: {roc_auc_a:.3f}")
print(f"ROC-AUC модели B: {roc_auc_b:.3f}")
print(f"ROC-AUC модели C: {roc_auc_c:.3f}")

precision_a, recall_a, _ = precision_recall_curve(y_true, y_score_a)
pr_auc_a = average_precision_score(y_true, y_score_a)

precision_b, recall_b, _ = precision_recall_curve(y_true, y_score_b)
pr_auc_b = average_precision_score(y_true, y_score_b)

precision_c, recall_c, _ = precision_recall_curve(y_true, y_score_c)
pr_auc_c = average_precision_score(y_true, y_score_c)

plt.figure(figsize=(8, 6))

plt.plot(recall_a, precision_a, label=f'Модель A (AP = {pr_auc_a:.3f})', linewidth=2)
plt.plot(recall_b, precision_b, label=f'Модель B (AP = {pr_auc_b:.3f})', linewidth=2)
plt.plot(recall_c, precision_c, label=f'Модель C (AP = {pr_auc_c:.3f})', linewidth=2)

baseline = sum(y_true) / len(y_true)
plt.axhline(y=baseline, color='k', linestyle='--', 
            label=f'Случайный классификатор (AP = {baseline:.3f})', linewidth=1)

plt.xlabel('Recall')
plt.ylabel('Precision')
plt.title('PR-кривые для трёх моделей')
plt.legend(loc='upper right')
plt.grid(True, alpha=0.3)
plt.xlim([0, 1])
plt.ylim([0, 1])
plt.show()

print(f"PR-AUC модели A: {pr_auc_a:.2f}")
print(f"PR-AUC модели B: {pr_auc_b:.2f}")
print(f"PR-AUC модели C: {pr_auc_c:.2f}")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

models = ['Модель A', 'Модель B', 'Модель C']
roc_scores = [roc_auc_a, roc_auc_b, roc_auc_c]
pr_scores = [pr_auc_a, pr_auc_b, pr_auc_c]

bars1 = ax1.bar(models, roc_scores, color=['red', 'yellow', 'green'])
ax1.axhline(y=0.5, color='black', linestyle='--', alpha=0.5, label='Случайный')
ax1.set_ylabel('ROC-AUC')
ax1.set_title('ROC-AUC: все модели выглядят прилично')
ax1.set_ylim([0, 1])
ax1.legend()

for bar, score in zip(bars1, roc_scores):
    height = bar.get_height()
    ax1.text(bar.get_x() + bar.get_width()/2., height + 0.01,
             f'{score:.3f}', ha='center', va='bottom')

bars2 = ax2.bar(models, pr_scores, color=['red', 'yellow', 'green'])
ax2.axhline(y=baseline, color='black', linestyle='--', alpha=0.5, label='Случайный')
ax2.set_ylabel('PR-AUC')
ax2.set_title('PR-AUC: видна реальная разница в качестве')
ax2.set_ylim([0, 1])
ax2.legend()

for bar, score in zip(bars2, pr_scores):
    height = bar.get_height()
    ax2.text(bar.get_x() + bar.get_width()/2., height + 0.01,
             f'{score:.3f}', ha='center', va='bottom')

plt.tight_layout()
plt.show()