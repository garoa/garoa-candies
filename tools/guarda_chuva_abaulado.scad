// Doce em formato de guarda-chuva, abaulado por fora (como uma esfera).
//
// A forma é calculada por guarda_chuva_abaulado_altura.py como um mapa de altura
// (out/guarda_chuva_abaulado_altura.png); aqui só transformamos o mapa em sólido.
// Para mudar tamanho, altura, abaulado etc., edite os parâmetros no topo
// do .py e rode:
//
//   python3 tools/guarda_chuva_abaulado_altura.py out
//   cd tools && openscad -o ../out/guarda_chuva_abaulado.stl guarda_chuva_abaulado.scad

include <../out/guarda_chuva_abaulado_altura.scad>   // MM_PX, ALTURA, PX

/* [Placa com várias cavidades] */
colunas = 1;
linhas  = 1;
espaco  = 15;   // distância entre doces (mm)
placa   = 0;    // espessura da placa de base (0 = sem placa)

lado = PX * MM_PX;

module doce() {
    // surface() lê o PNG em cinza como alturas de 0 a 100 e põe uma base
    // embaixo; cortamos tudo abaixo de 0,05 mm para sobrar só o doce.
    intersection() {
        scale([MM_PX, MM_PX, ALTURA / 100])
            surface(file = "../out/guarda_chuva_abaulado_altura.png", center = true);
        translate([-lado / 2, -lado / 2, 0.05]) cube([lado, lado, ALTURA + 1]);
    }
}

for (c = [0 : colunas - 1], l = [0 : linhas - 1])
    translate([c * (lado + espaco), l * (lado + espaco), placa - 0.05]) doce();

if (placa > 0)
    translate([-lado / 2, -lado / 2, 0])
        cube([colunas * (lado + espaco) - espaco, linhas * (lado + espaco) - espaco, placa]);
