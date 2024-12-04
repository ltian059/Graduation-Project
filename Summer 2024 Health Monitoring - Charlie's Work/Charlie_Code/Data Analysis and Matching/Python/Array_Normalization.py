import numpy as np

def Array_Normalization(Array):
    normA = Array - np.min(Array)
    normA = normA / np.max(normA)
    return normA
