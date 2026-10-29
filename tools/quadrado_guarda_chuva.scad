// Modelo mestre (positivo) para vacuum forming: bloco quadrado com o
// guarda-chuva do logo cavado no topo (sem o GAROA).
//
// Mesma ideia do pao_de_mel_disco_logo.scad, mas com corpo quadrado: lateral
// com saída, cantos verticais arredondados e borda de cima arredondada. O
// chocolate sai igual ao mestre, com o guarda-chuva em baixo-relevo.
//
//   cd tools && openscad --export-format binstl -o ../out/quadrado_guarda_chuva.stl quadrado_guarda_chuva.scad

/* [Doce] */
lado    = 40;    // lado do quadrado na base (boca da forma) (mm)
altura  = 5;     // altura total do doce (mm)
draft   = 3;     // ângulo de saída da lateral (graus); diminui o topo
raio    = 3;     // arredondamento da borda superior (mm)
canto   = 5;     // raio dos cantos verticais, na base (mm)
folga   = 1;     // distância entre o guarda-chuva e o início da curva (mm)

/* [Guarda-chuva em negativo] */
// Cada sulco deve ser <= largura do traço que ele cava (cabo ~1,3 mm),
// senão o plástico não chega ao fundo.
profundidade = 1.0;  // profundidade do guarda-chuva (mm)
draft_logo   = 15;   // ângulo de saída das paredes cavadas (graus)
engrossar    = 0.15; // alarga cabo/guarda-chuva (mm por lado)

/* [Respiros] */
respiros  = true;
d_respiro = 0.8;  // diâmetro (mm); 0,6–1,0. Maior que 1 mm marca o chocolate

/* [Placa com várias cavidades] */
colunas = 1;
linhas  = 1;
espaco  = 20;    // distância entre doces (mm); >= altura, senão o plástico faz "teia"
placa   = 0;     // espessura da placa de base (0 = sem placa)

passos = 4;      // fatias das rampas de saída do guarda-chuva
$fn = 96;
svg_fn = 24;     // segmentos por curva do logo (ver pao_de_mel_disco_logo.scad)

R0 = lado / 2;
// centro do arco do arredondamento (distância do centro até ele na
// horizontal), tangente à lateral inclinada e ao topo
cz = altura - raio;
cx = R0 - cz * tan(draft) - raio / cos(draft);
// os cantos da base têm raio `canto`; no topo o arco do arredondamento
// percorre um círculo com este raio em volta do mesmo centro
c0 = R0 - canto;
R_TORO = cx - c0;
assert(R_TORO >= 0, "aumente `canto` ou diminua `draft`/`raio`");

// --- Geometria do SVG de 60 mm (ver make_logo_circle.py) ----------------
// No garoa_umbrella.svg o guarda-chuva já fica centrado em (30, 30) e mede
// ~45,5 × 52,5 mm (copa × comprimento com o gancho).
VB = 426.82;
K = 60 / VB;
COMPRIMENTO_SVG = 52.5;
esc = 2 * (cx - folga) / COMPRIMENTO_SVG;
copa = 323.33 * K * esc;

module svg() scale([esc, esc]) translate([-30, -30]) import("../out/garoa_umbrella.svg", $fn = svg_fn);

// ponto do Logo_Garoa.svg original -> mm no topo do doce
function logo_pt(p) = esc * [(p[0] - 74.055) * K - 30, 30 - (p[1] - 241.635) * K];

// Cantos onde o ar fica preso: ponta do cabo, gancho, pontas das ondinhas.
PONTOS_RESPIRO = [
    [287.5, 273.5],
    [315.1, 636.4], [338.5, 593.0],
    [131.1, 431.5], [193.6, 431.5], [256.1, 431.5],
    [318.6, 431.5], [381.1, 431.5], [443.6, 431.5],
];

// Igual ao do pão de mel: a forma cresce conforme sobe (sulco abrindo pra cima).
module extrude_draft_aberto(h, ang) {
    for (i = [0 : passos - 1]) {
        z = i * h / passos;
        translate([0, 0, z])
            linear_extrude(h / passos + 0.001)
                offset(delta = tan(ang) * z) children();
    }
}

module corpo() {
    // com `raio` > altura - raio o arco do arredondamento passaria da base;
    // corta tudo abaixo de z = 0
    intersection() {
    translate([-lado, -lado, 0]) cube([2 * lado, 2 * lado, altura + 1]);
    hull() {
        linear_extrude(0.01) offset(r = canto) square(2 * c0, center = true);
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * c0, sy * c0, cz])
                rotate_extrude() intersection() {
                    // R_TORO < raio: um toro se cruzaria no meio, então gira
                    // só a metade x >= 0 do "estádio" equivalente
                    hull() for (x = [-R_TORO, R_TORO]) translate([x, 0]) circle(r = raio);
                    translate([0, -raio]) square(2 * raio + R_TORO);
                }
    }
    }
}

module doce() {
    fundo = altura - profundidade;
    difference() {
        corpo();
        translate([0, 0, fundo])
            extrude_draft_aberto(profundidade + 0.01, draft_logo)
                offset(delta = engrossar) svg();
        if (respiros)
            for (p = PONTOS_RESPIRO)
                translate([each logo_pt(p), -placa - 1])
                    cylinder(d = d_respiro, h = fundo + placa + 1.01, $fn = 24);
    }
}

echo(str("Base: ", lado, " mm | topo plano: ", 2 * cx, " mm | copa: ", copa,
         " mm | guarda-chuva: ", COMPRIMENTO_SVG * esc, " mm"));

passo = lado + espaco;
for (c = [0 : colunas - 1], l = [0 : linhas - 1])
    translate([c * passo, l * passo, placa]) doce();

if (placa > 0)
    difference() {
        translate([-passo / 2, -passo / 2, 0])
            cube([colunas * passo, linhas * passo, placa]);
        if (respiros)
            for (c = [0 : colunas - 1], l = [0 : linhas - 1], p = PONTOS_RESPIRO)
                translate([c * passo, l * passo, -1])
                    translate([each logo_pt(p), 0])
                        cylinder(d = d_respiro, h = placa + 2, $fn = 24);
    }
