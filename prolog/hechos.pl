% =====================================================================
%  hechos.pl  --  BASE DE CONOCIMIENTO (solo datos, nada de lógica)
% =====================================================================
%  Formato IDÉNTICO al que exporta  GET /prolog/hechos  de FastAPI:
%
%     jugador(Nombre, Equipo, Liga, PaisClub, Estadio, Nacionalidad).
%
%  Reglas de edición (para no perderse en la presentación):
%    1. Todo en minúsculas y entre comillas simples:  'lionel messi'
%    2. Dato desconocido  ->  none   (sin comillas)
%    3. Un jugador = una línea. Para cambiar de equipo, editar esa línea.
%    4. Para agregar algo rápido, usar la sección 6 (ZONA DE PRUEBAS).
%
%  OJO: son datos de ejemplo; verificar fichajes/estadios actuales.
% =====================================================================

:- encoding(utf8).
:- dynamic jugador/6.         % dynamic: permite assertz/retract desde consola
:- discontiguous jugador/6.   % permite repartir los hechos en secciones

% ---------------------------------------------------------------------
% 1. LALIGA (España)
% ---------------------------------------------------------------------
jugador('kylian mbappé',    'real madrid',        'laliga', 'españa', 'santiago bernabéu',       'francia').
jugador('vinícius júnior',  'real madrid',        'laliga', 'españa', 'santiago bernabéu',       'brasil').
jugador('jude bellingham',  'real madrid',        'laliga', 'españa', 'santiago bernabéu',       'inglaterra').
jugador('julián álvarez',   'atlético de madrid', 'laliga', 'españa', 'riyadh air metropolitano', 'argentina').

% ---------------------------------------------------------------------
% 2. PREMIER LEAGUE (Inglaterra)
% ---------------------------------------------------------------------
jugador('erling haaland',   'manchester city', 'premier league', 'inglaterra', 'etihad stadium',  'noruega').
jugador('phil foden',       'manchester city', 'premier league', 'inglaterra', 'etihad stadium',  'inglaterra').
jugador('mohamed salah',    'liverpool',       'premier league', 'inglaterra', 'anfield',         'egipto').
jugador('alexis mac allister', 'liverpool',    'premier league', 'inglaterra', 'anfield',         'argentina').
jugador('bukayo saka',      'arsenal',         'premier league', 'inglaterra', 'emirates stadium', 'inglaterra').

% ---------------------------------------------------------------------
% 3. BUNDESLIGA (Alemania) y SERIE A (Italia)
% ---------------------------------------------------------------------
jugador('harry kane',       'bayern múnich',   'bundesliga', 'alemania', 'allianz arena', 'inglaterra').
jugador('lautaro martínez', 'inter de milán',  'serie a',    'italia',   'san siro',      'argentina').

% ---------------------------------------------------------------------
% 4. MLS, ARABIA SAUDITA y BRASIL
% ---------------------------------------------------------------------
jugador('lionel messi',      'inter miami', 'mls',               'estados unidos', 'chase stadium',   'argentina').
jugador('cristiano ronaldo', 'al nassr',    'saudi pro league',  'arabia saudita', 'al awwal park',   'portugal').
jugador('neymar',            'santos',      'brasileirão',       'brasil',         'vila belmiro',    'brasil').

% ---------------------------------------------------------------------
% 5. HECHOS PEGADOS DESDE  GET /prolog/hechos
%    (copiar y pegar aquí la salida del endpoint; mismo formato)
% ---------------------------------------------------------------------


% ---------------------------------------------------------------------
% 6. ZONA DE PRUEBAS  (agregar/cambiar aquí durante la evaluación)
%    Ejemplo con datos faltantes (usar none):
%    jugador('jugador de prueba', 'club x', none, none, none, 'chile').
% ---------------------------------------------------------------------

