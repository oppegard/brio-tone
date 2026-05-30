# Capa 2 — Look "Apple" en OBS con LUT (gratis)

Esta capa pone el **carácter de cine / tono de piel Apple** encima de tu MX Brio y lo
expone como **cámara virtual** para Zoom, Meet, Teams, FaceTime y grabación.

Funciona junto a **BrioTone** (capa 1): BrioTone corrige el sensor; OBS aplica la LUT.

## LUTs incluidas (formato `.cube`, nativo de OBS 32)

| Archivo | Para qué |
|---|---|
| `mx-brio---apple.cube` | Equilibrada. **Empieza por esta.** |
| `mx-brio---apple-suave.cube` | 60% de intensidad, más sutil. |
| `mx-brio---apple-fuerte.cube` | Más cálida y fílmica. |

¿Quieres afinarla? Edita los parámetros en `generate_lut.py` y corre `python3 generate_lut.py`.

## Configuración en OBS (una sola vez, ~6 clics)

1. Abre **OBS**. Si es la primera vez, salta el asistente (Cancelar).
2. En el panel **Fuentes** (Sources) → **＋** → **Dispositivo de captura de vídeo**
   (Video Capture Device) → *Crear nueva* → OK.
3. En **Dispositivo** elige **MX Brio**. Ajusta resolución (1920×1080) y FPS (30) si quieres.
   → OK.
4. Click derecho sobre la fuente **MX Brio** → **Filtros** (Filters).
5. Abajo izquierda, **＋** → **Aplicar LUT** (Apply LUT).
6. En **Ruta de LUT** (Path) → busca y selecciona
   `…/brio-tone/obs-apple-look/mx-brio---apple.cube`.
   - Verás el cambio en vivo. Baja **Cantidad** (Amount) si quieres menos efecto.
   → Cerrar.

### Activar la cámara virtual
7. Botón **Iniciar cámara virtual** (Start Virtual Camera), abajo derecha en *Controles*.
   - La **primera vez** macOS pedirá aprobar una extensión del sistema:
     Ajustes del Sistema → te aparece el permiso → Permitir. Reinicia la cámara virtual.
8. En **Zoom / Meet / Teams**, elige la cámara **"OBS Virtual Camera"**.

## Importante: no apiles dos veces el color

La LUT ya calienta y trabaja el color. Para no "doblar" el efecto:

- Con la LUT activa, pon **BrioTone** en preset **"Neutro"** (o incluso *Logitech default*),
  y deja que la **LUT** haga el grado de color. Si combinas el preset cálido de BrioTone
  *más* la LUT, puede quedar demasiado naranja.
- Regla simple: **un solo lugar manda el color**. Para videollamadas rápidas → solo BrioTone.
  Para grabar/stream con look pro → BrioTone en Neutro + OBS con LUT.
