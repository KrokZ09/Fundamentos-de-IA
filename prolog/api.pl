% =====================================================================
%  api.pl  --  PUENTE CON FASTAPI (stdin -> JSON por stdout)
% =====================================================================
%  main.py lo ejecuta así (una vez por pregunta):
%
%      swipl -q -s prolog/api.pl -g main_api -t halt
%
%  Entrada : la pregunta, por stdin (UTF-8). Sin problemas de comillas.
%  Salida  : un JSON con el MISMO formato que ChatOut de main.py:
%      {"answer": "...", "players": [...], "relations": [...]}
%
%  Requiere SWI-Prolog 9.x (library(http/json) viene incluida).
% =====================================================================

:- encoding(utf8).
:- use_module(library(http/json)).
:- ensure_loaded(chatbot).

main_api :-
    catch(ejecutar_api, Error,
          ( print_message(error, Error), halt(1) )).

ejecutar_api :-
    set_stream(user_input,  encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    read_string(user_input, _, Pregunta),
    responder(Pregunta, Respuesta, Jugadores, Relaciones),
    maplist(jugador_a_dict, Jugadores, DictsJugadores),
    convlist(relacion_a_dict, Relaciones, DictsRelaciones),
    json_write_dict(current_output,
                    _{ answer:    Respuesta,
                       players:   DictsJugadores,
                       relations: DictsRelaciones },
                    [width(0)]),
    nl.

% jugador/6 -> {"nombre", "equipo", "liga", "pais_club", "estadio", "nacionalidad"}
% (los datos 'none' salen como null, igual que en la versión Gemini)
jugador_a_dict(J, _{ nombre: Nombre, equipo: E, liga: L, pais_club: P,
                     estadio: S, nacionalidad: N }) :-
    once(jugador(J, E0, L0, P0, S0, N0)),
    bonito(J, Nombre),
    maplist(dato_json, [E0, L0, P0, S0, N0], [E, L, P, S, N]).

dato_json(none, null) :- !.
dato_json(Dato, Texto) :- bonito(Dato, Texto).

% relacion/3 o sin_relacion/2 -> {"jugadores": [A,B], "mismo_equipo": bool, ...}
% (convlist descarta los resultados no_existe/mismo_jugador)
relacion_a_dict(Rel, _{ jugadores: [NA, NB],
                        mismo_equipo: ME, misma_liga: ML,
                        mismo_pais_club: MP, misma_nacionalidad: MN }) :-
    datos_relacion(Rel, A, B, Tipos),
    bonito(A, NA), bonito(B, NB),
    bandera(mismo_equipo, Tipos, ME),
    bandera(misma_liga, Tipos, ML),
    bandera(mismo_pais_club, Tipos, MP),
    bandera(misma_nacionalidad, Tipos, MN).

datos_relacion(relacion(A, B, Tipos), A, B, Tipos).
datos_relacion(sin_relacion(A, B),    A, B, []).

bandera(Tipo, Tipos, true)  :- memberchk(Tipo, Tipos), !.
bandera(_, _, false).
