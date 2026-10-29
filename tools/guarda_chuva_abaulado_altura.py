#!/usr/bin/env python3
"""Gera o mapa de altura do doce de guarda-chuva abaulado.

Uso: python3 tools/guarda_chuva_abaulado_altura.py [pasta_out]
     (depois: cd tools && openscad -o ../out/guarda_chuva_abaulado.stl guarda_chuva_abaulado.scad)

Em vez de modelar com CSG (minkowski é lento demais), calculamos a altura do
doce em cada ponto a partir da distância até a borda do guarda-chuva:

  - copa:   domo (elipsoide) que desce suave até a borda — perfil parabólico,
            então a borda tem inclinação (bom para desmoldar);
  - cabo:   bastão roliço (meia-cana) que segue o traço do cabo e do gancho;
  - GAROA:  gravado na copa, com paredes levemente inclinadas.

Saídas em out/: guarda_chuva_abaulado_altura.png (cinza 8 bits, preto = 0 mm,
branco = ALTURA) e guarda_chuva_abaulado_altura.scad (escala para o OpenSCAD).
Requer rsvg-convert (librsvg) e os SVGs gerados por make_logo_circle.py.
"""
import math
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "out")

# --- Parâmetros (mm, no doce final) -------------------------------------
LARGURA = 60.0      # largura da copa; o doce fica ~1,16x mais comprido
ALTURA = 12.0       # altura do ponto mais alto da copa
PERFIL = 0.5        # forma da copa "inflada": 0,5 = bem redonda (bordas em
                    # quarto de círculo); 0,3 = mais cheia/achatada no topo;
                    # 0,7 = mais pontuda no centro
ENGROSSAR = 1.2     # engrossa o contorno (cabo de ~2 mm vira ~4,4 mm)
LARGURA_CABO = 6.0  # largura do cabo e do gancho (mm); em chocolate, >= 5
ALTURA_CABO = 4.5   # altura do cabo (mm); seção oval
TEXTO = False       # grava GAROA na copa?
PROF_TEXTO = 0.7    # profundidade do GAROA
RAMPA_TEXTO = 0.3   # largura da rampa na borda das letras (saída)
RESOLUCAO = 0.1     # mm por pixel do mapa de altura
SUAVIZAR = 2        # raio (px) do desfoque que tira o serrilhado dos pixels

# --- Geometria do SVG de 60 mm (ver make_logo_circle.py) -----------------
DOC_MM = 60.0
VB = 426.82                         # unidades do viewBox
VB_X0, VB_Y0 = 74.055, 241.635      # origem do viewBox no Logo_Garoa.svg
K = DOC_MM / VB                     # mm do documento por unidade
ESC = LARGURA / (323.33 * K)        # documento -> doce
MM_UNID = K * ESC                   # mm do doce por unidade do SVG original

# Faixa da copa (unidades do SVG original); fora dela é cabo
COPA_Y0, COPA_Y1 = 296.0, 440.0
CABO_X = 287.54
ARCO_TOPO = 403.0   # topo dos arcos ("ondinhas"), onde o cabo sai da copa

PX = round(DOC_MM * ESC / RESOLUCAO)  # lado da imagem em pixels


def rasterizar(svg: Path, dilatar_unid: float = 0.0) -> list:
    """Renderiza o SVG e devolve uma máscara (lista de linhas de bool)."""
    txt = svg.read_text()
    if dilatar_unid > 0:
        # dilata desenhando contorno redondo da mesma cor (= offset(r))
        txt = txt.replace('fill="#000"', f'fill="#000" stroke="#000" '
                          f'stroke-width="{2 * dilatar_unid:.3f}" '
                          f'stroke-linejoin="round"')
    with tempfile.TemporaryDirectory() as d:
        src, png = Path(d) / "in.svg", Path(d) / "out.png"
        src.write_text(txt)
        subprocess.run(["rsvg-convert", "-w", str(PX), "-h", str(PX),
                        str(src), "-o", str(png)], check=True)
        w, h, rows = ler_png_rgba(png)
    return [[row[4 * i + 3] > 127 for i in range(w)] for row in rows]


def ler_png_rgba(path: Path):
    """Decodificador mínimo de PNG RGBA 8 bits (o que o rsvg-convert gera)."""
    data = path.read_bytes()
    pos, idat = 8, b""
    while pos < len(data):
        n, tipo = struct.unpack(">I4s", data[pos:pos + 8])
        corpo = data[pos + 8:pos + 8 + n]
        if tipo == b"IHDR":
            w, h, prof, cor = struct.unpack(">IIBB", corpo[:10])
            assert prof == 8 and cor == 6, "esperava PNG RGBA 8 bits"
        elif tipo == b"IDAT":
            idat += corpo
        pos += 12 + n
    raw, bpp, stride = zlib.decompress(idat), 4, w * 4
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        cur = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = cur[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                cur[i] = (cur[i] + a) & 255
            elif f == 2:
                cur[i] = (cur[i] + b) & 255
            elif f == 3:
                cur[i] = (cur[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                cur[i] = (cur[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(cur)
        prev = cur
    return w, h, rows


def _edt_1d(f):
    """Transformada de distância 1D ao quadrado (Felzenszwalb & Huttenlocher)."""
    n = len(f)
    d, v, z = [0.0] * n, [0] * n, [0.0] * (n + 1)
    k, z[0], z[1] = 0, -math.inf, math.inf
    for q in range(1, n):
        while True:
            s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
            if s <= z[k]:
                k -= 1
            else:
                break
        k += 1
        v[k], z[k], z[k + 1] = q, s, math.inf
    k = 0
    for q in range(n):
        while z[k + 1] < q:
            k += 1
        d[q] = (q - v[k]) ** 2 + f[v[k]]
    return d


def distancia_ate_fora(mask):
    """Para cada pixel dentro da máscara, distância (px) ao pixel de fora mais próximo."""
    big = 1e12
    h, w = len(mask), len(mask[0])
    cols = [[0.0 if not mask[y][x] else big for y in range(h)] for x in range(w)]
    cols = [_edt_1d(c) for c in cols]
    rows = [_edt_1d([cols[x][y] for x in range(w)]) for y in range(h)]
    return [[math.sqrt(v) for v in r] for r in rows]


# Linha central do cabo (unidades do SVG original): reta vertical e o arco
# do gancho (centro, raio e ângulo da ponta, com y para baixo).
CABO_TOPO, CABO_FIM = 273.5, 608.9
GANCHO_C, GANCHO_R, GANCHO_PONTA = (315.07, 608.9), 27.53, -34.0


def dist_cabo(ux, uy):
    """Distância (unidades) do ponto até a linha central do cabo + gancho."""
    y = min(max(uy, CABO_TOPO), CABO_FIM)
    d = math.hypot(ux - CABO_X, uy - y)
    dx, dy = ux - GANCHO_C[0], uy - GANCHO_C[1]
    ang = math.degrees(math.atan2(dy, dx))
    if GANCHO_PONTA <= ang <= 180:            # passa por baixo (y > centro)
        d = min(d, abs(math.hypot(dx, dy) - GANCHO_R))
    else:                                       # perto da ponta do gancho
        t = math.radians(GANCHO_PONTA)
        pt = (GANCHO_C[0] + GANCHO_R * math.cos(t), GANCHO_C[1] + GANCHO_R * math.sin(t))
        d = min(d, math.hypot(ux - pt[0], uy - pt[1]))
    return d


def _sor(mask, u, passo, iteracoes, omega):
    """Resolve Δu = -1 dentro da máscara (u = 0 fora) por Gauss-Seidel/SOR."""
    h, w = len(mask), len(mask[0])
    dentro = [y * w + x for y in range(1, h - 1) for x in range(1, w - 1) if mask[y][x]]
    f = passo * passo
    for _ in range(iteracoes):
        for k in dentro:
            novo = (u[k - 1] + u[k + 1] + u[k - w] + u[k + w] + f) * 0.25
            u[k] += omega * (novo - u[k])
    return u


def inflar(mask, fator=4):
    """Altura de "balão" (0..1) dentro da máscara: solução de Poisson,
    resolvida numa grade grossa e refinada na grade fina."""
    h, w = len(mask), len(mask[0])
    hc, wc = h // fator, w // fator
    grossa = [[mask[y * fator + fator // 2][x * fator + fator // 2]
               for x in range(wc)] for y in range(hc)]
    ug = _sor(grossa, [0.0] * (hc * wc), fator, 800, 1.95)
    # interpolação bilinear para a grade fina
    u = [0.0] * (h * w)
    for y in range(h):
        gy = min(max((y - fator / 2 + 0.5) / fator, 0), hc - 1.001)
        y0, ty = int(gy), gy - int(gy)
        for x in range(w):
            if not mask[y][x]:
                continue
            gx = min(max((x - fator / 2 + 0.5) / fator, 0), wc - 1.001)
            x0, tx = int(gx), gx - int(gx)
            i = y0 * wc + x0
            u[y * w + x] = ((ug[i] * (1 - tx) + ug[i + 1] * tx) * (1 - ty)
                            + (ug[i + wc] * (1 - tx) + ug[i + wc + 1] * tx) * ty)
    u = _sor(mask, u, 1, 60, 1.9)
    m = max(u)
    return [[u[y * w + x] / m for x in range(w)] for y in range(h)]


def suavizar(m, r, vertical=False):
    """Média móvel de raio r nas linhas (ou colunas, se vertical)."""
    if vertical:
        m = [list(c) for c in zip(*m)]
    res = []
    for row in m:
        acc, n, out_row = 0.0, len(row), []
        pref = [0.0]
        for v in row:
            acc += v
            pref.append(acc)
        for i in range(n):
            a, b = max(0, i - r), min(n, i + r + 1)
            out_row.append((pref[b] - pref[a]) / (b - a))
        res.append(out_row)
    return [list(c) for c in zip(*res)] if vertical else res


def na_copa(ux, uy):
    """A copa é a faixa COPA_Y0..COPA_Y1, menos o cabo abaixo dos arcos."""
    meia_faixa_cabo = 5.31 + ENGROSSAR / MM_UNID + 1
    return (COPA_Y0 <= uy <= COPA_Y1
            and not (uy > ARCO_TOPO - ENGROSSAR / MM_UNID and abs(ux - CABO_X) < meia_faixa_cabo))


def unid(px, py):
    """Centro do pixel -> coordenadas do Logo_Garoa.svg original."""
    s = DOC_MM / PX / K
    return (px + 0.5) * s + VB_X0, (py + 0.5) * s + VB_Y0


def main():
    print(f"imagem {PX}x{PX} px ({RESOLUCAO} mm/px)...")
    guarda = rasterizar(out / "garoa_umbrella.svg", ENGROSSAR / MM_UNID)
    letras = rasterizar(out / "garoa_text.svg")
    # máscara só da copa, com distância própria: assim a copa desce suave
    # até a base também onde o cabo sai de baixo dela
    copa = [[guarda[py][px] and na_copa(*unid(px, py)) for px in range(PX)]
            for py in range(PX)]
    d_l = distancia_ate_fora(letras)
    infl = inflar(copa)

    w_cabo = LARGURA_CABO / 2
    # o cabo tem medida própria, independente do contorno do logo
    forma = [[guarda[py][px] or dist_cabo(*unid(px, py)) * MM_UNID < w_cabo
              for px in range(PX)] for py in range(PX)]

    alt = [[0.0] * PX for _ in range(PX)]
    for py in range(PX):
        for px in range(PX):
            if not forma[py][px]:
                continue
            ux, uy = unid(px, py)
            # cabo / gancho: meia-cana em volta da linha central
            r = dist_cabo(ux, uy) * MM_UNID
            h = ALTURA_CABO * math.sqrt(max(0.0, 1 - (r / w_cabo) ** 2))
            # copa: "balão" inflado dentro do contorno
            if copa[py][px]:
                h = max(h, ALTURA * infl[py][px] ** PERFIL)
                # GAROA gravado, com rampa nas bordas das letras
                if TEXTO and letras[py][px]:
                    h -= PROF_TEXTO * min(1.0, d_l[py][px] * RESOLUCAO / RAMPA_TEXTO)
            alt[py][px] = max(0.0, h)

    # desfoque em caixa (2 passadas ≈ gaussiano), só dentro do guarda-chuva
    for _ in range(2):
        alt = suavizar(suavizar(alt, SUAVIZAR), SUAVIZAR, vertical=True)
    hmax = 0.0
    img = bytearray()
    for py in range(PX):
        img.append(0)  # filtro PNG "none"
        for px in range(PX):
            h = alt[py][px] if forma[py][px] else 0.0
            hmax = max(hmax, h)
            img.append(round(h / ALTURA * 255))

    def chunk(t, c):
        return struct.pack(">I", len(c)) + t + c + struct.pack(">I", zlib.crc32(t + c))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", PX, PX, 8, 0, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(img), 9))
           + chunk(b"IEND", b""))
    (out / "guarda_chuva_abaulado_altura.png").write_bytes(png)
    (out / "guarda_chuva_abaulado_altura.scad").write_text(
        "// gerado por guarda_chuva_abaulado_altura.py — não editar\n"
        f"MM_PX = {RESOLUCAO};\nALTURA = {ALTURA};\nPX = {PX};\n")
    print(f"ok: altura máx {hmax:.2f} mm, doce ~{PX * RESOLUCAO:.0f} mm de lado")


main()
