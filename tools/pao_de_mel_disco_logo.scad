// Modelo mestre (positivo) para vacuum forming da forma de chocolate do Garoa.
// O plástico é puxado POR CIMA desta peça; a cavidade resultante tem
// exatamente este formato, então o chocolate sai igual ao mestre.
//
// Os SVGs em ../out/ são gerados por make_logo_circle.py com 60 mm e
// reescalados aqui para caber na parte plana do topo.

/* [Doce] */
D       = 50;    // largura máxima do doce (base do mestre / boca da forma) (mm)
altura  = 28;    // altura total do doce (mm)
draft   = 3;     // ângulo de saída da lateral (graus); diminui o topo
raio    = 4;     // arredondamento da borda superior (mm)
folga   = 1;     // distância entre o logo e o início da curva (mm)

/* [Logo em negativo] */
// Tudo cavado no topo, em dois níveis: o guarda-chuva desce `profundidade`
// e o GAROA desce mais `profundidade_letras` a partir do fundo do
// guarda-chuva. Cada degrau deve ser <= largura do traço que ele cava
// (cabo ~1,3 mm, letras ~1 mm), senão o plástico não chega ao fundo.
profundidade = 1.0;         // profundidade do guarda-chuva (mm)
profundidade_letras = 0.6;  // profundidade extra das letras (mm)
draft_logo = 15;            // ângulo de saída das paredes cavadas (graus)
engrossar  = 0.15;          // alarga cabo/guarda-chuva (mm por lado)
engrossar_letras = 0.0;     // alarga os sulcos das letras (mm por lado)

/* [Respiros] */
// Furos verticais do fundo do bolsão até a base, para o ar preso nos cantos
// sair quando o vácuo puxa o plástico.
respiros  = true;
d_respiro = 0.8;  // diâmetro (mm); 0,6–1,0. Maior que 1 mm marca o chocolate

/* [Placa com várias cavidades] */
colunas = 1;
linhas  = 1;
espaco  = 30;    // distância entre doces (mm); >= altura, senão o plástico faz "teia"
placa   = 0;     // espessura da placa de base (0 = sem placa)

passos = 4;      // fatias das rampas de saída do logo; 4 dá degraus de
                 // ~0,25 mm (perto da camada de impressão) e 1/3 dos triângulos de 12
$fn = 160;       // segmentos do corpo redondo
svg_fn = 24;     // segmentos por curva do logo; 160 aqui dava ~674 mil
                 // triângulos sem diferença visível, e o slicer engasgava

R0 = D / 2;                              // raio na base
// centro do arco do arredondamento, tangente à lateral inclinada e ao topo
cz = altura - raio;
cx = R0 - cz * tan(draft) - raio / cos(draft);
// O ponto do guarda-chuva mais longe do centro (ponta do cabo) fica a
// ~26,8 mm do centro no SVG de 60 mm; escalamos para caber no topo plano.
R_LOGO_SVG = 26.8;
esc = (cx - folga) / R_LOGO_SVG;
logo_D = 2 * R_LOGO_SVG * esc;

module svg(f) scale([esc, esc]) translate([-30, -30]) import(str("../out/", f), $fn = svg_fn);

// Converte um ponto do Logo_Garoa.svg original (unidades do SVG, as mesmas que o Inkscape mostra)
// para a posição em mm no topo do doce. Constantes vêm de make_logo_circle.py
// (viewBox de 426,82 unidades a partir de 74,055 / 241,635 = 60 mm).
function logo_pt(p) = let(k = 60 / 426.82)
    esc * [(p[0] - 74.055) * k - 30, 30 - (p[1] - 241.635) * k];

// Cantos onde o ar fica preso: ponta do cabo, gancho, pontas do guarda-chuva.
PONTOS_RESPIRO = [
    [287.5, 273.5],                       // ponta de cima do cabo
    [315.1, 636.4], [338.5, 593.0],       // fundo e ponta do gancho
    [131.1, 431.5], [193.6, 431.5], [256.1, 431.5],   // pontas das ondinhas
    [318.6, 431.5], [381.1, 431.5], [443.6, 431.5],
];

// Extruda uma forma 2D com paredes inclinadas (encolhe conforme sobe).
module extrude_draft(h, ang) {
    for (i = [0 : passos - 1]) {
        z = i * h / passos;
        translate([0, 0, z])
            linear_extrude(h / passos + 0.001)
                offset(delta = -tan(ang) * (z + h / passos)) children();
    }
}

// Igual, mas a forma cresce conforme sobe (para sulcos que abrem pra cima).
module extrude_draft_aberto(h, ang) {
    for (i = [0 : passos - 1]) {
        z = i * h / passos;
        translate([0, 0, z])
            linear_extrude(h / passos + 0.001)
                offset(delta = tan(ang) * z) children();
    }
}

// Perfil 2D (meio corte) do corpo: lateral com saída, topo arredondado.
module perfil() {
    hull() {
        square([R0, 0.01]);
        square([0.01, altura]);
        translate([cx, cz]) circle(r = raio);
        translate([0, cz]) square([cx, raio]);
    }
}

module doce() {
    fundo = altura - profundidade;
    difference() {
        rotate_extrude() perfil();
        // guarda-chuva cavado, abrindo para cima (saída para o plástico)
        translate([0, 0, fundo])
            extrude_draft_aberto(profundidade + 0.01, draft_logo)
                offset(delta = engrossar) svg("garoa_umbrella.svg");
        // GAROA cavado mais fundo, a partir do fundo do guarda-chuva
        translate([0, 0, fundo - profundidade_letras])
            extrude_draft_aberto(profundidade_letras + 0.02, draft_logo)
                offset(delta = engrossar_letras) svg("garoa_text.svg");
        if (respiros)
            for (p = PONTOS_RESPIRO)
                translate([each logo_pt(p), -placa - 1])
                    cylinder(d = d_respiro, h = fundo + placa + 1.01, $fn = 24);
    }
}

echo(str("Topo plano: ", 2 * cx, " mm | logo: ", logo_D, " mm | base: ", D, " mm"));

passo_x = D + espaco;
for (c = [0 : colunas - 1], l = [0 : linhas - 1])
    translate([c * passo_x, l * passo_x, placa]) doce();

if (placa > 0)
    difference() {
        translate([-passo_x / 2, -passo_x / 2, 0])
            cube([colunas * passo_x, linhas * passo_x, placa]);
        if (respiros)
            for (c = [0 : colunas - 1], l = [0 : linhas - 1], p = PONTOS_RESPIRO)
                translate([c * passo_x, l * passo_x, -1])
                    translate([each logo_pt(p), 0])
                        cylinder(d = d_respiro, h = placa + 2, $fn = 24);
    }
