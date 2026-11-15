% =====================================================================
%  reglas.pl  --  LÓGICA DE PRIMER ORDEN (sin texto, sin interfaz)
% =====================================================================
%  Depende de hechos.pl (jugador/6). Aquí solo hay reglas; el texto de
%  las respuestas vive en chatbot.pl.
%
%  Secciones:
%    1. Acceso a los datos         (equipo_de, liga_de, ...)
%    2. Reglas de relación         (companeros_de_equipo, misma_liga, ...)
%    3. Tipos de relación          (AGREGAR AQUÍ una relación nueva)
%    4. Consultas públicas         (las que usa el chatbot)
%
%  Resultados de las consultas públicas:
%    consultar_ubicacion(J, R):
%        R = ubicacion(J, Equipo, Liga, PaisClub, Estadio, Nacionalidad)
%          | no_existe(J)
%    consultar_relacion(A, B, R):
%        R = relacion(A, B, ListaDeTipos)
%          | sin_relacion(A, B)
%          | mismo_jugador(A)
%          | no_existe(J)
% =====================================================================

:- encoding(utf8).

% ---------------------------------------------------------------------
% 1. ACCESO A LOS DATOS
%    Cada predicado falla si el dato es 'none' (desconocido), así una
%    relación nunca se afirma con datos que no tenemos.
% ---------------------------------------------------------------------
existe_jugador(J) :- jugador(J, _, _, _, _, _), !.

dato_conocido(Dato) :- Dato \== none.

equipo_de(J, E)       :- jugador(J, E, _, _, _, _), dato_conocido(E).
liga_de(J, L)         :- jugador(J, _, L, _, _, _), dato_conocido(L).
pais_club_de(J, P)    :- jugador(J, _, _, P, _, _), dato_conocido(P).
estadio_de(J, S)      :- jugador(J, _, _, _, S, _), dato_conocido(S).
nacionalidad_de(J, N) :- jugador(J, _, _, _, _, N), dato_conocido(N).

% ---------------------------------------------------------------------
% 2. REGLAS DE RELACIÓN  (A y B son jugadores distintos)
%    Cada regla = una forma de estar relacionados.
% ---------------------------------------------------------------------
companeros_de_equipo(A, B)  :- A \== B, equipo_de(A, E),       equipo_de(B, E).
misma_liga(A, B)            :- A \== B, liga_de(A, L),         liga_de(B, L).
mismo_pais_club(A, B)       :- A \== B, pais_club_de(A, P),    pais_club_de(B, P).
misma_nacionalidad(A, B)    :- A \== B, nacionalidad_de(A, N), nacionalidad_de(B, N).

% ---------------------------------------------------------------------
% 3. TIPOS DE RELACIÓN
%    Para sumar una relación nueva:
%      a) escribir su regla en la sección 2,
%      b) agregar su nombre en tipo_relacion/1,
%      c) enlazarla en relacion_entre/3,
%      d) (opcional) darle texto en chatbot.pl -> descripcion_relacion/2.
% ---------------------------------------------------------------------
tipo_relacion(mismo_equipo).
tipo_relacion(misma_liga).
tipo_relacion(mismo_pais_club).
tipo_relacion(misma_nacionalidad).

relacion_entre(mismo_equipo,        A, B) :- companeros_de_equipo(A, B).
relacion_entre(misma_liga,          A, B) :- misma_liga(A, B).
relacion_entre(mismo_pais_club,     A, B) :- mismo_pais_club(A, B).
relacion_entre(misma_nacionalidad,  A, B) :- misma_nacionalidad(A, B).

% relaciones_entre(+A, +B, -Tipos): lista de todos los tipos que se cumplen.
relaciones_entre(A, B, Tipos) :-
    findall(T, ( tipo_relacion(T), once(relacion_entre(T, A, B)) ), Tipos).

% ---------------------------------------------------------------------
% 4. CONSULTAS PÚBLICAS
% ---------------------------------------------------------------------

% Dónde juega un jugador (equipo, liga, país del club, estadio).
consultar_ubicacion(J, Resultado) :-
    (   jugador(J, E, L, P, S, N)
    ->  Resultado = ubicacion(J, E, L, P, S, N)
    ;   Resultado = no_existe(J)
    ).

% Qué relación hay entre dos jugadores.
consultar_relacion(A, B, Resultado) :-
    (   \+ existe_jugador(A) -> Resultado = no_existe(A)
    ;   \+ existe_jugador(B) -> Resultado = no_existe(B)
    ;   A == B               -> Resultado = mismo_jugador(A)
    ;   relaciones_entre(A, B, Tipos),
        (   Tipos == []
        ->  Resultado = sin_relacion(A, B)
        ;   Resultado = relacion(A, B, Tipos)
        )
    ).
