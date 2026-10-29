// Doce pequeno em formato de guarda-chuva, extrudado reto (sem o GAROA).
//
// Silhueta do guarda-chuva levantada `altura` mm, com saída nas laterais
// (para desmoldar no vacuum forming) e a borda de cima arredondada. O cabo
// e o gancho do logo são finos demais para chocolate, então são refeitos
// aqui com largura própria em volta da linha central do traço.
//
//   cd tools && openscad --export-format binstl -o ../out/guarda_chuva_reto_arredondado.stl guarda_chuva_reto_arredondado.scad

/* [Doce] */
largura = 48;      // largura da copa (mm); o doce de disco tem 50
altura  = 10;      // altura do doce (mm)
draft   = 3;       // ângulo de saída da lateral (graus)
raio    = 1.5;     // arredondamento da borda de cima (mm)
fechar  = 1.5;     // arredonda as curvinhas entre as ondinhas e junto ao cabo (mm)
// As pontas das ondinhas saem arredondadas com raio_base (ver abaixo), que
// vem do raio de cima + saída: a lateral é uma só superfície contínua.

/* [Cabo] */
largura_cabo = 5;  // largura do cabo e do gancho (mm); em chocolate, >= 5
raio_gancho  = 5;  // raio da linha central do gancho (mm); o vão interno é
                   // 2 x raio_gancho - largura_cabo e precisa passar de 2 x fechar

/* [Placa com várias cavidades] */
colunas = 1;
linhas  = 1;
espaco  = 15;      // distância entre doces (mm); >= altura, senão o plástico faz "teia"
placa   = 0;       // espessura da placa de base (0 = sem placa)

$fn = 64;

// --- Geometria do SVG de 60 mm (ver make_logo_circle.py) ----------------
// Coordenadas em unidades do Logo_Garoa.svg original (y para baixo).
VB = 426.82;
VB_X0 = 74.055;  VB_Y0 = 241.635;
K = 60 / VB;                          // mm do SVG de 60 mm por unidade
COPA_LARGURA = 323.33;                // largura da copa (unidades)
COPA_Y0 = 296;  COPA_Y1 = 440;        // faixa da copa
CABO_X = 287.54;
CABO_TOPO = 273.5;  CABO_FIM = 608.9; // linha central do cabo
GANCHO_PONTA = -34;                   // ângulo da ponta do gancho

esc = largura / (COPA_LARGURA * K);   // SVG de 60 mm -> doce
mm_unid = K * esc;                    // mm do doce por unidade original

// ponto do SVG original -> mm no doce (y para cima, cabo em x = 0)
function pt(p) = [(p[0] - CABO_X) * mm_unid, -(p[1] - VB_Y0) * mm_unid];

module copa() {
    // só a faixa da copa do SVG; o cabo fino fica de fora
    intersection() {
        scale(esc) translate([-(CABO_X - VB_X0) * K, -VB * K]) import("../out/garoa_umbrella.svg");
        translate(pt([0, COPA_Y1])) square([1000, (COPA_Y1 - COPA_Y0) * mm_unid]);
    }
}

module cabo() {
    r = largura_cabo / 2;
    fim = pt([CABO_X, CABO_FIM]);
    hull() { translate(pt([CABO_X, CABO_TOPO])) circle(r); translate(fim) circle(r); }
    // gancho: meia-volta por baixo, do fim do cabo até a ponta (ângulos do
    // SVG, com y para baixo), com raio próprio para o vão não fechar
    c = fim + [raio_gancho, 0];
    angs = [for (a = [GANCHO_PONTA : 4 : 180]) a];
    for (i = [0 : len(angs) - 2])
        hull() for (a = [angs[i], angs[i + 1]])
            translate(c + raio_gancho * [cos(a), -sin(a)]) circle(r);
}

module silhueta() {
    // fecha as curvinhas entre as ondinhas e junto ao cabo
    offset(r = -fechar) offset(r = fechar) union() { copa(); cabo(); }
}

// Quanto a lateral avança na base em relação ao topo plano.
raio_base = raio + (altura - raio) * tan(draft);

// Ferramenta da lateral: tronco de cone (saída) com uma esfera no topo
// (arredondamento). O minkowski passa essa forma por todo o contorno, então
// a lateral sai lisa, sem degraus de fatias.
module ferramenta() {
    hull() {
        cylinder(r1 = raio_base, r2 = raio, h = altura - raio);
        translate([0, 0, altura - raio]) sphere(raio);
    }
}

module doce() {
    intersection() {
        minkowski() {
            linear_extrude(0.01) offset(r = -raio_base) silhueta();
            ferramenta();
        }
        // corta só o excesso de 0,01 mm no topo (cortar em z = 0, rente à
        // base, deixa arestas duplicadas na malha)
        translate([-500, -500, -1]) cube([1000, 1000, altura + 1]);
    }
}

// centraliza o doce (copa + cabo) na origem
fundo = pt([CABO_X, CABO_FIM])[1] - raio_gancho - largura_cabo / 2;
centro = [0, (pt([CABO_X, CABO_TOPO])[1] + largura_cabo / 2 + fundo) / 2];
comprimento = pt([CABO_X, CABO_TOPO])[1] + largura_cabo / 2 - fundo;
echo(str("Doce: ", largura, " x ", comprimento, " mm, ", altura, " mm de altura"));

passo_x = largura + espaco;
passo_y = comprimento + espaco;
for (c = [0 : colunas - 1], l = [0 : linhas - 1])
    translate([c * passo_x, l * passo_y, placa]) translate(-centro) doce();

if (placa > 0)
    translate([-passo_x / 2, -passo_y / 2, 0])
        cube([colunas * passo_x, linhas * passo_y, placa]);
