-- umi v8.1 (antes Mar Sintetizador) — versión simple
-- Personajes: Tucker (barco), Mobba (ballena), Lea (ave, solo por K2), Sean (el mar)
--
-- Al arrancar: la intro U-MA de partículas y después la pantalla "UMI";
-- luego arranca el instrumento. Cualquier tecla o encoder las saltea.
--
-- E1: Viento (altura de las olas y sonido del viento; no cambia la
--     velocidad de las notas: esa la da el reloj)
-- E2: Mueve a Tucker en X (transpone -8..+8 pasos de escala) — o mueve
--     a Lea mientras su solo está activo
-- E3: Mueve a Mobba en X (mismo efecto de transposición)
-- K1 (mantenido): abre el panel, una sola lista de 6 ajustes. E2 elige
--     y E3 cambia: tucker (off/Dream/Bell/Gauss), mobba (off/on), modo
--     (arp/gen, para los dos), escala, root, filter.
-- K2 (mantenido): Lea entra volando desde la izquierda, voz Blip
--     sostenida, generativo de 12 pasos; al soltar sale por la derecha.
-- K3: Mobba canta una nota; un instante después vuelve como eco, una
--     quinta más grave y apagada.
--
-- Tempo y sincronización: los del sistema (PARAMETERS > CLOCK). Con
-- source = midi, la velocidad la da el reloj MIDI que entra: el arpegio
-- cae en la grilla (Tucker en semicorcheas, Mobba en corcheas) y la ola
-- dura 8 pulsos justos. Ola que sube = notas ascendentes; baja = descendentes.
-- Los 6 ajustes del panel son parámetros (PARAMETERS > UMI): se pueden
-- mapear a MIDI, guardar en PSET, y el último estado se recuerda solo.
-- La versión completa anterior quedó en umi_v7.6_respaldo.lua.

engine.name = "Mar"

local MusicUtil = require("musicutil")

-- ============================================================
-- SPLASH: intro U-MA de partículas y luego "UMI", al arrancar el script
-- ============================================================
-- 1 = intro U-MA, 2 = pantalla UMI, 0 = listo, arranca el instrumento
local uma_intro = include("lib/uma_splash_particles")
local uma_sound = include("lib/uma_splash") -- base de la intro, maneja el sonido
local SPLASH_IN, SPLASH_HOLD, SPLASH_FADE = 0.5, 1.6, 0.7
local splash_phase = 1
local splash_t0 = nil
local splash_held = {}

local function splash_elapsed() return util.time() - (splash_t0 or util.time()) end

function splash_update()
  if splash_phase == 0 then return end
  local e = splash_elapsed()
  if e < uma_intro.DUR then splash_phase = 1
  elseif e < uma_intro.DUR + SPLASH_IN + SPLASH_HOLD + SPLASH_FADE then splash_phase = 2
  else splash_phase = 0 end
end

function splash_skip()
  if splash_phase == 1 then uma_sound.sound_off() end
  splash_phase = 0
end

function draw_umi_splash(alpha)
  local function L(l) return math.max(0, math.floor(l * alpha + 0.5)) end
  screen.level(L(15))
  screen.font_size(16)
  screen.move(64, 36)
  screen.text_center("UMI")
  screen.font_size(8)
  -- una ola chiquita que pasa debajo del título
  screen.level(L(6))
  local ph = util.time() * 7.5
  for x = 44, 84 do
    screen.pixel(x, 44 + math.floor(math.sin(x * 0.3 + ph) * 1.2 + 0.5))
  end
  screen.fill()
end

-- ============================================================
-- ESTADO GLOBAL DE ESCALA / TEMPO / MAREA
-- ============================================================
-- Nombres confirmados contra la fuente real de musicutil.lua (mark_eats):
-- "Hirajoshi" no existe ahí, y era "Pentatonic Minor" al revés (es
-- "Minor Pentatonic"). Esta lista usa únicamente nombres reales.
local scale_names = {
  "Major", "Natural Minor", "Harmonic Minor", "Melodic Minor",
  "Dorian", "Phrygian", "Lydian", "Mixolydian", "Locrian",
  "Whole Tone", "Major Pentatonic", "Minor Pentatonic",
  "Blues Scale", "Gypsy Minor"
}
local current_scale = 2

local root_note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local root_pc = 0 -- 0=C .. 11=B, siempre dentro de la misma octava base
local ROOT_OCTAVE_BASE = 48 -- C3
local root_note = ROOT_OCTAVE_BASE + root_pc
local notes_in_scale = {}

local wind_speed = 1.0 -- gobierna la intensidad visual del mar/viento, no la velocidad musical
local clock_counter = 0
local parallax_offset = 0

local current_tempo_mult = 1.0

-- ============================================================
-- TEMPO: reloj global de norns (PARAMETERS > CLOCK)
-- ============================================================
-- Una ola completa dura 8 pulsos justos (2 compases de 4/4), así el
-- dibujo y el arpegio quedan enganchados al reloj (interno o MIDI).
local SEA_PHASE_PER_BEAT = (2 * math.pi) / 8

function get_tempo_mult()
  return clock.get_tempo() / 120
end

local filter_cutoff = 3000 -- Hz, compartido por los 3 filtros de personaje (tope 5000)

-- ============================================================
-- PANEL (K1)
-- ============================================================
local entity_order = {"boat", "whale"}

local zoom_held = false -- true mientras K1 está mantenido
local menu_slide = 0    -- 0 = panel oculto, 1 = panel totalmente desplegado
local MENU_SLIDE_SPEED = 0.12

local selected_item_idx = 1

-- ============================================================
-- ENTIDADES
-- ============================================================
local entities = {
  boat = {
    phase = 0, y_pos = 36, x_pos = 64, x_target = 64, pulse = 0,
    prev_note = -1, prev_step = -1,
    on = true, mode = "arp", steps = 16, max_steps = 16,
    synth_idx = 1, synth_names = {"Dream", "Bell", "Gauss"},
    default_release = 0.4,
    walk_note_idx = 1, walk_dir = 1, walk_phrase_len = 4, gen_wait = 0,
    last_idx = nil
  },
  whale = {
    phase = 2.0, y_pos = 50, x_pos = 64, x_target = 64, swim_phase = 0,
    prev_note = -1, prev_step = -1,
    on = true, mode = "arp", steps = 8, max_steps = 8,
    default_release = 0.8,
    walk_note_idx = 1, walk_dir = 1, walk_phrase_len = 4, gen_wait = 0,
    last_idx = nil
  }
}

-- El panel: una sola lista fija. Cada ítem es un parámetro (id).
local panel_items = {
  {id = "tucker", label = "tucker"},
  {id = "mobba", label = "mobba"},
  {id = "modo", label = "modo"},
  {id = "sea_scale", label = "escala"},
  {id = "sea_root", label = "root"},
  {id = "sea_filter", label = "filter"},
}

local wing_phase = 0

-- ============================================================
-- MODO SOLO DE LEA (K2 en la página Mar) — Lea ya no tiene página
-- propia ni comportamiento autónomo: solo existe como este solo.
-- ============================================================
-- Mientras se mantiene K2 apretado en la página Mar: entra volando
-- despacio desde la izquierda, voz Blip sostenida propia, generativo de 12
-- pasos con legato, y E2 controla su posición en X (que transpone el
-- generativo, igual que con Tucker). Al soltar K2, sale despacio por
-- la derecha.
local LEA_SOLO_ENTER_X = -20
local LEA_SOLO_EXIT_X = 148
local LEA_SOLO_CENTER_X = 64
local LEA_SOLO_EASE = 0.035 -- más lento que Tucker (0.09), entrada/salida grácil
local lea_solo = {
  active = false,
  x = LEA_SOLO_ENTER_X, x_target = LEA_SOLO_CENTER_X,
  y_pos = 15, phase = 4.0,
  gen_wait = 0,
  walk_note_idx = 1, walk_dir = 1, walk_phrase_len = 4,
  prev_note = -1
}

-- ============================================================
-- ECO DE MOBBA (K3 en la página Mar)
-- ============================================================
-- Un toque dispara una nota; un instante después esa misma nota vuelve
-- como un eco (una quinta más grave, más apagado), como si el mar se
-- la devolviera. No suspende ni interrumpe su arp/gen normal.
local ECHO_DELAY_SEC = 0.6
local ECHO_INTERVAL_DOWN = 7 -- semitonos (quinta) más grave para el eco
local ECHO_AMP_SCALE = 0.45
local echo = {
  pending = false,
  note = nil,
  at = 0 -- util.time() en que vuelve el eco
}

-- Nubes
local clouds = {
  {x = -20, base_y = 3, y = 3, w = 18, base_speed = 0.15, phase = 0.0},
  {x = 50,  base_y = 5, y = 5, w = 22, base_speed = 0.20, phase = 2.1},
  {x = 100, base_y = 2, y = 2, w = 14, base_speed = 0.10, phase = 4.3}
}

-- Burbujas
local bubbles = {}
for i = 1, 16 do
  table.insert(bubbles, {
    x = math.random(2, 126),
    y = math.random(38, 63),
    speed = 0.15 + math.random() * 0.25,
    wobble = math.random() * 6.28,
    level = math.random(1, 4)
  })
end

-- Partículas
local particles = {}

function add_particle(x, y, vx, vy, life, kind)
  table.insert(particles, {x = x, y = y, vx = vx, vy = vy, life = life, max_life = life, kind = kind})
end

function update_particles()
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    p.life = p.life - 1
    if p.life <= 0 then
      table.remove(particles, i)
    end
  end
end

-- ============================================================
-- INICIALIZACIÓN
-- ============================================================
-- ============================================================
-- PARÁMETROS (menú PARAMETERS > MAR): los paneles leen y escriben acá
-- ============================================================
local STATE_FILE = nil -- se arma en init (carpeta data del script)
local music_clock_id = nil
local arp_clock_id = nil

local function add_mar_params()
  params:add_group("UMI", 6)

  local tucker_opts = {"OFF"}
  for _, name in ipairs(entities.boat.synth_names) do table.insert(tucker_opts, name) end
  params:add_option("tucker", "tucker", tucker_opts, 2)
  params:set_action("tucker", function(v)
    entities.boat.on = (v > 1)
    if v > 1 then entities.boat.synth_idx = v - 1 end
  end)
  params:add_option("mobba", "mobba", {"OFF", "ON"}, 2)
  params:set_action("mobba", function(v) entities.whale.on = (v == 2) end)
  params:add_option("modo", "modo", {"arp", "gen"}, 1)
  params:set_action("modo", function(v)
    local mode = (v == 1) and "arp" or "gen"
    entities.boat.mode = mode
    entities.whale.mode = mode
  end)
  params:add_option("sea_scale", "escala", scale_names, 2)
  params:set_action("sea_scale", function(v)
    current_scale = v
    build_scale()
  end)
  params:add_option("sea_root", "root", root_note_names, 1)
  params:set_action("sea_root", function(v)
    root_pc = v - 1
    root_note = ROOT_OCTAVE_BASE + root_pc
    build_scale()
  end)
  params:add_control("sea_filter", "filter", controlspec.new(100, 5000, "exp", 1, 3000, "Hz"))
  params:set_action("sea_filter", function(v)
    filter_cutoff = v
    engine.set_filter_cutoff(v)
  end)
end

-- Reloj musical: corre aparte de la pantalla, ~100 veces por segundo,
-- y avanza según los pulsos reales del clock de norns.
local function start_music_clock()
  music_clock_id = clock.run(function()
    local last = clock.get_beats()
    while true do
      clock.sleep(1 / 100)
      local now = clock.get_beats()
      local db = now - last
      last = now
      -- saltos del reloj (reset de transporte, cambio de fuente): ignorar
      if db < 0 or db > 1 then db = 0 end
      music_tick(db)
    end
  end)
end

-- Reloj del arpegio: despierta justo en cada semicorchea del reloj de
-- norns (interno, MIDI, Link...). Tucker toca en todas; Mobba, una por
-- medio (corcheas). Si el transporte MIDI se detiene, se detiene.
local function start_arp_clock()
  arp_clock_id = clock.run(function()
    while true do
      clock.sync(1 / 4)
      local sixteenth = math.floor(clock.get_beats() * 4 + 0.5)
      arp_tick(sixteenth % 2 == 0)
    end
  end)
end

-- ============================================================
-- INICIALIZACIÓN
-- ============================================================
function init()
  build_scale()

  local mid_idx = math.floor(#notes_in_scale / 2) + 1
  for _, name in ipairs(entity_order) do
    entities[name].walk_note_idx = mid_idx
  end

  add_mar_params()
  STATE_FILE = norns.state.data .. "umi_estado.pset"
  if util.file_exists(STATE_FILE) then
    params:read(STATE_FILE)
  end
  params:bang()
  params:set("reverb", 2) -- arranca con el reverb de norns encendido

  uma_sound.sound_on(norns.state.path .. "lib/uma_particles.wav")
  splash_t0 = util.time()
  -- Si un dibujo tarda más que el cuadro, los avisos del metro se
  -- encolan; en vez de dibujar uno atrás del otro (y dejar sin aire al
  -- reloj musical), ese cuadro atrasado solo actualiza la animación.
  local last_draw_end = 0
  local redraw_metro = metro.init(function()
    update_physics()
    if util.time() - last_draw_end < 0.004 then return end
    redraw()
    last_draw_end = util.time()
  end, 1/30)
  redraw_metro:start()

  start_music_clock()
  start_arp_clock()

  engine.set_wind(0.012, 350)
end

-- Al salir del script: se guarda el estado de los parámetros
function cleanup()
  if music_clock_id then clock.cancel(music_clock_id) end
  if arp_clock_id then clock.cancel(arp_clock_id) end
  if STATE_FILE then
    util.make_dir(norns.state.data)
    params:write(STATE_FILE)
  end
end

function build_scale()
  notes_in_scale = MusicUtil.generate_scale_of_length(root_note, scale_names[current_scale], 24)
end

-- ============================================================
-- NOTAS: PASEO ARMÓNICO (usado por modo "gen")
-- ============================================================
-- headroom: cuántos pasos de margen dejar en cada punta para que, al
-- sumarle después un transpose (Tucker/Lea usan x_to_transpose, hasta
-- ±8), el resultado nunca necesite recortarse — evita que muchos
-- estados internos distintos del paseo colapsen en la misma nota tope
-- cuando el transpose está al máximo. 0 = sin margen.
function next_harmonic_index(entity, headroom)
  headroom = headroom or 0
  local min_idx = 1 + headroom
  local max_idx = math.max(min_idx, #notes_in_scale - headroom)

  entity.walk_phrase_len = entity.walk_phrase_len - 1
  if entity.walk_phrase_len <= 0 then
    entity.walk_dir = -entity.walk_dir
    entity.walk_phrase_len = math.random(3, 8)
  end

  local step_size = math.random(1, 3) * entity.walk_dir
  local new_idx = entity.walk_note_idx + step_size

  if new_idx < min_idx then
    new_idx = min_idx
    entity.walk_dir = 1
    entity.walk_phrase_len = math.random(3, 8)
  elseif new_idx > max_idx then
    new_idx = max_idx
    entity.walk_dir = -1
    entity.walk_phrase_len = math.random(3, 8)
  end

  entity.walk_note_idx = new_idx
  return new_idx
end

-- ============================================================
-- DISPARO DE SONIDO UNIFICADO (arp y gen llegan acá)
-- ============================================================

function trigger_entity_sound(entity, entity_name, note, release, amp_scale, spout_boost)
  amp_scale = amp_scale or 1.0
  spout_boost = spout_boost or 1.0
  local freq = MusicUtil.note_num_to_freq(note)

  if entity_name == "boat" then
    engine.boat_note(freq, 0.3 * amp_scale, entity.synth_idx, release)
    entity.pulse = 1.0
    add_particle(entity.x_pos + 1, entity.y_pos - 12, (math.random() - 0.5) * 0.5, -0.6, 25, "note_spark")
    add_particle(entity.x_pos - 3, entity.y_pos - 4, (math.random() - 0.8) * 0.3, -0.4, 20, "smoke")
  elseif entity_name == "whale" then
    engine.whale_note(freq * 0.5, 0.4 * amp_scale, release)
    -- spout_boost > 1 da una estela más alta (sube más rápido) y más
    -- sostenida (vive más tiempo, más partículas) — se usa en el
    -- canto/eco de K3, no en sus notas normales de arp/gen.
    local spout_count = math.floor(6 * spout_boost)
    for p = 1, spout_count do
      add_particle(
        entity.x_pos + 5 + (math.random() - 0.5) * 1.8,
        entity.y_pos - 4,
        (math.random() - 0.5) * 0.3,
        (-0.75 - (math.random() * 0.35)) * spout_boost,
        math.floor((16 + math.random(0, 6)) * spout_boost),
        "spout"
      )
    end
  end
end

-- ============================================================
-- MODO ARP
-- ============================================================
-- Tucker: la posición X (controlada por E2 en la página Mar) transpone
-- el arpegio -8..+8 pasos de escala, sumado al índice que ya sale de la
-- altura de la ola. La ola da la forma: mientras sube en pantalla las
-- notas suben, mientras baja, bajan; la mano en el encoder decide en qué
-- registro suena esa forma. norm_y: 0 = valle, 1 = cresta.
local BOAT_X_MIN, BOAT_X_MAX = 16, 112
local function x_to_transpose(x)
  local norm = util.clamp((x - BOAT_X_MIN) / (BOAT_X_MAX - BOAT_X_MIN), 0, 1)
  return math.floor((norm * 16) - 8 + 0.5)
end

function process_arp_note(entity, entity_name, norm_y)
  local total_steps = entity.max_steps
  local step = math.floor(norm_y * math.max(0, total_steps - 1))

  if step ~= entity.prev_step then
    entity.prev_step = step
    local mapped_idx = math.floor((step / math.max(1, total_steps - 1)) * (#notes_in_scale - 1)) + 1

    if entity_name == "boat" or entity_name == "whale" then
      mapped_idx = util.clamp(mapped_idx + x_to_transpose(entity.x_pos), 1, #notes_in_scale)
    end

    local note = notes_in_scale[mapped_idx]
    entity.last_idx = mapped_idx

    if note ~= entity.prev_note then
      entity.prev_note = note
      trigger_entity_sound(entity, entity_name, note, entity.default_release)
    end
  end
end

-- ============================================================
-- MODO GEN
-- ============================================================
local GEN_SILENCE_CHANCE = 0.25
local GEN_MIN_DUR, GEN_MAX_DUR = 0.08, 1.2

-- beats: pulsos transcurridos desde el último tick. Intervalo base =
-- 4/pasos pulsos (Tucker 16 pasos: una semicorchea; Mobba 8: una
-- corchea), con la misma variación aleatoria 0.6x-1.6x de antes.
-- La nota sale de la altura de la ola (norm_y: 0 = valle, 1 = cresta),
-- igual que en arp: ola que sube = notas que suben. Lo generativo queda
-- en el ritmo irregular, los silencios y las duraciones. Se mueve en la
-- franja central de la escala (8 pasos de margen por punta) para que el
-- transpose de E2/E3 nunca tenga que recortarse.
local GEN_HEADROOM = 8
function process_gen_note(entity, entity_name, beats, norm_y)
  entity.gen_wait = entity.gen_wait - beats
  if entity.gen_wait > 0 then return end
  entity.gen_wait = (4 / entity.max_steps) * (0.6 + math.random())

  if math.random() < GEN_SILENCE_CHANCE then return end

  local min_idx = 1 + GEN_HEADROOM
  local max_idx = math.max(min_idx, #notes_in_scale - GEN_HEADROOM)
  local idx = min_idx + math.floor(norm_y * (max_idx - min_idx) + 0.5)
  if idx == entity.walk_note_idx then return end -- la ola no cambió de escalón
  entity.walk_note_idx = idx
  idx = util.clamp(idx + x_to_transpose(entity.x_pos), 1, #notes_in_scale)
  entity.last_idx = idx
  local note = notes_in_scale[idx]
  local dur = GEN_MIN_DUR + math.random() * (GEN_MAX_DUR - GEN_MIN_DUR)
  trigger_entity_sound(entity, entity_name, note, dur)
end

-- El modo gen avanza con el reloj musical; el arp, con arp_tick.
function process_entity_note(entity_name, beats, norm_y)
  local entity = entities[entity_name]
  if not entity.on then return end
  if entity.mode ~= "arp" then
    process_gen_note(entity, entity_name, beats, norm_y)
  end
end

-- ============================================================
-- MAR
-- ============================================================
local SEA_BASE_Y = 35
local SEA_WAVELENGTH = 0.08
local SEA_AMPLITUDE = 3.5

function sea_wave_signal(x)
  local primary = math.sin(clock_counter + (x * SEA_WAVELENGTH))
  local secondary = math.sin((clock_counter * 2.1) + (x * SEA_WAVELENGTH * 1.5) + 1.2) * 0.35
  return (primary + secondary) / 1.35
end

function sea_surface_y(x)
  return SEA_BASE_Y + sea_wave_signal(x) * (SEA_AMPLITUDE * wind_speed)
end

-- ============================================================
-- FÍSICA / ACTUALIZACIÓN POR FRAME
-- ============================================================
-- ------------------------------------------------------------
-- MÚSICA: se llama desde el reloj musical. beats = pulsos del clock
-- transcurridos desde el tick anterior.
-- ------------------------------------------------------------
function music_tick(beats)
  if splash_phase > 0 then return end

  current_tempo_mult = util.clamp(get_tempo_mult(), 0.1, 6)
  local sea_beats = beats

  -- la fase del mar sigue al pulso real
  clock_counter = clock_counter + beats * SEA_PHASE_PER_BEAT

  -- Tucker: sigue la ola; acá solo el modo gen (cresta = nota aguda:
  -- en pantalla "arriba" es y menor, por eso la señal va invertida)
  local boat_x = entities.boat.x_pos
  entities.boat.y_pos = sea_surface_y(boat_x)
  process_entity_note("boat", sea_beats, (1 - sea_wave_signal(boat_x)) / 2)

  -- Mobba
  local whale_sin = math.sin(clock_counter + entities.whale.phase)
  entities.whale.y_pos = 50 + whale_sin * 3.5
  process_entity_note("whale", sea_beats, (1 - whale_sin) / 2)

  -- Eco de Mobba (K3)
  if echo.pending and util.time() >= echo.at then
    if entities.whale.on then
      trigger_entity_sound(entities.whale, "whale", echo.note - ECHO_INTERVAL_DOWN, 1.5, ECHO_AMP_SCALE, 2.2)
    end
    echo.pending = false
  end

  -- Lea (solo de K2): generativo de 12 pasos
  if lea_solo.active then
    lea_solo.gen_wait = lea_solo.gen_wait - sea_beats
    if lea_solo.gen_wait <= 0 then
      lea_solo.gen_wait = (4 / 12) * (0.6 + math.random())
      if math.random() >= GEN_SILENCE_CHANCE then
        local idx = next_harmonic_index(lea_solo, 8)
        idx = util.clamp(idx + x_to_transpose(lea_solo.x), 1, #notes_in_scale)
        local note = notes_in_scale[idx]
        engine.lea_solo_freq(MusicUtil.note_num_to_freq(note) * 2)
        add_particle(lea_solo.x, lea_solo.y_pos, -0.8, (math.random() - 0.5) * 0.2, 28, "spark")
      end
    end
  end
end

-- ------------------------------------------------------------
-- ARPEGIO: se llama en cada semicorchea del reloj (ver start_arp_clock).
-- La altura en pantalla decide la nota: en pantalla "arriba" es y menor,
-- por eso la señal va invertida (cresta = nota más aguda).
-- ------------------------------------------------------------
function arp_tick(on_eighth)
  if splash_phase > 0 then return end

  local boat = entities.boat
  if boat.on and boat.mode == "arp" then
    process_arp_note(boat, "boat", (1 - sea_wave_signal(boat.x_pos)) / 2)
  end

  local whale = entities.whale
  if on_eighth and whale.on and whale.mode == "arp" then
    local whale_sin = math.sin(clock_counter + whale.phase)
    process_arp_note(whale, "whale", (1 - whale_sin) / 2)
  end
end

-- ------------------------------------------------------------
-- PANTALLA: se llama a 30 fps; solo animación, nada de notas.
-- ------------------------------------------------------------
function update_physics()
  splash_update()
  if splash_phase > 0 then return end

  parallax_offset = (parallax_offset + 0.08 * wind_speed) % 128

  update_particles()

  if entities.boat.pulse > 0 then
    entities.boat.pulse = math.max(0, entities.boat.pulse - 0.08)
  end

  wing_phase = wing_phase + 0.5 * current_tempo_mult
  entities.whale.swim_phase = entities.whale.swim_phase + 0.12 * current_tempo_mult

  -- Animación del panel (K1)
  if zoom_held then
    menu_slide = math.min(1, menu_slide + MENU_SLIDE_SPEED)
  else
    menu_slide = math.max(0, menu_slide - MENU_SLIDE_SPEED)
  end

  for _, c in ipairs(clouds) do
    c.phase = c.phase + 0.02 * wind_speed
    local speed_variation = c.base_speed + math.sin(c.phase) * 0.05
    c.x = c.x + speed_variation * wind_speed
    c.y = c.base_y + math.sin(c.phase * 0.7) * 1.5
    if c.x > 135 then
      c.x = -c.w - 5
      c.base_y = math.random(2, 6)
    end
  end

  for _, b in ipairs(bubbles) do
    b.y = b.y - b.speed
    b.wobble = b.wobble + 0.06
    if b.y < SEA_BASE_Y + 4 then
      b.y = 63
      b.x = math.random(2, 126)
    end
  end

  -- Tucker y Mobba se deslizan suave hacia el objetivo que fijan E2/E3
  entities.boat.x_pos = entities.boat.x_pos + (entities.boat.x_target - entities.boat.x_pos) * 0.09
  entities.whale.x_pos = entities.whale.x_pos + (entities.whale.x_target - entities.whale.x_pos) * 0.09

  -- Lea: vuelo (posición y altura); sus notas van en music_tick
  if lea_solo.active then
    lea_solo.x = lea_solo.x + (lea_solo.x_target - lea_solo.x) * LEA_SOLO_EASE
    local solo_bird_sin = math.sin(clock_counter * 1.2 + lea_solo.phase)
    lea_solo.y_pos = 13 + solo_bird_sin * 5

    -- terminó de salir de cuadro por la derecha: apaga la voz
    if lea_solo.x_target == LEA_SOLO_EXIT_X and lea_solo.x > 128 then
      lea_solo.active = false
      engine.set_lea_solo(0, 0)
    end
  end
end

-- ============================================================
-- DIBUJO: PÁGINA "MAR"
-- ============================================================
local function rotate_pt(px, py, angle)
  local cos_a = math.cos(angle)
  local sin_a = math.sin(angle)
  return px * cos_a - py * sin_a, px * sin_a + py * cos_a
end

-- Polígono rotado alrededor de (bx, wl): el casco se dibuja como una
-- sola figura en vez de líneas sueltas, así no se "rompe" al inclinarse.
local function rot_poly(bx, wl, ang, pts, fill)
  for i, p in ipairs(pts) do
    local rx, ry = rotate_pt(p[1], p[2], ang)
    if i == 1 then screen.move(bx + rx, wl + ry) else screen.line(bx + rx, wl + ry) end
  end
  screen.close()
  if fill then screen.fill() else screen.stroke() end
end

-- Dibujo del barco, parametrizado por posición (bx, waterline) e
-- inclinación (slope_angle) — se usa tanto en la escena viva (siguiendo
-- la ola real) como recentrado dentro del panel.
local HULL = {{-7, -4}, {8, -4}, {10, -6}, {6, 0}, {-5, 0}}
local MAST_H = -14
local FLAG = {{0, MAST_H}, {-4, MAST_H + 1}, {0, MAST_H + 2}}
local SAIL = {{1, MAST_H + 2}, {6, -6}, {1, -5}}
local JIB = {{-1, MAST_H + 4}, {-4, -6}, {-1, -5}}

function draw_boat_sprite(bx, waterline, slope_angle)
  local pulse = entities.boat.pulse

  -- estela: unos pocos puntitos detrás del casco, más con más viento
  screen.level(3)
  local wake_n = math.floor(wind_speed * 2)
  for i = 1, wake_n do
    local wx = bx - 7 - i * 3 - math.floor((clock_counter * 6) % 3)
    screen.pixel(wx, math.floor(sea_surface_y(wx)) + 1)
  end
  screen.fill()

  -- casco: textura dither (damero) + borde brillante (late con cada nota)
  local hull = HULL
  screen.level(math.floor(6 + pulse * 6))
  local ca, sa = math.cos(-slope_angle), math.sin(-slope_angle)
  local ibx, iwl = math.floor(bx), math.floor(waterline)
  for py = iwl - 8, iwl + 2 do
    for px = ibx - 9, ibx + 11 do
      if (px + py) % 2 == 0 then
        -- pixel de pantalla -> coordenadas locales del casco
        local dx, dy = px + 0.5 - bx, py + 0.5 - waterline
        local lx, ly = dx * ca - dy * sa, dx * sa + dy * ca
        if ly > -3.5 and ly < -0.5 then
          local t = (ly + 4) / 4
          if lx > -7 + 2 * t + 0.5 and lx < 8 - 2 * t - 0.5 then
            screen.pixel(px, py)
          end
        end
      end
    end
  end
  screen.fill()
  screen.level(math.floor(11 + pulse * 4))
  screen.line_width(1)
  rot_poly(bx, waterline, slope_angle, hull, false)

  -- mástil
  local mast_h = MAST_H
  local m1x, m1y = rotate_pt(0, -4, slope_angle)
  local m2x, m2y = rotate_pt(0, mast_h, slope_angle)
  screen.move(bx + m1x, waterline + m1y)
  screen.line(bx + m2x, waterline + m2y)
  screen.stroke()

  -- banderín
  screen.level(15)
  local flag_wave = math.sin(clock_counter * 6) > 0 and 1 or 0
  FLAG[2][2] = mast_h + 1 + flag_wave
  rot_poly(bx, waterline, slope_angle, FLAG, true)

  -- vela mayor y foque (como antes)
  screen.level(14)
  local sail_wind = math.floor(wind_speed * 0.8)
  SAIL[2][1] = 6 + sail_wind
  rot_poly(bx, waterline, slope_angle, SAIL, true)
  screen.level(7)
  JIB[2][1] = -4 - math.floor(wind_speed * 0.4)
  rot_poly(bx, waterline, slope_angle, JIB, true)
end

-- Dibujo de la ballena, parametrizado por posición (wx, wy) — misma
-- silueta de siempre pero redondeada en una sola figura.
function draw_whale_sprite(wx, wy)
  local swim_off = math.sin(entities.whale.swim_phase) * 1.5

  -- cuerpo (el de la versión anterior)
  screen.level(12)
  screen.rect(wx + 4, wy - 3, 10, 6)
  screen.rect(wx - 6, wy - 2, 10, 4)
  screen.rect(wx - 11, wy - 1 + math.floor(swim_off * 0.5), 5, 2)
  screen.fill()

  screen.level(15)
  screen.move(wx + 13, wy + 2)
  screen.line(wx - 2, wy + 2)
  screen.stroke()
  screen.move(wx + 10, wy + 1)
  screen.line(wx, wy + 1)
  screen.stroke()

  screen.level(0)
  screen.pixel(wx + 11, wy - 1)
  screen.fill()

  -- cola con aleta en V que acompaña el nado
  screen.level(12)
  local tail_y = wy + swim_off
  screen.move(wx - 11, wy)
  screen.line(wx - 15, tail_y - 1)
  screen.stroke()
  screen.move(wx - 15, tail_y - 1)
  screen.line(wx - 19, tail_y - 5)
  screen.line(wx - 17, tail_y - 1)
  screen.line(wx - 19, tail_y + 2)
  screen.close()
  screen.fill()

  -- aleta pectoral
  local fin_swing = math.sin(entities.whale.swim_phase * 0.8) * 1.2
  screen.move(wx + 3, wy + 2)
  screen.line(wx - 1, wy + 5 + fin_swing)
  screen.line(wx + 1, wy + 2)
  screen.close()
  screen.fill()
end

-- Estrellas fijas del cielo (titilan muy tenues)
local stars = {{8, 12}, {23, 4}, {37, 15}, {61, 9}, {79, 3}, {92, 14}, {121, 18}}
local MOON_X, MOON_Y = 112, 9

local function draw_sky()
  -- estrellas (agrupadas por brillo: un solo fill por nivel)
  for lv = 1, 3 do
    local any = false
    for i, st in ipairs(stars) do
      if math.floor(2 + math.sin(clock_counter * 0.7 + i * 1.9) * 1.5) == lv then
        if not any then screen.level(lv); any = true end
        screen.pixel(st[1], st[2])
      end
    end
    if any then screen.fill() end
  end

  -- luna creciente
  screen.level(9)
  screen.circle(MOON_X, MOON_Y, 4.5)
  screen.fill()
  screen.level(0)
  screen.circle(MOON_X + 2.5, MOON_Y - 1.5, 4)
  screen.fill()

  -- nubes con forma redondeada (bultos arriba, base más clara)
  screen.level(3)
  for _, c in ipairs(clouds) do
    local cx = math.floor((c.x - parallax_offset * 0.15) % 140 - 10)
    local cy = math.floor(c.y)
    screen.rect(cx, cy, c.w, 2)
    screen.rect(cx + 3, cy - 1, math.floor(c.w * 0.45), 1)
    screen.rect(cx + math.floor(c.w * 0.5), cy - 2, math.floor(c.w * 0.3), 2)
  end
  screen.fill()
  screen.level(1)
  for _, c in ipairs(clouds) do
    local cx = math.floor((c.x - parallax_offset * 0.15) % 140 - 10)
    screen.rect(cx + 2, math.floor(c.y) + 2, c.w - 4, 1)
  end
  screen.fill()
end

-- pececitos: entran por un costado, cruzan y vuelven a salir
local fishes = {}
function reset_fish(f)
  f.dir = (math.random() < 0.5) and 1 or -1
  f.x = (f.dir == 1) and -6 - math.random(0, 80) or 134 + math.random(0, 80)
  f.y = math.random(43, 58)
  f.speed = 0.25 + math.random() * 0.3
  f.level = math.random(3, 6)
end
for i = 1, 3 do
  local f = {}
  reset_fish(f)
  table.insert(fishes, f)
end

-- ------------------------------------------------------------
-- El agua se arma en un buffer de píxeles y va a la pantalla con UNA
-- sola llamada (screen.poke), en vez de cientos de screen.pixel: cada
-- llamada de pantalla cuesta, y de a ratos norns las atiende mucho más
-- lento; con ~1600 por cuadro el dibujo no llegaba a tiempo y trababa
-- también al reloj musical.
-- El buffer cubre las filas WATER_Y0..63 (la ola nunca sube más que eso).
-- ------------------------------------------------------------
local WATER_Y0 = 26
local WATER_H = 64 - WATER_Y0
local LV = {}
for l = 0, 15 do LV[l] = string.char(l) end
local wbuf = {}
for i = 1, 128 * WATER_H do wbuf[i] = LV[0] end
local wdirty, wdirty_n = {}, 0

local function wset(x, y, l)
  if x < 0 or x > 127 or y < WATER_Y0 or y > 63 then return end
  local i = (y - WATER_Y0) * 128 + x + 1
  wdirty_n = wdirty_n + 1
  wdirty[wdirty_n] = i
  wbuf[i] = LV[l]
end

-- superficie del mar de este cuadro: altura y señal, por columna
local SY, SIG = {}, {}
local ALGAE_X = {14, 41, 99}
-- pececito mirando a la derecha (dx, dy); (0,0) queda apagado: es el ojo
local FISH_BODY = {
  {-2, -1}, {-1, -1}, {0, -1},
  {-3, 0}, {-2, 0}, {-1, 0}, {1, 0},
  {-2, 1}, {-1, 1}, {0, 1},
}

local function draw_sea()
  local cc = clock_counter
  local amp = SEA_AMPLITUDE * wind_speed
  local sin, floor = math.sin, math.floor

  for x = 0, 128 do
    local sg = (sin(cc + x * SEA_WAVELENGTH) + sin(cc * 2.1 + x * SEA_WAVELENGTH * 1.5 + 1.2) * 0.35) / 1.35
    SIG[x] = sg
    SY[x] = SEA_BASE_Y + sg * amp
  end

  -- limpiar lo que se pintó en el buffer el cuadro anterior
  for k = 1, wdirty_n do wbuf[wdirty[k]] = LV[0] end
  wdirty_n = 0

  -- agua: dither tenue debajo de la superficie, más denso arriba y que
  -- se va apagando hacia el fondo (separa el mar del cielo). Es el mismo
  -- patrón Bayer 4x4 de antes, recorriendo solo los puntos que prenden.
  local wscroll = floor(cc * 3)
  for x = 0, 127 do
    local c = (x + wscroll) % 4
    if c == 0 or c == 2 then
      local top = floor(SY[x]) + 3
      local span = 64 - top
      if c == 0 then
        local lim = top + span * 0.65
        for y = top + ((0 - top) % 4), 63, 4 do
          if y >= lim then break end
          wset(x, y, 1)
        end
      else
        local lim = top + span * 0.15
        for y = top + ((0 - top) % 4), 63, 4 do
          if y >= lim then break end
          wset(x, y, 1)
        end
        lim = top + span * 0.4
        for y = top + ((2 - top) % 4), 63, 4 do
          if y >= lim then break end
          wset(x, y, 1)
        end
      end
    end
  end

  -- brillo bajo las crestas: solo donde la ola está alta, punteado
  for x = 0, 127, 3 do
    if SIG[x] > 0.25 then wset(x, floor(SY[x]) + 2, 3) end
  end

  -- brillos de luna sobre el agua (pocos, titilando)
  for k = 0, 3 do
    local gx = MOON_X - 6 + ((k * 5 + floor(cc * 4)) % 14)
    local gy = floor(SY[gx]) + 2 + k
    local lv = util.clamp(floor(5 - k + sin(cc * 3 + k) * 2), 1, 7)
    wset(gx - 1, gy, lv)
    wset(gx, gy, lv)
    wset(gx + 1, gy, lv)
  end

  -- pececitos que cruzan de vez en cuando
  for _, f in ipairs(fishes) do
    f.x = f.x + f.speed * f.dir
    if f.x < -8 or f.x > 136 then reset_fish(f) end
    local fx = floor(f.x)
    local fy = floor(f.y + sin(cc * 2 + f.x * 0.1) * 0.8)
    -- cuerpo ovalado con ojo (el hueco) y hocico
    local d, lv = f.dir, f.level
    for _, o in ipairs(FISH_BODY) do wset(fx + o[1] * d, fy + o[2], lv) end
    -- cola: se abre y se cierra mientras nada
    if sin(cc * 9 + f.y) > 0 then
      wset(fx - 4 * d, fy - 1, lv)
      wset(fx - 4 * d, fy + 1, lv)
    else
      wset(fx - 4 * d, fy, lv)
    end
  end

  -- burbujas con un leve vaivén
  for _, b in ipairs(bubbles) do
    local bx = floor((b.x + sin(b.wobble) * 1.2 - parallax_offset * 0.1) % 128)
    wset(bx, floor(b.y), b.level)
  end

  -- fondo: tres algas que se mecen; el fondo
  -- avanza despacio junto con el mar (si no, parece una pecera)
  local floor_scroll = cc * 3
  for i, base_x in ipairs(ALGAE_X) do
    local ax = floor((base_x - floor_scroll) % 140) - 6
    for k = 0, 4 + (i % 2) do
      local sway = floor(sin(cc * 0.8 + k * 0.6 + i) * k * 0.35 + 0.5)
      wset(ax + sway, 62 - k, 2)
    end
  end

  screen.poke(0, WATER_Y0, 128, WATER_H, table.concat(wbuf))

  -- línea de la superficie: la sombra de abajo, de un solo trazo
  screen.level(3)
  screen.move(0, SY[0] + 1)
  for x = 2, 128, 2 do screen.line(x, SY[x] + 1) end
  screen.stroke()

  -- la línea brillante: un trazo por cada tramo de igual brillo
  local cur = -1
  for x = 0, 126, 2 do
    local lv = util.clamp(floor(9 + SIG[x] * 6 + sin(x * 0.2 + cc * 2) * 2), 7, 15)
    if lv ~= cur then
      if cur ~= -1 then screen.stroke() end
      screen.level(lv)
      screen.move(x, SY[x])
      cur = lv
    end
    screen.line(x + 2, SY[x + 2])
  end
  screen.stroke()

  -- espuma en las crestas
  local foam_y = SEA_BASE_Y - amp * 0.6
  cur = -1
  for x = 0, 127 do
    local sy = SY[x]
    if sy < foam_y then
      local lv = util.clamp(floor(9 + SIG[x] * 6 + sin(x * 0.2 + cc * 2) * 2) + 2, 8, 15)
      if lv ~= cur then
        if cur ~= -1 then screen.fill() end
        screen.level(lv)
        cur = lv
      end
      screen.pixel(x, sy - 1)
    end
  end
  if cur ~= -1 then screen.fill() end
end

local function draw_lea(ax, ay)
  screen.level(15)
  screen.rect(ax - 1, ay, 3, 1)
  screen.fill()

  local wing_y = math.sin(wing_phase) * 3
  screen.move(ax - 4, ay - math.floor(wing_y))
  screen.line(ax - 1, ay)
  screen.line(ax + 2, ay)
  screen.line(ax + 5, ay - math.floor(wing_y))
  screen.stroke()
end

-- Reencuadre: con el panel abierto, si el ítem elegido es "tucker" o
-- "mobba", ese personaje se desliza hacia el área libre de la izquierda
-- (26/28) para que se vea a quién se está ajustando.
local function reframe_x(true_x, item_id, target_x)
  if menu_slide > 0 and panel_items[selected_item_idx].id == item_id then
    return true_x + (target_x - true_x) * menu_slide
  end
  return true_x
end

function draw_mar_page()
  screen.line_width(1)
  draw_sky()
  draw_sea()

  if entities.boat.on then
    local bx = math.floor(reframe_x(entities.boat.x_pos, "tucker", 26))
    local waterline = sea_surface_y(bx)
    local y_next = sea_surface_y(bx + 2)
    local y_prev = sea_surface_y(bx - 2)
    local slope_angle = math.atan2(y_next - y_prev, 4)
    draw_boat_sprite(bx, waterline, slope_angle)
  end

  if entities.whale.on then
    local wx = math.floor(reframe_x(entities.whale.x_pos, "mobba", 28))
    draw_whale_sprite(wx, math.floor(entities.whale.y_pos))
  end

  if lea_solo.active then
    draw_lea(math.floor(lea_solo.x), math.floor(lea_solo.y_pos))
  end

  -- partículas, agrupadas por brillo (un solo fill por nivel)
  for _, p in ipairs(particles) do
    if p.kind == "spout" then
      p.lv = util.clamp(math.floor((p.life / p.max_life) * 12), 1, 15)
    else
      p.lv = math.floor((p.life / p.max_life) * 15)
    end
  end
  for lv = 1, 15 do
    local any = false
    for _, p in ipairs(particles) do
      if p.lv == lv then
        if not any then screen.level(lv); any = true end
        local px, py = math.floor(p.x), math.floor(p.y)
        screen.pixel(px, py)
        if p.kind == "spout" then
          if p.life > p.max_life * 0.5 then screen.pixel(px, py + 1) end
        elseif p.kind == "note_spark" then
          screen.pixel(px + 1, py - 1)
        end
      end
    end
    if any then screen.fill() end
  end
end

-- ============================================================
-- MENÚ GENÉRICO CON SCROLL
-- ============================================================
local function compute_scroll_offset(sel_idx, total, visible)
  if total <= visible then return 0 end
  local offset = sel_idx - 1 - math.floor(visible / 2)
  offset = math.max(0, math.min(offset, total - visible))
  return offset
end

-- Etiqueta a la izquierda (tenue), valor alineado a la derecha; el ítem
-- elegido lleva un triangulito y una línea fina debajo en vez del
-- bloque blanco.
local function draw_item_menu(x, labels, values, selected_idx, y_start, row_h, visible_rows)
  local offset = compute_scroll_offset(selected_idx, #labels, visible_rows)
  local right = 124
  for i = offset + 1, math.min(#labels, offset + visible_rows) do
    local row = i - offset
    local y = y_start + (row - 1) * row_h
    local sel = (i == selected_idx)
    if sel then
      screen.level(15)
      screen.move(x, y - 6)
      screen.line(x + 3, y - 3)
      screen.line(x, y)
      screen.close()
      screen.fill()
    end
    -- si etiqueta + valor no entran, se acorta la etiqueta (el valor
    -- siempre se ve completo)
    local label = labels[i]
    local vw = screen.text_extents(values[i])
    local room = right - (x + 5) - vw - 4
    if screen.text_extents(label) > room then
      while #label > 1 and screen.text_extents(label .. ".") > room do
        label = label:sub(1, -2)
      end
      label = (room > 6) and (label .. ".") or ""
    end
    screen.level(sel and 15 or 4)
    screen.move(x + 5, y)
    screen.text(label)
    screen.level(sel and 15 or 8)
    screen.move(right, y)
    screen.text_right(values[i])
    if sel then
      screen.level(3)
      screen.move(x + 5, y + 2.5)
      screen.line(right, y + 2.5)
      screen.stroke()
    end
  end
  -- barrita de scroll (solo si hay más ítems de los que entran)
  if #labels > visible_rows then
    local top = y_start - row_h + 2
    local h = visible_rows * row_h
    local th = math.max(3, math.floor(h * visible_rows / #labels))
    local ty = top + math.floor((h - th) * offset / (#labels - visible_rows))
    screen.level(1)
    screen.rect(127, top, 1, h)
    screen.fill()
    screen.level(6)
    screen.rect(127, ty, 1, th)
    screen.fill()
  end
end

-- ============================================================
-- PANEL (K1 mantenido): una sola lista de 6 ajustes
-- ============================================================
local function panel_item_value(id)
  if id == "sea_filter" then
    return string.format("%dHz", math.floor(filter_cutoff))
  end
  return params:string(id)
end

-- helpers: opciones que dan la vuelta / interruptores
local function param_wrap(id, delta, n)
  params:set(id, ((params:get(id) - 1 + delta) % n) + 1)
end
local function param_toggle(id)
  params:set(id, (params:get(id) == 2) and 1 or 2)
end

local function apply_panel_delta(id, delta)
  if id == "tucker" then
    param_wrap("tucker", delta, #entities.boat.synth_names + 1)
    -- una nota de muestra para escuchar el timbre nuevo
    local boat = entities.boat
    if boat.on then
      local preview_note = (boat.prev_note ~= -1) and boat.prev_note or root_note
      trigger_entity_sound(boat, "boat", preview_note, boat.default_release)
    end
  elseif id == "mobba" or id == "modo" then
    param_toggle(id)
  elseif id == "sea_scale" then
    params:set("sea_scale", util.clamp(current_scale + delta, 1, #scale_names))
  elseif id == "sea_root" then
    param_wrap("sea_root", delta, 12)
  elseif id == "sea_filter" then
    params:set("sea_filter", util.clamp(filter_cutoff + delta * 100, 100, 5000))
  end
end

function draw_zoom_overlay()
  -- slide_x va de 128 (afuera de pantalla, a la derecha) a 54 (reposo)
  local slide_x = math.floor(128 - menu_slide * 74)

  screen.level(0)
  screen.rect(slide_x - 3, 0, 131 - slide_x, 64)
  screen.fill()
  -- divisor punteado entre escena y panel
  screen.level(2)
  for yy = 1, 63, 3 do screen.pixel(slide_x - 3, yy) end
  screen.fill()

  screen.level(15)
  screen.move(26, 8)
  screen.text_center("UMI")
  -- olita debajo del nombre
  screen.level(4)
  for xx = -11, 11 do
    screen.pixel(26 + xx, 11 + math.floor(math.sin(xx * 0.6 + clock_counter * 3) * 0.8 + 0.5))
  end
  screen.fill()

  local labels, values = {}, {}
  for i, spec in ipairs(panel_items) do
    labels[i] = spec.label
    values[i] = panel_item_value(spec.id)
  end
  draw_item_menu(slide_x, labels, values, selected_item_idx, 12, 9, #panel_items)
end

-- ============================================================
-- REDRAW PRINCIPAL
-- ============================================================
function redraw()
  screen.clear()

  if splash_phase == 1 then
    uma_intro.render(splash_elapsed())
  elseif splash_phase == 2 then
    local e = splash_elapsed() - uma_intro.DUR
    local a = 1
    if e < SPLASH_IN then a = e / SPLASH_IN
    elseif e > SPLASH_IN + SPLASH_HOLD then a = 1 - (e - SPLASH_IN - SPLASH_HOLD) / SPLASH_FADE end
    draw_umi_splash(math.max(0, math.min(1, a)))
  else
    draw_mar_page()
    if zoom_held or menu_slide > 0 then
      draw_zoom_overlay()
    end
  end

  screen.update()
end

-- ============================================================
-- ENCODERS Y BOTONES
-- ============================================================
function enc(n, delta)
  if splash_phase > 0 then splash_skip() return end

  if n == 2 and lea_solo.active then
    -- El solo de Lea tiene prioridad sobre la navegación del panel
    local step = delta * ((BOAT_X_MAX - BOAT_X_MIN) / 10)
    lea_solo.x_target = util.clamp(lea_solo.x_target + step, BOAT_X_MIN, BOAT_X_MAX)
    return
  end

  if zoom_held and n ~= 1 then
    -- Panel abierto: E2 elige el ajuste, E3 lo cambia (E1 sigue siendo viento)
    if n == 2 then
      selected_item_idx = ((selected_item_idx - 1 + delta) % #panel_items) + 1
    else
      apply_panel_delta(panel_items[selected_item_idx].id, delta)
    end
    return
  end

  -- Estado base (panel cerrado, Lea sin solo): E1 = viento/olas,
  -- E2 = Tucker, E3 = Mobba — una mano por personaje.
  if n == 1 then
    wind_speed = util.clamp(wind_speed + delta * 0.1, 0.5, 3.0)
    engine.set_wind(0.01 * wind_speed, 300 + (wind_speed * 100))
  elseif n == 2 then
    local step = delta * ((BOAT_X_MAX - BOAT_X_MIN) / 10)
    entities.boat.x_target = util.clamp(entities.boat.x_target + step, BOAT_X_MIN, BOAT_X_MAX)
  elseif n == 3 then
    local step = delta * ((BOAT_X_MAX - BOAT_X_MIN) / 10)
    entities.whale.x_target = util.clamp(entities.whale.x_target + step, BOAT_X_MIN, BOAT_X_MAX)
  end
end

function key(n, z)
  if splash_phase > 0 then
    if z == 1 then splash_skip(); splash_held[n] = true end
    return
  end
  -- tragar el "soltar" de la tecla que salteó la intro
  if z == 0 and splash_held[n] then splash_held[n] = nil return end
  if n == 1 then
    -- K1 mantenido abre el panel; al soltar se cierra
    zoom_held = (z == 1)
  elseif n == 2 then
    if z == 1 then
      if lea_solo.active then
        -- todavía está en cuadro (saliendo): da la vuelta desde donde está
        lea_solo.x_target = LEA_SOLO_CENTER_X
        return
      end
      -- K2 apretado: Lea entra a cuadro en modo solo
      lea_solo.active = true
      lea_solo.x = LEA_SOLO_ENTER_X
      lea_solo.x_target = LEA_SOLO_CENTER_X
      lea_solo.walk_note_idx = math.floor(#notes_in_scale / 2) + 1
      lea_solo.walk_dir = 1
      lea_solo.walk_phrase_len = 4
      lea_solo.gen_wait = 0
      -- primero la frecuencia, así la voz no arranca en una nota vieja
      engine.lea_solo_freq(MusicUtil.note_num_to_freq(notes_in_scale[lea_solo.walk_note_idx]) * 2)
      engine.set_lea_solo(1, 3.0)
    else
      -- K2 soltado: sale de cuadro volando por la derecha, despacio;
      -- update_physics apaga la voz apenas termina de salir de pantalla.
      lea_solo.x_target = LEA_SOLO_EXIT_X
    end
  elseif n == 3 and z == 1 then
    -- K3: Mobba canta cerca de donde está cantando ahora (su última
    -- nota, o el centro corrido por su posición), y un instante después
    -- vuelve el eco. No interrumpe su arp/gen. Apagada: no suena nada.
    if not echo.pending and entities.whale.on then
      local whale = entities.whale
      local base = whale.last_idx or
        (math.floor(#notes_in_scale / 2) + 1 + x_to_transpose(whale.x_pos))
      local idx = util.clamp(base + math.random(-2, 2), 1, #notes_in_scale)
      local note = notes_in_scale[idx]
      trigger_entity_sound(whale, "whale", note, 1.0, 1.0, 2.2)
      echo.pending = true
      echo.note = note
      echo.at = util.time() + ECHO_DELAY_SEC
    end
  end
end