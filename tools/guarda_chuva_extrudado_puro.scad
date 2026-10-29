// Guarda-chuva do logo extrudado reto, sem nenhum ajuste.
//
// Só linear_extrude() da silhueta 2D do SVG: sem saída, sem arredondamento
// e com o cabo/gancho finos do logo (~1,6 mm com a copa de 48 mm). Para a
// versão pensada para chocolate, ver guarda_chuva_reto_arredondado.scad.
//
//   cd tools && openscad --export-format binstl -o ../out/guarda_chuva_extrudado_puro.stl guarda_chuva_extrudado_puro.scad

largura = 48;      // largura da copa (mm), igual ao guarda_chuva_reto_arredondado.scad
altura  = 10;      // altura do extrudado (mm)

// --- Geometria do SVG de 60 mm (ver make_logo_circle.py) ----------------
VB = 426.82;
COPA_LARGURA = 323.33;                // largura da copa (unidades do SVG original)
K = 60 / VB;                          // mm do SVG de 60 mm por unidade
esc = largura / (COPA_LARGURA * K);   // SVG de 60 mm -> doce

linear_extrude(altura) scale(esc) import("../out/garoa_umbrella.svg", center = true);
