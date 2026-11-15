% =====================================================================
%  chatbot.pl  --  INTÉRPRETE DE PREGUNTAS (palabras clave, español)
% =====================================================================
%  Flujo:  pregunta -> tokens -> jugadores mencionados -> intención
%          -> reglas.pl (consultar_ubicacion / consultar_relacion)
%          -> texto de respuesta.
%
%  Uso en la consola de SWI-Prolog:
%      $ swipl prolog/chatbot.pl
%      ?- chat.                                    % ciclo interactivo
%      ?- responder('¿Dónde juega Messi?', R).     % una sola pregunta
%      ?- make.                                    % recarga tras editar un .pl
%
%  Uso desde Python:  prolog/api.pl (lee stdin, imprime JSON).
%
%  Secciones:
%    1. Normalización del texto     5. Texto de las respuestas
%    2. Reconocer jugadores         6. Decisión (responder/2 y /4)
%    3. Palabras clave (EDITABLE)   7. Mensajes fijos
%    4. Formato de nombres          8. Ciclo de consola
% =====================================================================

:- encoding(utf8).
:- ensure_loaded(hechos).
:- ensure_loaded(reglas).

% ---------------------------------------------------------------------
% 1. NORMALIZACIÓN: minúsculas, sin tildes, sin signos -> lista de átomos
%    normalizar_texto('¿Dónde juega Mbappé?', T)  =>  T = [donde,juega,mbappe]
% ---------------------------------------------------------------------
normalizar_texto(Entrada, Tokens) :-
    text_to_string(Entrada, S0),
    string_lower(S0, S1),
    string_codes(S1, Codigos0),
    maplist(limpiar_codigo, Codigos0, Codigos),
    string_codes(S2, Codigos),
    split_string(S2, " ", " ", Partes),
    exclude(==(""), Partes, Utiles),
    maplist(cadena_a_atomo, Utiles, Tokens).

cadena_a_atomo(Cadena, Atomo) :- atom_string(Atomo, Cadena).

limpiar_codigo(C, R) :- sin_tilde(C, R), !.            % á -> a
limpiar_codigo(C, C)  :- code_type(C, alnum), !.       % letras y dígitos
limpiar_codigo(_, 32).                                 % lo demás -> espacio

sin_tilde(0'á, 0'a).  sin_tilde(0'é, 0'e).  sin_tilde(0'í, 0'i).
sin_tilde(0'ó, 0'o).  sin_tilde(0'ú, 0'u).  sin_tilde(0'ü, 0'u).
sin_tilde(0'ñ, 0'n).  sin_tilde(0'ø, 0'o).  sin_tilde(0'ã, 0'a).
sin_tilde(0'ç, 0'c).

% ---------------------------------------------------------------------
% 2. RECONOCER JUGADORES EN LA PREGUNTA
%    Un jugador se reconoce si aparece su nombre completo, o una palabra
%    de su nombre (>= 4 letras) que sea única en la base (ej: "messi").
% ---------------------------------------------------------------------
jugadores_mencionados(Tokens, Jugadores) :-
    findall(J, ( jugador(J, _, _, _, _, _), menciona(Tokens, J) ), Todos),
    list_to_set(Todos, Jugadores).

menciona(Tokens, J) :-                      % nombre completo
    normalizar_texto(J, NT), NT \== [],
    subset(NT, Tokens), !.
menciona(Tokens, J) :-                      % una palabra distintiva
    normalizar_texto(J, NT),
    member(T, NT),
    atom_length(T, L), L >= 4,
    memberchk(T, Tokens),
    palabra_unica(T), !.

palabra_unica(T) :-
    findall(J, ( jugador(J, _, _, _, _, _),
                 normalizar_texto(J, NT), memberchk(T, NT) ), Js),
    sort(Js, [_]).

% ---------------------------------------------------------------------
% 3. PALABRAS CLAVE  (EDITAR AQUÍ para entender más frases)
%    Escribirlas en minúsculas y SIN tildes.
% ---------------------------------------------------------------------
% Intención "relación entre jugadores"
palabras_clave(relacion, [relacion, relaciones, relaciona, relacionan,
                          relacionados, companero, companeros, juntos,
                          comparten, comparte, mismo, misma, mismos,
                          mismas, conexion, vinculo, comun]).
% Saludo / ayuda
palabras_clave(ayuda,    [hola, buenas, ayuda, help, saludos, ayudame]).
% Pedir la lista de jugadores
palabras_clave(listar,   [conoces, lista, listado, disponibles, sabes, hay]).

% Foco de una pregunta sobre un solo jugador (qué dato se pide)
palabras_foco(equipo,       [equipo, club, camiseta]).
palabras_foco(liga,         [liga, campeonato, torneo]).
palabras_foco(pais,         [pais, paises]).
palabras_foco(estadio,      [estadio, cancha, local]).
palabras_foco(nacionalidad, [nacionalidad, nacio, origen, oriundo]).

tiene_clave(Grupo, Tokens) :-
    palabras_clave(Grupo, Palabras),
    member(P, Palabras), memberchk(P, Tokens), !.

% foco_pregunta(+Tokens, -Foco): un foco concreto, o 'todo' si hay 0 o varios.
foco_pregunta(Tokens, Foco) :-
    findall(F, ( palabras_foco(F, Ps), member(P, Ps), memberchk(P, Tokens) ), Fs0),
    sort(Fs0, Fs),
    (   Fs = [Unico] -> Foco = Unico ; Foco = todo ).

% ---------------------------------------------------------------------
% 4. FORMATO DE NOMBRES  ('inter de milán' -> 'Inter de Milán')
% ---------------------------------------------------------------------
formato_especial(mls,    'MLS').
formato_especial(laliga, 'LaLiga').
formato_especial(fc,     'FC').
formato_especial(psg,    'PSG').

particula(de).  particula(del).  particula(la).  particula(el).  particula(y).

bonito(none, 'dato no disponible') :- !.
bonito(Atomo, Texto) :-
    atomic_list_concat(Palabras, ' ', Atomo),
    maplist(capitalizar, Palabras, Cap),
    atomic_list_concat(Cap, ' ', Texto).

capitalizar(P, C) :- formato_especial(P, C), !.
capitalizar(P, P) :- particula(P), !.
capitalizar(P, C) :-
    sub_atom(P, 0, 1, _, Primera), sub_atom(P, 1, _, 0, Resto),
    upcase_atom(Primera, Mayus), atom_concat(Mayus, Resto, C), !.
capitalizar(P, P).

% ---------------------------------------------------------------------
% 5. TEXTO DE LAS RESPUESTAS
% ---------------------------------------------------------------------

% --- 5.1 Ubicación: una frase por cada dato conocido ------------------
texto_ubicacion(no_existe(J), _, Texto) :-
    bonito(J, Nom),
    format(atom(Texto), '~w no está en mi base de datos.', [Nom]).
texto_ubicacion(ubicacion(J, E, L, P, S, N), Foco, Texto) :-
    bonito(J, Nom),
    findall(Frase, frase_dato(Foco, Nom, E, L, P, S, N, Frase), Frases),
    (   Frases == []
    ->  format(atom(Texto), 'No tengo ese dato de ~w en mi base.', [Nom])
    ;   atomic_list_concat(Frases, ' ', Texto)
    ).

% frase_dato(Foco, Nombre, Equipo, Liga, PaisClub, Estadio, Nac, Frase)
frase_dato(Foco, Nom, E, _, _, _, _, Frase) :-
    member(Foco, [todo, equipo]), dato_conocido(E), bonito(E, B),
    format(atom(Frase), '~w juega en ~w.', [Nom, B]).
frase_dato(Foco, _, _, L, _, _, _, Frase) :-
    member(Foco, [todo, liga]), dato_conocido(L), bonito(L, B),
    format(atom(Frase), 'Su liga es ~w.', [B]).
frase_dato(Foco, _, _, _, P, _, _, Frase) :-
    member(Foco, [todo, pais]), dato_conocido(P), bonito(P, B),
    format(atom(Frase), 'Su club está en ~w.', [B]).
frase_dato(Foco, _, _, _, _, S, _, Frase) :-
    member(Foco, [todo, estadio]), dato_conocido(S), bonito(S, B),
    format(atom(Frase), 'Juega de local en ~w.', [B]).
frase_dato(Foco, _, _, _, _, _, N, Frase) :-
    member(Foco, [todo, nacionalidad, pais]), dato_conocido(N), bonito(N, B),
    format(atom(Frase), 'Su nacionalidad es ~w.', [B]).

% --- 5.2 Relación entre dos jugadores ---------------------------------
descripcion_relacion(mismo_equipo,       'son compañeros de equipo').
descripcion_relacion(misma_liga,         'juegan en la misma liga').
descripcion_relacion(mismo_pais_club,    'sus clubes están en el mismo país').
descripcion_relacion(misma_nacionalidad, 'tienen la misma nacionalidad').

texto_relacion(relacion(A, B, Tipos), Texto) :-
    bonito(A, NA), bonito(B, NB),
    maplist(descripcion_relacion, Tipos, Descs),
    atomic_list_concat(Descs, '; ', Lista),
    format(atom(Texto), '~w y ~w: ~w.', [NA, NB, Lista]).
texto_relacion(sin_relacion(A, B), Texto) :-
    bonito(A, NA), bonito(B, NB),
    format(atom(Texto),
           'No encontré ninguna relación entre ~w y ~w con los datos de mi base.',
           [NA, NB]).
texto_relacion(mismo_jugador(A), Texto) :-
    bonito(A, NA),
    format(atom(Texto), 'Mencionaste solo a ~w; dame dos jugadores distintos.', [NA]).
texto_relacion(no_existe(J), Texto) :-
    bonito(J, N),
    format(atom(Texto), '~w no está en mi base de datos.', [N]).

% ---------------------------------------------------------------------
% 6. DECISIÓN
%    responder(+Pregunta, -Respuesta)                    <- uso simple
%    responder(+Pregunta, -Respuesta, -Jugadores, -Relaciones)
%        Jugadores  = nombres reconocidos (átomos)
%        Relaciones = resultados de consultar_relacion/3
% ---------------------------------------------------------------------
responder(Pregunta, Respuesta) :-
    responder(Pregunta, Respuesta, _, _).

responder(Pregunta, Respuesta, Jugadores, Relaciones) :-
    normalizar_texto(Pregunta, Tokens),
    jugadores_mencionados(Tokens, Jugadores),
    decidir(Tokens, Jugadores, Respuesta, Relaciones).

% (a) Dos o más jugadores -> relación entre cada par
%     (si no usó palabras de relación, también se muestra dónde juega cada uno)
decidir(Tokens, Jugadores, Respuesta, Relaciones) :-
    Jugadores = [_, _ | _], !,
    pares(Jugadores, Pares),
    findall(R, ( member(A-B, Pares), consultar_relacion(A, B, R) ), Relaciones),
    maplist(texto_relacion, Relaciones, TextosRel),
    (   tiene_clave(relacion, Tokens)
    ->  TextosUbic = []
    ;   foco_pregunta(Tokens, Foco),
        findall(T, ( member(J, Jugadores),
                     consultar_ubicacion(J, U),
                     texto_ubicacion(U, Foco, T) ), TextosUbic)
    ),
    append(TextosUbic, TextosRel, Textos),
    atomic_list_concat(Textos, ' ', Respuesta).

% (b) Un jugador, pero preguntan por una relación -> falta el otro
decidir(Tokens, [J], Respuesta, []) :-
    tiene_clave(relacion, Tokens), !,
    bonito(J, Nom), lista_jugadores(Lista),
    format(atom(Respuesta),
           'Solo reconozco a ~w en tu pregunta. Para una relación necesito dos jugadores de mi base. Conozco a: ~w.',
           [Nom, Lista]).

% (c) Un jugador -> dónde juega (según el foco de la pregunta)
decidir(Tokens, [J], Respuesta, []) :- !,
    foco_pregunta(Tokens, Foco),
    consultar_ubicacion(J, U),
    texto_ubicacion(U, Foco, Respuesta).

% (d) Saludo / ayuda
decidir(Tokens, [], Respuesta, []) :-
    tiene_clave(ayuda, Tokens), !,
    mensaje_ayuda(Respuesta).

% (e) Lista de jugadores
decidir(Tokens, [], Respuesta, []) :-
    tiene_clave(listar, Tokens), !,
    lista_jugadores(Lista),
    format(atom(Respuesta), 'Conozco a: ~w.', [Lista]).

% (f) Nada reconocido -> jugador fuera de la base o pregunta no entendida
decidir(_, [], Respuesta, []) :-
    lista_jugadores(Lista),
    format(atom(Respuesta),
           'No reconozco ningún jugador de mi base en tu pregunta (o no la entendí). Conozco a: ~w.',
           [Lista]).

% pares(+Lista, -Pares): todas las combinaciones A-B sin repetir.
pares(Lista, Pares) :-
    findall(A-B, ( append(_, [A | Resto], Lista), member(B, Resto) ), Pares).

% ---------------------------------------------------------------------
% 7. MENSAJES FIJOS
% ---------------------------------------------------------------------
mensaje_ayuda('Soy un bot de fútbol hecho en Prolog. Pregúntame dónde juega un jugador (equipo, liga, país y estadio) o qué relación hay entre dos jugadores. Ej: "¿Dónde juega Haaland?" o "¿Qué relación hay entre Messi y Lautaro Martínez?"').

lista_jugadores(Lista) :-
    findall(N, ( jugador(J, _, _, _, _, _), bonito(J, N) ), Nombres0),
    list_to_set(Nombres0, Nombres),
    atomic_list_concat(Nombres, ', ', Lista).

% ---------------------------------------------------------------------
% 8. CICLO DE CONSOLA     ?- chat.
% ---------------------------------------------------------------------
chat :-
    writeln('Chatbot de fútbol (Prolog). Escribe "salir" para terminar.'),
    ciclo_chat.

ciclo_chat :-
    write('Tú: '), flush_output,
    read_line_to_string(user_input, Linea),
    (   Linea == end_of_file
    ->  nl, writeln('Bot: ¡Hasta luego!')
    ;   es_salida(Linea)
    ->  writeln('Bot: ¡Hasta luego!')
    ;   responder(Linea, Respuesta),
        format('Bot: ~w~n', [Respuesta]),
        ciclo_chat
    ).

es_salida(Linea) :-
    normalizar_texto(Linea, [Palabra]),
    memberchk(Palabra, [salir, chao, adios, exit, quit, fin]).
