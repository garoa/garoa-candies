#!/usr/bin/env python3
"""Gera versões do logo do Garoa sem os pontinhos de chuva (e, opcionalmente, com um círculo).

Uso: python3 tools/make_logo_circle.py [Logo_Garoa.svg] [pasta_saida]

Saídas:
  garoa_circulo.svg      - visual (guarda-chuva preto + texto vazado [+ anel se BORDA])
  garoa_circulo_3d.svg   - para 3D: grupos separados id=umbrella / text [/ circle],
                           todos com preenchimento sólido (sem stroke)
"""
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
NS = {"s": SVG}

src = Path(sys.argv[1] if len(sys.argv) > 1 else "Logo_Garoa.svg")
out = Path(sys.argv[2] if len(sys.argv) > 2 else ".")

# Guarda-chuva sem os pontos (medido com inkscape --query-all)
UMB_X0, UMB_Y0, UMB_X1, UMB_Y1 = 125.80, 268.24, 449.13, 641.85
MARGIN = 14.0      # folga entre o guarda-chuva e o anel
RING = 10.6        # espessura do anel = espessura do cabo do guarda-chuva
BORDA = False      # desenha o anel em volta? (desligado a pedido)
DIAM_MM = 60.0     # diâmetro final do doce (o SVG sai em mm, pronto p/ CAD)
# Só "GAROA" (sem "HACKER CLUBE"), ampliado e centralizado no guarda-chuva.
TEXT_SCALE = 1.35  # ampliação do GAROA em torno do seu centro
TEXT_DY = 18.0     # deslocamento vertical do GAROA (unidades do SVG, + = desce)

root = ET.parse(src).getroot()
layer = root.find("s:g[@id='New_lettering_P_x26_B']", NS)

umbrella, text = [], []
# O 1º <g> da camada contém só os pontinhos de chuva: pulamos ele inteiro,
# mas conferimos que cada path ali é mesmo um ponto (~7x7 unidades).
dots_group = layer.find("s:g", NS)
for p in dots_group.iter(f"{{{SVG}}}path"):
    assert len(p.get("d")) < 200, "path grande demais para ser um ponto"
for p in layer.iter(f"{{{SVG}}}path"):
    if p in list(dots_group.iter(f"{{{SVG}}}path")):
        continue
    (umbrella if p.get("fill", "").upper() == "#1D1D1B" else text).append(p.get("d"))

assert len(umbrella) == 1, f"esperava 1 guarda-chuva, achei {len(umbrella)}"
assert len(text) == 16, f"esperava 16 letras, achei {len(text)} (GAROA + HACKERCLUBE)"


def first_y(d):
    return float(re.match(r"M\s*-?[\d.]+\s*,\s*(-?[\d.]+)", d).group(1))


# GAROA fica na linha de cima (y < 360); HACKER CLUBE fica embaixo
text = [d for d in text if first_y(d) < 360]
assert len(text) == 5, f"esperava 5 letras em GAROA, achei {len(text)}"
GAROA_CX, GAROA_CY = (216.6 + 358.9) / 2, (318.7 + 357.5) / 2  # bbox original
text_tf = (f' transform="translate({GAROA_CX:.3f},{GAROA_CY + TEXT_DY:.3f}) '
           f'scale({TEXT_SCALE}) translate({-GAROA_CX:.3f},{-GAROA_CY:.3f})"')

cx = (UMB_X0 + UMB_X1) / 2
cy = (UMB_Y0 + UMB_Y1) / 2
# raio que cobre os cantos do bbox (folgado) — na prática o guarda-chuva
# é mais estreito embaixo, então usamos o maior semi-eixo + margem
r_in = max(UMB_X1 - UMB_X0, UMB_Y1 - UMB_Y0) / 2 + MARGIN
r_out = r_in + RING
pad = 2
vb = (cx - r_out - pad, cy - r_out - pad, 2 * (r_out + pad), 2 * (r_out + pad))


def circle_d(r):
    return (f"M{cx - r:.3f},{cy:.3f}a{r:.3f},{r:.3f} 0 1,0 {2*r:.3f},0"
            f"a{r:.3f},{r:.3f} 0 1,0 {-2*r:.3f},0z")


ring_d = circle_d(r_out) + circle_d(r_in)  # anel via evenodd
# viewBox começa em 0,0 (o import do OpenSCAD erra com origem deslocada);
# o deslocamento vai num transform do grupo raiz.
head = (f'<svg xmlns="{SVG}" viewBox="0 0 {vb[2]:.3f} {vb[3]:.3f}" '
        f'width="{DIAM_MM}mm" height="{DIAM_MM}mm">\n'
        f'<g transform="translate({-vb[0]:.3f},{-vb[1]:.3f})">\n')
tail = "</g>\n</svg>\n"


def paths(ds, fill, extra=""):
    return "".join(f'    <path fill="{fill}"{extra} d="{d.split()[0] if False else " ".join(d.split())}"/>\n' for d in ds)


ring_g = (lambda fill: f'  <g id="circle"><path fill="{fill}" fill-rule="evenodd" d="{ring_d}"/></g>\n'
          if BORDA else "")
visual = (head + ring_g("#1D1D1B") +
          f'  <g id="umbrella">\n{paths(umbrella, "#1D1D1B")}  </g>\n'
          f'  <g id="text"{text_tf}>\n{paths(text, "#FFFFFF")}  </g>\n' + tail)
(out / "garoa_circulo.svg").write_text(visual)

# Versão 3D: tudo preto, cada parte num grupo próprio
solid = (head + ring_g("#000") +
         f'  <g id="umbrella">\n{paths(umbrella, "#000")}  </g>\n'
         f'  <g id="text"{text_tf}>\n{paths(text, "#000")}  </g>\n' + tail)
(out / "garoa_circulo_3d.svg").write_text(solid)

# Arquivos separados (para importadores que não aceitam id=)
parts = [("circle", f'<path fill-rule="evenodd" d="{ring_d}"/>\n')] if BORDA else []
for gid, body in parts + [("umbrella", paths(umbrella, "#000")),
                          ("text", f'<g{text_tf}>\n{paths(text, "#000")}</g>\n')]:
    (out / f"garoa_{gid}.svg").write_text(head + body + tail)

print(f"centro=({cx:.2f},{cy:.2f}) r_in={r_in:.2f} r_out={r_out:.2f} "
      f"diâmetro={2*r_out:.1f} unidades")
