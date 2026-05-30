#!/usr/bin/env python3
"""
Genera LUTs .cube estilo "Apple" afinadas para la Logitech MX Brio.

La MX Brio tira a frío/azul y a una saturación "digital". Esta LUT:
  1. Calienta el balance de blancos (gana rojo, baja azul).
  2. Levanta sombras y aclara medios suavemente (look filmico/Apple, menos
     contraste duro).
  3. Saturación selectiva que PRESERVA luminancia y PROTEGE la piel:
     los tonos cálidos (piel) ganan un poco; los azules se calman.

Uso:
    python3 generate_lut.py                      # genera las variantes por defecto
Edita los parámetros en VARIANTS (abajo) para crear tu propio look.
"""

import numpy as np
import os

SIZE = 33  # puntos por eje (33 = estándar profesional)

def transform(rgb, *, warm, lift, mid_gamma, sat_base, skin_boost,
              cool_calm, intensity):
    """rgb: array (...,3) en 0..1. Devuelve el rgb procesado."""
    orig = rgb.copy()
    r, g, b = rgb[..., 0].copy(), rgb[..., 1].copy(), rgb[..., 2].copy()

    # 1) Balance de blancos cálido
    r = r * (1.0 + warm)
    b = b * (1.0 - warm)

    # 2) Tono: levantar sombras + aclarar medios (rolloff suave)
    def tone(x):
        x = lift + (1.0 - lift) * x          # sube negros
        x = np.clip(x, 0.0, 1.0) ** mid_gamma  # gamma<1 aclara medios
        return x
    r, g, b = tone(r), tone(g), tone(b)

    out = np.stack([r, g, b], axis=-1)
    out = np.clip(out, 0.0, 1.0)

    # 3) Saturación selectiva que preserva luminancia
    Y = 0.2126 * out[..., 0] + 0.7152 * out[..., 1] + 0.0722 * out[..., 2]
    warm_amt = np.clip(out[..., 0] - out[..., 2], 0.0, 1.0)   # qué tan cálido (piel)
    cool_amt = np.clip(out[..., 2] - out[..., 0], 0.0, 1.0)   # qué tan azul
    sat = sat_base + skin_boost * warm_amt - cool_calm * cool_amt
    sat = sat[..., None]
    Yb = Y[..., None]
    out = Yb + sat * (out - Yb)
    out = np.clip(out, 0.0, 1.0)

    # Mezcla con el original según intensidad
    return np.clip(orig * (1.0 - intensity) + out * intensity, 0.0, 1.0)


def write_cube(path, title, params):
    # Malla identidad: el índice más rápido es R (orden estándar .cube)
    idx = np.arange(SIZE) / (SIZE - 1)
    b, g, r = np.meshgrid(idx, idx, idx, indexing="ij")
    grid = np.stack([r, g, b], axis=-1).reshape(-1, 3)

    out = transform(grid, **params)

    with open(path, "w") as f:
        f.write(f'TITLE "{title}"\n')
        f.write(f"LUT_3D_SIZE {SIZE}\n")
        f.write("DOMAIN_MIN 0.0 0.0 0.0\n")
        f.write("DOMAIN_MAX 1.0 1.0 1.0\n")
        for px in out:
            f.write(f"{px[0]:.6f} {px[1]:.6f} {px[2]:.6f}\n")
    print(f"✓ {path}")


# Look base "Apple" + variantes de intensidad
BASE = dict(warm=0.05, lift=0.018, mid_gamma=0.96,
            sat_base=0.95, skin_boost=0.12, cool_calm=0.06)

VARIANTS = {
    "MX Brio - Apple":         dict(BASE, intensity=1.0),
    "MX Brio - Apple (suave)": dict(BASE, intensity=0.6),
    "MX Brio - Apple (fuerte)": dict(warm=0.07, lift=0.024, mid_gamma=0.94,
                                     sat_base=0.94, skin_boost=0.16,
                                     cool_calm=0.09, intensity=1.0),
}

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for title, params in VARIANTS.items():
        fname = title.lower().replace(" ", "-").replace("(", "").replace(")", "")
        write_cube(os.path.join(here, f"{fname}.cube"), title, params)
    print("\nListo. Carga el .cube en OBS → filtro 'Aplicar LUT'.")
