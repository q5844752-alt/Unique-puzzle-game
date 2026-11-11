-- آڈیو پزل گیمز (ورژن 1.0، خودکار اپڈیٹ کے ساتھ): Android کے لیے Lua (AndroLua انداز)
-- 1) آوازوں کی ترتیب کی یادداشت
-- 2) تجوری کھولو (پیانو کے سُر)
-- 3) پراسرار جاسوس: دو راؤنڈ، ہر راؤنڈ میں 8 کیس
-- 4) ہارر: کہانی 1 ویران حویلی، کہانی 2 ویران ہسپتال (فولڈر: Horror audio sounds)
--
-- آپ کی اپنی آوازیں اس فولڈر سے چلیں گی:
-- Internal storage / 解说 / Tools / Unique audio puzzle game / Audio sounds
-- (فولڈر کے نام میں بڑے چھوٹے حروف یا خالی جگہ کا فرق ہو تو بھی گیم خود ڈھونڈ لیتی ہے)
-- جو آواز آپ کے فولڈر میں نہ ہو وہ گیم خود بنا کر بجاتی ہے۔
--
-- خودکار اپڈیٹ: گیم کھلنے پر GitHub (q5844752-alt/Unique-puzzle-game) سے version.txt دیکھتی ہے۔
-- نیا ورژن ہو تو کوڈ کی فائل خود ڈاؤن لوڈ ہو کر
-- Internal storage / 解说 / Tools / Unique audio puzzle game / main.lua کی جگہ لے لیتی ہے
-- (پرانی فائل main.lua.bak کے نام سے بچی رہتی ہے)۔ نیا ورژن اگلی بار گیم کھلنے پر چلتا ہے۔
--
-- نیا ورژن شائع کرنے کا طریقہ:
-- 1) نئی کوڈ فائل GitHub پر اسی نام سے اپلوڈ کریں (پرانی کی جگہ)، اور اس کے اندر APP_VERSION بدلیں۔
-- 2) version.txt کی پہلی لائن میں وہی نیا ورژن لکھیں (مثلاً 1.1)۔
-- 3) اگر کوڈ فائل کا نام بدلا ہو تو version.txt کی دوسری لائن میں نیا نام لکھیں۔

require "import"
import "android.widget.*"
import "android.view.*"
import "android.media.*"
import "android.os.*"
import "java.io.File"

math.randomseed(os.time())

local sin, pi, exp, random = math.sin, math.pi, math.exp, math.random
local R = 16000
local VER = "v8"
local APP_VERSION = "1.0"   -- اس کوڈ کا ورژن؛ GitHub کی version.txt سے ملایا جاتا ہے

------------------------------------------------------------
-- بنیادی مدد گار
------------------------------------------------------------
local handler = Handler()
local function later(ms, f)
  handler.postDelayed(luajava.createProxy("java.lang.Runnable", { run = f }), ms)
end

-- gen: سکرین بدلنے پر پرانے ٹائمر بند ہو جاتے ہیں
local gen = 0
local function laterG(g, ms, f)
  later(ms, function() if g == gen then f() end end)
end

local CACHE = activity.getCacheDir().getAbsolutePath() .. "/"

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

------------------------------------------------------------
-- آپ کے ساؤنڈ فولڈر کی تلاش
------------------------------------------------------------
-- نام کو برابر کرنا: چھوٹے حروف، خالی جگہ اور .wav ہٹا دینا
-- (مثلاً "Door open.wav" اور "doorOpen" ایک ہی بن جاتے ہیں)
local function norm(s)
  s = s:lower():gsub("%.%w+$", "")
  return (s:gsub("[^%w]", ""))
end

local function listNames(dir)
  local out = {}
  pcall(function()
    local f = File(dir)
    if f.exists() and f.isDirectory() then
      local arr = f.list()
      if arr then
        local ok, t = pcall(function() return luajava.astable(arr) end)
        if ok and t then
          for _, v in ipairs(t) do out[#out + 1] = tostring(v) end
        else
          for i = 0, arr.length - 1 do out[#out + 1] = tostring(arr[i]) end
        end
      end
    end
  end)
  return out
end

local function childDir(dir, pred)
  for _, nm in ipairs(listNames(dir)) do
    if pred(nm) and File(dir .. nm).isDirectory() then return dir .. nm .. "/" end
  end
  return nil
end

local EXACT = "/sdcard/解说/Tools/Unique audio puzzle game/Audio sounds/"

local function soundDirs()
  local dirs = { EXACT }
  for _, base in ipairs({ "/sdcard/", "/storage/emulated/0/" }) do
    local d = base
    local steps = {
      function(nm) return nm:find("解说", 1, true) ~= nil end,
      function(nm) return norm(nm) == "tools" end,
      function(nm) return norm(nm):find("uniqueaudio", 1, true) ~= nil end,
      function(nm) return norm(nm):find("audiosounds", 1, true) ~= nil end,
    }
    for _, p in ipairs(steps) do
      if d then d = childDir(d, p) end
    end
    if d then dirs[#dirs + 1] = d end
  end
  dirs[#dirs + 1] = "/sdcard/audiogame/"
  return dirs
end

local userFiles, userCount, gameDir, soundDirFound = {}, 0, nil, nil
local lastScan, lastScanH = 0, 0   -- آخری بار فولڈر کب دیکھا

local function scanSounds()
  userFiles, userCount, gameDir, soundDirFound = {}, 0, nil, nil
  lastScan = os.time()
  for _, dir in ipairs(soundDirs()) do
    local names = listNames(dir)
    if #names > 0 then
      if not soundDirFound then soundDirFound = dir end
      for _, nm in ipairs(names) do
        local ext = nm:lower():match("%.(%w+)$")
        if ext == "wav" or ext == "mp3" or ext == "ogg" or ext == "m4a" then
          local k = norm(nm)
          if not userFiles[k] then
            userFiles[k] = dir .. nm
            userCount = userCount + 1
          end
        end
      end
    end
  end
  if soundDirFound and soundDirFound ~= "/sdcard/audiogame/" then
    gameDir = soundDirFound:match("^(.*/)[^/]+/$")
  end
end

------------------------------------------------------------
-- پیش رفت محفوظ کرنا اور واپس پڑھنا
------------------------------------------------------------
local prog = { round = 1, start = 1, total = 0, best1 = 0, best2 = 0, best3 = 0, best4 = 0, best5 = 0 }

local function progPaths()
  local t = {}
  if gameDir then t[#t + 1] = gameDir .. "progress.txt" end
  t[#t + 1] = activity.getFilesDir().getAbsolutePath() .. "/audiopuzzle_progress.txt"
  return t
end

local function saveProg()
  local text = string.format("round=%d\nstart=%d\ntotal=%d\nbest1=%d\nbest2=%d\nbest3=%d\nbest4=%d\nbest5=%d\n",
    prog.round, prog.start, prog.total, prog.best1, prog.best2, prog.best3, prog.best4,
    prog.best5)
  for _, p in ipairs(progPaths()) do
    pcall(function()
      local f = io.open(p, "w")
      f:write(text)
      f:close()
    end)
  end
end

local function loadProg()
  for _, p in ipairs(progPaths()) do
    local f = io.open(p, "r")
    if f then
      local txt = f:read("*a")
      f:close()
      for k, v in txt:gmatch("(%w+)=(%-?%d+)") do
        if prog[k] ~= nil then prog[k] = tonumber(v) end
      end
      return
    end
  end
end

------------------------------------------------------------
-- آواز بنانا اور بجانا
------------------------------------------------------------
local function finish(raw, gain)
  local peak = 0.0001
  for i = 1, #raw do
    local a = math.abs(raw[i])
    if a > peak then peak = a end
  end
  local out = {}
  local k = 32767 * (gain or 0.8) / peak
  for i = 1, #raw do out[i] = math.floor(raw[i] * k) end
  return out
end

local function wavBytes(data)
  local parts, n = {}, #data
  for i = 1, n, 2000 do
    local chunk = {}
    for j = i, math.min(i + 1999, n) do
      chunk[#chunk + 1] = string.pack("<i2", data[j])
    end
    parts[#parts + 1] = table.concat(chunk)
  end
  local pcm = table.concat(parts)
  local header = "RIFF" .. string.pack("<I4", 36 + #pcm) .. "WAVEfmt " ..
    string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, R, R * 2, 2, 16) ..
    "data" .. string.pack("<I4", #pcm)
  return header .. pcm
end

local function getSound(key, builder)
  local path = CACHE .. "ag_" .. VER .. "_" .. key .. ".wav"
  if not File(path).exists() then
    local f = io.open(path, "wb")
    f:write(wavBytes(builder()))
    f:close()
  end
  return path
end

-- فائل بجائیں اور اس کا دورانیہ (ms) واپس کریں۔ maxMs سے لمبی ہو تو کاٹ دیں۔
local function playPath(path, maxMs)
  local dur
  pcall(function()
    local mp = MediaPlayer()
    mp.setDataSource(path)
    mp.prepare()
    dur = mp.getDuration()
    mp.setOnCompletionListener(luajava.createProxy(
      "android.media.MediaPlayer$OnCompletionListener",
      { onCompletion = function(p) pcall(function() p.release() end) end }))
    mp.start()
    if maxMs and dur and dur > maxMs then
      dur = maxMs
      later(maxMs, function()
        pcall(function() mp.stop() end)
        pcall(function() mp.release() end)
      end)
    end
  end)
  if dur and dur < 0 then dur = nil end
  return dur
end

-- پہلے آپ کی فائل، نہ ہو تو گیم کی بنائی ہوئی آواز
-- نام (یا ناموں کی فہرست) سے آپ کی فائل ڈھونڈنا۔
-- فائل نہ ملے تو فولڈر دوبارہ دیکھ لیتا ہے (ہر 3 سیکنڈ میں زیادہ سے زیادہ ایک بار)،
-- اس لیے بعد میں رکھی ہوئی فائلیں خود بخود پہچان لی جاتی ہیں۔
local function findUser(names)
  if not names then return nil end
  local list = type(names) == "table" and names or { names }
  for pass = 1, 2 do
    for _, nm in ipairs(list) do
      local p = userFiles[norm(nm)]
      if p then return p end
    end
    if pass == 1 then
      if os.time() - lastScan < 3 then return nil end
      scanSounds()
    end
  end
  return nil
end

local function playNamed(userName, key, builder, maxMs)
  local up = findUser(userName)
  if up then
    local d = playPath(up, maxMs)
    if d then return d end
  end
  return playPath(getSound(key, builder), maxMs)
end

------------------------------------------------------------
-- گیم کی اپنی بنائی ہوئی آوازیں
------------------------------------------------------------
local function bellSound(f0, ms, dec)
  local n = math.floor(R * ms / 1000)
  local partials = {
    { 0.5, 1.0, 0.6 }, { 1, 0.8, 1.0 }, { 1.2, 0.5, 1.4 }, { 1.5, 0.3, 1.8 },
    { 2, 0.4, 2.2 }, { 2.74, 0.3, 3 }, { 3.5, 0.2, 4 }, { 4.2, 0.15, 5 },
  }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0
    for _, p in ipairs(partials) do
      s = s + p[2] * sin(2 * pi * f0 * p[1] * t) * exp(-t * p[3] * dec)
    end
    raw[i] = s * math.min(1, t / 0.003)
  end
  return finish(raw, 0.8)
end

local function meow()
  local dur = 0.9
  local n = math.floor(R * dur)
  local raw, phase = {}, 0
  for i = 1, n do
    local t = (i - 1) / R
    local x = t / dur
    local f = 380 + 520 * sin(pi * math.min(1, x * 1.15)) * (1 - 0.3 * x)
    phase = phase + 2 * pi * f / R
    local fc = 2400 - 1500 * x
    local v = 0
    local h = 1
    while h <= 14 and h * f < 7000 do
      local w = exp(-((h * f - fc) / 700) ^ 2) + 0.15 / h
      v = v + w * sin(h * phase)
      h = h + 1
    end
    local env = math.min(1, t / 0.08, (dur - t) / 0.18)
    raw[i] = v * env * (1 + 0.1 * sin(2 * pi * 30 * t))
  end
  return finish(raw, 0.75)
end

local function rain()
  local n = math.floor(R * 1.8)
  local raw, prev, drop = {}, 0, 0
  for i = 1, n do
    local t = (i - 1) / R
    local nz = random() * 2 - 1
    local hp = nz - 0.6 * prev
    prev = nz
    if random() < 0.003 then drop = 1 end
    drop = drop * 0.985
    local fade = math.min(1, t / 0.15, (n / R - t) / 0.2)
    raw[i] = (0.5 * hp + drop * (random() * 2 - 1) * 0.9) * fade
  end
  return finish(raw, 0.7)
end

local function horn()
  local n = math.floor(R * 0.85)
  local function sq(f, t)
    return sin(2 * pi * f * t) + 0.33 * sin(6 * pi * f * t) +
           0.2 * sin(10 * pi * f * t) + 0.14 * sin(14 * pi * f * t)
  end
  local wins = { { 0.0, 0.3 }, { 0.42, 0.78 } }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local g = 0
    for _, w in ipairs(wins) do
      if t >= w[1] and t <= w[2] then
        g = math.min(1, (t - w[1]) / 0.012, (w[2] - t) / 0.02)
      end
    end
    raw[i] = (sq(420, t) + sq(530, t)) * g
  end
  return finish(raw, 0.7)
end

local function dog()
  local n = math.floor(R * 0.75)
  local barks = { 0, 0.3 }
  local raw, phase = {}, 0
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0
    for _, b in ipairs(barks) do
      local x = (t - b) / 0.22
      if x >= 0 and x < 1 then
        local f = 480 - 230 * x
        phase = phase + 2 * pi * f / R
        local v = 0
        for h = 1, 8 do
          v = v + (exp(-((h * f - 1000) / 700) ^ 2) + 0.08) * sin(h * phase)
        end
        v = v * 0.7 + (random() * 2 - 1) * 0.5 * exp(-x * 3)
        s = s + v * math.min(1, x / 0.04) * exp(-x * 3.5)
      end
    end
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function drum()
  local n = math.floor(R * 0.8)
  local hits = { { 0, 170, 55, 1.0, 9 }, { 0.3, 230, 110, 0.8, 11 } }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0
    for _, h in ipairs(hits) do
      local tt = t - h[1]
      if tt >= 0 then
        local ph = 2 * pi * (h[3] * tt + (h[2] - h[3]) * (1 - exp(-30 * tt)) / 30)
        s = s + h[4] * (sin(ph) * exp(-tt * h[5]) +
            (random() * 2 - 1) * 0.35 * exp(-tt * 90))
      end
    end
    raw[i] = s
  end
  return finish(raw, 0.9)
end

local function clickSound()
  local n = math.floor(R * 0.05)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    raw[i] = (random() * 2 - 1) * exp(-t * 140) +
             0.6 * sin(2 * pi * 2400 * t) * exp(-t * 180)
  end
  return finish(raw, 0.8)
end

local function openSound()
  local n = math.floor(R * 0.9)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = sin(2 * pi * 65 * t) * exp(-t * 6)
    for _, c in ipairs({ 0, 0.15 }) do
      local tt = t - c
      if tt >= 0 then
        s = s + (random() * 2 - 1) * 0.8 * exp(-tt * 120) +
            0.4 * sin(2 * pi * 1500 * tt) * exp(-tt * 100)
      end
    end
    if t > 0.25 and t < 0.85 then
      s = s + 0.25 * (0.5 + 0.5 * sin(2 * pi * 14 * t)) * sin(2 * pi * 120 * t)
    end
    raw[i] = s
  end
  return finish(raw, 0.85)
end

local function failSound()
  local dur = 0.7
  local n = math.floor(R * dur)
  local raw, phase = {}, 0
  for i = 1, n do
    local t = (i - 1) / R
    local x = t / dur
    phase = phase + 2 * pi * (260 - 140 * x) / R
    local v = 0
    for h = 1, 6 do v = v + sin(h * phase) / h end
    raw[i] = v * math.min(1, x / 0.03) * (1 - x) ^ 0.5
  end
  return finish(raw, 0.8)
end

local function piano(midi)
  local f = 440 * 2 ^ ((midi - 69) / 12)
  local n = math.floor(R * 1.0)
  local amps = { 1, 0.55, 0.4, 0.25, 0.18, 0.1, 0.07, 0.04 }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0
    for h, a in ipairs(amps) do
      local fh = f * h * (1 + 0.0004 * h * h)
      if fh < 7500 then
        s = s + a * sin(2 * pi * fh * t) * exp(-t * (1.2 + 0.55 * h))
      end
    end
    s = s * math.min(1, t / 0.004) + (random() * 2 - 1) * 0.12 * exp(-t * 120)
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function lpnoise(a)
  local y = 0
  return function()
    y = y + a * ((random() * 2 - 1) - y)
    return y
  end
end

local function clk(tt, f, dec)
  if tt < 0 then return 0 end
  return (random() * 2 - 1) * exp(-tt * dec) +
         0.6 * sin(2 * pi * f * tt) * exp(-tt * dec * 1.2)
end

local function thud(tt, f, dec)
  if tt < 0 then return 0 end
  return sin(2 * pi * f * tt) * exp(-tt * dec)
end

local function stepsSound(count, gap, f, lp, amp)
  local n = math.floor(R * (gap * (count - 1) + 0.3))
  local nz = lpnoise(lp)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local k = math.floor(t / gap)
    local tt = t - k * gap
    local z = nz()
    local s = 0
    if k < count and tt < 0.25 then
      s = thud(tt, f, 30) + z * 3 * exp(-tt * 28) * amp
    end
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function glassBreak()
  local n = math.floor(R * 1.3)
  local pings = {}
  for i = 1, 22 do
    pings[i] = { st = random() * 0.45, f = 2000 + random() * 4500,
                 dec = 8 + random() * 14, a = 0.2 + random() * 0.5 }
  end
  local prev, raw = 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    local nz = random() * 2 - 1
    local hp = nz - prev
    prev = nz
    local s = hp * exp(-t * 16) * 1.2
    for _, p in ipairs(pings) do
      local tt = t - p.st
      if tt >= 0 and tt < 0.6 then
        s = s + p.a * sin(2 * pi * p.f * tt) * exp(-tt * p.dec)
      end
    end
    raw[i] = s
  end
  return finish(raw, 0.85)
end

local function keyTurn()
  local n = math.floor(R * 0.8)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0.5 * sin(2 * pi * 4200 * t) * exp(-t * 25) * (0.5 + 0.5 * sin(2 * pi * 40 * t))
    s = s + clk(t - 0.12, 1800, 160) + clk(t - 0.22, 1800, 160) + clk(t - 0.32, 1800, 160)
    s = s + 1.4 * clk(t - 0.5, 900, 90) + thud(t - 0.5, 140, 30)
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function doorClose()
  local n = math.floor(R * 0.8)
  local nz = lpnoise(0.15)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    raw[i] = thud(t, 75, 9) * 1.2 + nz() * 2 * exp(-t * 14) + 0.8 * clk(t - 0.1, 1500, 120)
  end
  return finish(raw, 0.9)
end

local function doorOpen()
  local dur = 1.1
  local n = math.floor(R * dur)
  local raw, phase = {}, 0
  for i = 1, n do
    local t = (i - 1) / R
    local x = t / dur
    phase = phase + 2 * pi * (200 + 140 * sin(pi * x)) / R
    local v = 0
    for h = 1, 5 do v = v + sin(h * phase) / h end
    local env = math.max(0, math.min(1, t / 0.15, (dur - t) / 0.25))
    raw[i] = v * env * (0.6 + 0.4 * sin(2 * pi * 24 * t)) * 0.7 + clk(t - 0.02, 1400, 110)
  end
  return finish(raw, 0.8)
end

local function slideSound(dur, a, f)
  local n = math.floor(R * (dur + 0.2))
  local nz = lpnoise(a)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local env = math.max(0, math.min(1, t / 0.05, (dur - t) / 0.1))
    local s = nz() * 2 * env * (0.6 + 0.4 * sin(2 * pi * 11 * t)) +
              0.3 * sin(2 * pi * f * t) * env
    s = s + thud(t - dur, 90, 25) + clk(t - dur, 1100, 100)
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function paperRustle()
  local n = math.floor(R * 1.1)
  local bursts = {}
  for i = 1, 9 do bursts[i] = { st = random() * 0.9, len = 0.04 + random() * 0.07 } end
  local prev, raw = 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    local nz = random() * 2 - 1
    local hp = nz - 0.5 * prev
    prev = nz
    local s = 0
    for _, b in ipairs(bursts) do
      local tt = t - b.st
      if tt >= 0 and tt < b.len then s = s + hp * (1 - tt / b.len) end
    end
    raw[i] = s
  end
  return finish(raw, 0.6)
end

local function phoneRing()
  local n = math.floor(R * 1.3)
  local wins = { { 0, 0.45 }, { 0.65, 1.1 } }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local g = 0
    for _, w in ipairs(wins) do
      if t >= w[1] and t <= w[2] then
        g = math.min(1, (t - w[1]) / 0.01, (w[2] - t) / 0.01)
      end
    end
    raw[i] = (sin(2 * pi * 440 * t) + sin(2 * pi * 480 * t)) *
             (0.65 + 0.35 * sin(2 * pi * 20 * t)) * g
  end
  return finish(raw, 0.6)
end

local function carStart()
  local n = math.floor(R * 2.0)
  local nz = lpnoise(0.2)
  local phase, raw = 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    local z = nz()
    local s
    if t < 0.75 then
      local p = 0.5 + 0.5 * sin(2 * pi * 9 * t)
      s = z * 2 * p + 0.5 * sin(2 * pi * 80 * t) * p
    else
      local tt = t - 0.75
      local f = 38 + 30 * math.min(1, tt / 0.5) + 25 * math.max(0, (tt - 0.9) / 0.3)
      phase = phase + 2 * pi * f / R
      local v = 0
      for h = 1, 6 do v = v + sin(h * phase) / h end
      s = v * (0.7 + 0.3 * sin(2 * pi * 22 * t)) * math.min(1, tt / 0.1) * 1.5 + z * 0.3
    end
    raw[i] = s * math.min(1, (2.0 - t) / 0.2)
  end
  return finish(raw, 0.85)
end

local function siren()
  local n = math.floor(R * 1.7)
  local phase, raw = 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    phase = phase + 2 * pi * (900 + 300 * sin(2 * pi * 0.9 * t)) / R
    raw[i] = (sin(phase) + 0.3 * sin(2 * phase)) * math.min(1, t / 0.05, (1.7 - t) / 0.1)
  end
  return finish(raw, 0.7)
end

local function thunder()
  local n = math.floor(R * 2.2)
  local y, prevx, raw = 0, 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    local x = random() * 2 - 1
    y = 0.985 * y + 0.12 * x
    local crack = (x - prevx) * exp(-t * 35)
    prevx = x
    local env = math.min(1, t / 0.12) * exp(-math.max(0, t - 0.12) * 1.3)
    raw[i] = y * env * 6 + crack * 2
  end
  return finish(raw, 0.85)
end

local function clockTick()
  local n = math.floor(R * 1.7)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    raw[i] = clk(t, 2000, 200) + clk(t - 0.5, 1500, 200) +
             clk(t - 1.0, 2000, 200) + clk(t - 1.5, 1500, 200)
  end
  return finish(raw, 0.7)
end

local function alarmBeep()
  local n = math.floor(R * 1.5)
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local g = 0
    for k = 0, 3 do
      local tt = t - k * 0.37
      if tt >= 0 and tt <= 0.2 then g = math.min(1, tt / 0.005, (0.2 - tt) / 0.005) end
    end
    raw[i] = (sin(2 * pi * 1000 * t) + 0.3 * sin(2 * pi * 3000 * t)) * g
  end
  return finish(raw, 0.7)
end

local function clatter()
  local n = math.floor(R * 0.8)
  local hits = { { 0, 1100, 16 }, { 0.09, 1700, 18 }, { 0.17, 2600, 20 },
                 { 0.3, 900, 14 }, { 0.38, 2100, 22 } }
  local raw = {}
  for i = 1, n do
    local t = (i - 1) / R
    local s = 0
    for _, h in ipairs(hits) do
      local tt = t - h[1]
      if tt >= 0 then
        s = s + sin(2 * pi * h[2] * tt) * exp(-tt * h[3]) +
            (random() * 2 - 1) * 0.4 * exp(-tt * 60)
      end
    end
    raw[i] = s
  end
  return finish(raw, 0.8)
end

local function tapWater()
  local n = math.floor(R * 1.6)
  local y1, y2, raw = 0, 0, {}
  for i = 1, n do
    local t = (i - 1) / R
    local x = random() * 2 - 1
    y1 = y1 + 0.7 * (x - y1)
    y2 = y2 + 0.1 * (x - y2)
    raw[i] = (y1 - y2) * (0.8 + 0.2 * sin(2 * pi * 9 * t)) *
             math.min(1, t / 0.1, (1.6 - t) / 0.1)
  end
  return finish(raw, 0.7)
end

------------------------------------------------------------
-- یادداشت والے گیم کی آوازیں
-- file = آپ کی فائل کا نام (bell.wav وغیرہ)؛ نہ ملے تو build سے بنتی ہے
------------------------------------------------------------
local sounds = {
  { name = "گھنٹی",        file = "bell", build = function() return bellSound(660, 1400, 1.2) end },
  { name = "بلی",          file = "cat",  build = meow  },
  { name = "بارش",         file = "rain", build = rain  },
  { name = "گاڑی کا ہارن", file = "horn", build = horn  },
  { name = "کتا",          file = "dog",  build = dog   },
  { name = "ڈھول",         file = "drum", user = "dhol", build = drum  },
}

local function playSound(k, maxMs)
  local s = sounds[k]
  return playNamed(s.user or s.file, "s_" .. s.file, s.build, maxMs)
end

local function fx(name)
  if name == "ding" then
    playNamed(nil, "fx_ding", function() return bellSound(1320, 600, 3) end)
  elseif name == "fail" then
    playNamed(nil, "fx_fail", failSound)
  elseif name == "click" then
    playNamed(nil, "fx_click", clickSound)
  elseif name == "open" then
    playNamed(nil, "fx_open", openSound)
  end
end

------------------------------------------------------------
-- جاسوسی آوازیں
-- user = آپ کی فائل کا نام؛ جس کا user نہیں وہ گیم خود بنا کر بجاتی ہے
------------------------------------------------------------
local dsounds = {
  steps     = { name = "قدموں کی آواز", ms = 1500, user = "steps",
                build = function() return stepsSound(4, 0.4, 95, 0.25, 1.2) end },
  run       = { name = "بھاگتے قدم", ms = 1350, user = "run",
                build = function() return stepsSound(7, 0.17, 100, 0.3, 1.5) end },
  glass     = { name = "شیشہ ٹوٹنا", ms = 1300, user = "glass", build = glassBreak },
  keyTurn   = { name = "چابی گھمانا", ms = 800, user = "keyTurn", build = keyTurn },
  doorClose = { name = "دروازہ بند ہونا", ms = 800, user = "doorClose", build = doorClose },
  doorOpen  = { name = "دروازہ کھلنا", ms = 1100, user = "doorOpen", build = doorOpen },
  window    = { name = "کھڑکی کھسکنا", ms = 1000, user = "window",
                build = function() return slideSound(0.8, 0.5, 110) end },
  drawer    = { name = "دراز کھلنا", ms = 650, user = "drawer",
                build = function() return slideSound(0.45, 0.3, 160) end },
  paper     = { name = "کاغذوں کی سرسراہٹ", ms = 1100, user = "papers", build = paperRustle },
  phone     = { name = "فون کی گھنٹی", ms = 1300, user = "phone", build = phoneRing },
  carStart  = { name = "گاڑی سٹارٹ ہونا", ms = 2000, user = "carStart", build = carStart },
  siren     = { name = "پولیس کا سائرن", ms = 1700, user = "siren", build = siren },
  thunder   = { name = "بادل کی گرج", ms = 2200, user = "thunder", build = thunder },
  clock     = { name = "گھڑی کی ٹک ٹک", ms = 1700, user = "clock", build = clockTick },
  bell      = { name = "گھنٹی", ms = 1500, user = "bell",
                build = function() return bellSound(400, 1500, 0.9) end },
  alarm     = { name = "الارم", ms = 1500, user = "alarm", build = alarmBeep },
  clatter   = { name = "کسی چیز کا گرنا", ms = 800, user = "clatter", build = clatter },
  tap       = { name = "نل کا پانی", ms = 1600, user = "tap", build = tapWater },
  dog       = { name = "کتے کا بھونکنا", ms = 750, key = "s_dog", user = "dog", build = dog },
  rain      = { name = "بارش", ms = 1800, key = "s_rain", user = "rain", build = rain },
  horn      = { name = "گاڑی کا ہارن", ms = 850, key = "s_horn", user = "horn", build = horn },
  cat       = { name = "بلی", ms = 900, key = "s_cat", user = "cat", build = meow },
}

local dlist = { "steps", "run", "glass", "keyTurn", "doorClose", "doorOpen", "window",
  "drawer", "paper", "phone", "carStart", "siren", "thunder", "clock", "bell", "alarm",
  "clatter", "tap", "dog", "rain", "horn", "cat" }

local function playDS(k, maxMs)
  local s = dsounds[k]
  return playNamed(s.user, s.key or ("d_" .. k), s.build, maxMs)
end

------------------------------------------------------------
-- سکرین اور بٹن
------------------------------------------------------------
local root = LinearLayout(activity)
root.setOrientation(1)
local scroll = ScrollView(activity)
scroll.addView(root)
activity.setContentView(scroll)

local status = TextView(activity)
status.setTextSize(22)
status.setPadding(24, 24, 24, 24)

local function say(text)
  status.setText(text)
  status.announceForAccessibility(text)
end

local function clearScreen(title)
  root.removeAllViews()
  status.setText(title)
  root.addView(status)
end

local function btn(text, fn)
  local b = Button(activity)
  b.setText(text)
  b.setOnClickListener(luajava.createProxy("android.view.View$OnClickListener", {
    onClick = function(v) fn() end
  }))
  root.addView(b)
  return b
end

-- نام بولنا، پھر پوری آواز بجانا، آواز ختم ہونے پر اگلی (کوئی آواز کٹتی نہیں)
local function learnChain(g, keys, nameFn, playFn, done)
  local i = 0
  local function nxt()
    if g ~= gen then return end
    i = i + 1
    if i > #keys then
      if done then done() end
      return
    end
    say(nameFn(keys[i]))
    later(1600, function()
      if g ~= gen then return end
      local d = playFn(keys[i]) or 1500
      later(d + 800, nxt)
    end)
  end
  nxt()
end

local showMenu

------------------------------------------------------------
-- خودکار اپڈیٹ (GitHub سے)
------------------------------------------------------------
local REPO_RAW = "https://raw.githubusercontent.com/q5844752-alt/Unique-puzzle-game/main/"
local VERSION_FILE = "version.txt"
local DEFAULT_CODE_FILE = "audio_puzzle_jieshuo_v8.txt"   -- version.txt میں دوسری لائن نہ ہو تو یہی فائل
local MAIN_PATHS = {
  "/storage/emulated/0/解说/Tools/Unique audio puzzle game/main.lua",
  "/sdcard/解说/Tools/Unique audio puzzle game/main.lua",
}
local STATE_FILE = activity.getFilesDir().getAbsolutePath() .. "/audiopuzzle_update.txt"
local updateReady = nil     -- اپڈیٹ انسٹال ہو چکی ہو تو نیا ورژن یہاں آتا ہے

local function verParts(v)
  local t = {}
  for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return t
end

-- کیا a، b سے نیا ورژن ہے؟
local function verNewer(a, b)
  local x, y = verParts(a), verParts(b)
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then return p > q end
  end
  return false
end

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function writeFile(p, s)
  return (pcall(function()
    local f = assert(io.open(p, "wb"))
    f:write(s)
    f:close()
  end))
end

-- آخری انسٹال کیا ہوا ورژن بھی یاد رکھتے ہیں تاکہ ایک ہی اپڈیٹ بار بار ڈاؤن لوڈ نہ ہو
local function currentVersion()
  local s = readFile(STATE_FILE)
  local iv = s and s:match("%d[%d%.]*")
  if iv and verNewer(iv, APP_VERSION) then return iv end
  return APP_VERSION
end

local function httpGet(url, connectMs, readMs)
  local body, err
  local ok, e = pcall(function()
    local u = luajava.newInstance("java.net.URL", url)
    local conn = u.openConnection()
    conn.setConnectTimeout(connectMs or 5000)
    conn.setReadTimeout(readMs or 10000)
    conn.setUseCaches(false)
    conn.setRequestProperty("User-Agent", "UniqueAudioPuzzle")
    local code = conn.getResponseCode()
    if code ~= 200 then error("HTTP " .. tostring(code)) end
    local is = conn.getInputStream()
    local sc = luajava.newInstance("java.util.Scanner", is, "UTF-8")
    sc.useDelimiter("\\A")
    if sc.hasNext() then body = tostring(sc.next()) else body = "" end
    sc.close()
    conn.disconnect()
  end)
  if not ok then err = tostring(e) end
  return body, err
end

local function targetMain()
  for _, p in ipairs(MAIN_PATHS) do
    if File(p).exists() then return p end
  end
  local ok, dir = pcall(function() return tostring(activity.getLuaDir()) end)
  if ok and dir and File(dir .. "/main.lua").exists() then return dir .. "/main.lua" end
  return nil
end

-- manual: بٹن سے دبایا ہو تو ہر نتیجہ بولا جاتا ہے؛ خودکار چیک میں صرف نیا ورژن ملنے پر
local function checkUpdate(manual)
  pcall(function()
    local SM = luajava.bindClass("android.os.StrictMode")
    local b = luajava.newInstance("android.os.StrictMode$ThreadPolicy$Builder")
    SM.setThreadPolicy(b.permitAll().build())
  end)
  local vbody, verr = httpGet(REPO_RAW .. VERSION_FILE .. "?t=" .. os.time(), 5000, 8000)
  if not vbody then
    if manual then say("اپڈیٹ چیک نہیں ہو سکی۔ انٹرنیٹ دیکھیں۔ (" .. tostring(verr) .. ")") end
    return
  end
  local lines = {}
  for ln in vbody:gmatch("[^\r\n]+") do
    lines[#lines + 1] = ln:match("^%s*(.-)%s*$")
  end
  local remoteVer = lines[1] and lines[1]:match("^%d[%d%.]*$")
  if not remoteVer then
    if manual then say("version.txt کی پہلی لائن میں صرف ورژن کا نمبر ہونا چاہیے، مثلاً 1.1۔") end
    return
  end
  local codeFile = lines[2]
  if not codeFile or not codeFile:match("^[%w_%.%-]+$") then codeFile = DEFAULT_CODE_FILE end
  local cur = currentVersion()
  if not verNewer(remoteVer, cur) then
    if manual then say("آپ کے پاس تازہ ترین ورژن " .. cur .. " ہے۔") end
    return
  end

  say("نیا ورژن " .. remoteVer .. " ملا۔ ڈاؤن لوڈ ہو رہا ہے، چند سیکنڈ انتظار کریں۔")
  later(500, function()
    local code, derr = httpGet(REPO_RAW .. codeFile .. "?t=" .. os.time(), 8000, 40000)
    if not code then
      say("اپڈیٹ ڈاؤن لوڈ نہیں ہو سکی (" .. tostring(derr) .. ")۔ پرانا ورژن چلتا رہے گا۔")
      return
    end
    -- فائل کی جانچ: لمبائی، گیم کی نشانیاں، اردو اور چینی حروف سلامت ہوں، اور کوڈ کی ساخت درست ہو
    if #code < 20000 or not code:find("APP_VERSION", 1, true) or not code:find("آڈیو", 1, true)
       or not code:find("解说", 1, true) then
      say("ڈاؤن لوڈ کی گئی فائل درست نہیں لگی، اس لیے اپڈیٹ نہیں کی گئی۔ پرانا ورژن چلتا رہے گا۔")
      return
    end
    local fn, lerr = load(code)
    if not fn then
      say("نئی فائل میں کوڈ کی غلطی ہے، اس لیے اپڈیٹ نہیں کی گئی۔ (" .. tostring(lerr) .. ")")
      return
    end
    local target = targetMain()
    if not target then
      say("main.lua کا راستہ نہیں ملا، اس لیے اپڈیٹ نہیں کی گئی۔")
      return
    end
    local old = readFile(target)
    if old then writeFile(target .. ".bak", old) end
    local okw = writeFile(target, code)
    local chk = okw and readFile(target)
    if not chk or #chk ~= #code then
      if old then writeFile(target, old) end
      say("نئی فائل محفوظ نہیں ہو سکی، پرانا ورژن بحال کر دیا گیا ہے۔")
      return
    end
    writeFile(STATE_FILE, remoteVer)
    updateReady = remoteVer
    showMenu()
    say("اپڈیٹ مکمل! ورژن " .. remoteVer .. " انسٹال ہو گیا ہے۔ نیا ورژن چلانے کے لیے گیم بند کر کے دوبارہ کھولیں۔")
  end)
end

------------------------------------------------------------
-- گیم 1: آوازوں کی یادداشت
------------------------------------------------------------
local showMemory
do
local m = {}

local function playSeq(done)
  m.busy = true
  local i = 0
  local function step()
    i = i + 1
    if i > #m.seq then
      m.busy = false
      if done then done() end
      return
    end
    local d = playSound(m.seq[i], 8000) or 800
    later(math.max(m.gap, d + 300), step)
  end
  step()
end

local function nextLevel()
  local nSounds = math.min(#sounds, 3 + math.floor((m.level - 1) / 2))
  local len = math.min(15, 2 + m.level)
  m.gap = math.max(900, 1700 - 100 * m.level)
  m.seq = {}
  for i = 1, len do m.seq[i] = math.random(nSounds) end
  m.pos = 0
  m.replays = 2
  say("لیول " .. m.level .. "۔ غور سے سنیں۔")
  later(1500, function()
    playSeq(function()
      say("اب اسی ترتیب سے آوازوں کے بٹن دبائیں۔")
    end)
  end)
end

local function pressSound(k)
  if m.busy or m.over or not m.seq then return end
  playSound(k, 4000)
  m.pos = m.pos + 1
  if k ~= m.seq[m.pos] then
    later(900, function() fx("fail") end)
    local names = {}
    for i = 1, #m.seq do names[#names + 1] = sounds[m.seq[i]].name end
    local reached = m.level - 1
    if reached > prog.best1 then prog.best1 = reached; saveProg() end
    m.over = true
    later(1700, function()
      say("غلط۔ صحیح ترتیب: " .. table.concat(names, "، ") ..
          "۔ آپ لیول " .. m.level .. " تک پہنچے۔ دوبارہ کھیلنے کے لیے شروع کریں۔")
    end)
    return
  end
  if m.pos == #m.seq then
    m.busy = true
    later(1000, function() fx("ding") end)
    m.level = m.level + 1
    later(2000, nextLevel)
  end
end

local function learnSounds()
  if m.busy then return end
  m.busy = true
  gen = gen + 1
  local keys = {}
  for i = 1, #sounds do keys[i] = i end
  learnChain(gen, keys, function(i) return sounds[i].name end,
    function(i) return playSound(i, 10000) end,
    function()
      m.busy = false
      say("آوازیں سننا مکمل۔")
    end)
end

showMemory = function()
  clearScreen("آوازوں کی یادداشت۔ پہلے آوازیں سیکھیں، پھر شروع کریں۔")
  btn("آوازیں سیکھیں (نام کے ساتھ)", learnSounds)
  btn("شروع کریں", function()
    if m.busy and not m.over then return end
    m.level = 1
    m.over = false
    m.busy = true
    nextLevel()
  end)
  btn("ترتیب دوبارہ سنیں", function()
    if m.busy or m.over or not m.seq then return end
    if m.replays > 0 then
      m.replays = m.replays - 1
      m.pos = 0
      say("دوبارہ سنیں۔")
      later(1000, function() playSeq() end)
    else
      say("اس لیول میں اب دوبارہ سننا ممکن نہیں۔")
    end
  end)
  for k, snd in ipairs(sounds) do
    btn(snd.name, function() pressSound(k) end)
  end
  btn("واپس مینو میں", function() showMenu() end)
  m = { busy = false, over = false }
end

end

------------------------------------------------------------
-- گیم 2: تجوری کھولو (پیانو کے سُر)
------------------------------------------------------------
local showSafe
do
local BASE = 48
local sg = {}

local function playNote(k)
  local midi = BASE + k
  playNamed(nil, "p" .. midi, function() return piano(midi) end)
end

local function newSafe()
  sg.span = math.min(36, 18 + 3 * sg.round)
  sg.target = math.random(4, sg.span - 4)
  repeat sg.cur = math.random(0, sg.span)
  until math.abs(sg.cur - sg.target) >= 8
  sg.moves, sg.hints, sg.open = 0, 2, false
  say("تجوری نمبر " .. sg.round .. "۔ پیانو کے سُر بدل کر چھپا ہوا صحیح سُر تلاش کریں۔")
  playNote(sg.cur)
end

local function turn(d)
  if sg.open or not sg.target then return end
  sg.cur = sg.cur + d
  sg.moves = sg.moves + 1
  if sg.cur < 0 then sg.cur = 0; say("سب سے نیچا سُر۔") end
  if sg.cur > sg.span then sg.cur = sg.span; say("سب سے اونچا سُر۔") end
  playNote(sg.cur)

  if sg.cur == sg.target then
    sg.open = true
    local pts = math.max(10, 100 - sg.moves * 4 - (2 - sg.hints) * 10)
    sg.score = sg.score + pts
    if sg.score > prog.best2 then prog.best2 = sg.score; saveProg() end
    later(900, function() fx("click") end)
    later(1500, function() fx("open") end)
    later(2600, function()
      say("تجوری کھل گئی! " .. sg.moves .. " حرکتوں میں۔ اس کا سکور " .. pts ..
          "۔ کل سکور " .. sg.score .. "۔ اگلی تجوری کے لیے اگلی تجوری کا بٹن دبائیں۔")
    end)
  end
end

showSafe = function()
  clearScreen("تجوری کھولو۔ ایک چھپا ہوا پیانو سُر ہے۔ سُر بدل کر اسے تلاش کریں۔ صحیح سُر پر تجوری کھل جائے گی۔")
  btn("اگلا سُر اوپر", function() turn(1) end)
  btn("پچھلا سُر نیچے", function() turn(-1) end)
  btn("پانچ سُر اوپر", function() turn(5) end)
  btn("پانچ سُر نیچے", function() turn(-5) end)
  btn("موجودہ سُر دوبارہ سنیں", function() if sg.cur then playNote(sg.cur) end end)
  btn("ہدف کا سُر سنیں (ہنٹ)", function()
    if sg.open or not sg.target then return end
    if sg.hints > 0 then
      sg.hints = sg.hints - 1
      say("ہدف کا سُر۔ باقی ہنٹ " .. sg.hints)
      playNote(sg.target)
      later(1500, function() playNote(sg.cur) end)
    else
      say("ہنٹ ختم ہو چکے۔")
    end
  end)
  btn("اگلی تجوری / نیا کھیل", function()
    if not sg.round then
      sg.round, sg.score = 1, 0
    elseif sg.open then
      sg.round = sg.round + 1
    end
    newSafe()
  end)
  btn("واپس مینو میں", function() showMenu() end)
  sg = {}
end

end

------------------------------------------------------------
-- گیم 3: پراسرار جاسوس
------------------------------------------------------------
local showDetective
do
-- events: واقعات کی ترتیب
-- mc: ہاتھ سے لکھے منطقی سوال (ans صحیح، wrong غلط، why وجہ)
-- auto: خود بننے والے سوال: first, last, before, after, count, order

-- راؤنڈ 1: چوری کے معمے
local round1 = {
  { title = "کھڑکی کا چور",
    intro = "رات کا وقت ہے۔ ایک گھر کے اندر سے کچھ آوازیں آ رہی ہیں۔ غور سے سنیں۔",
    events = { "steps", "glass", "steps", "keyTurn", "doorClose" },
    mc = {
      { text = "چور اندر کس چیز کے ذریعے آیا؟",
        ans = "کھڑکی کا شیشہ توڑ کر",
        wrong = { "چابی سے دروازہ کھول کر", "چھت کا راستہ استعمال کر کے", "پچھلا دروازہ توڑ کر" },
        why = "چابی گھمانے سے پہلے شیشہ ٹوٹنے کی آواز آئی تھی۔" },
      { text = "چور باہر کیسے نکلا؟",
        ans = "اندر سے چابی گھما کر دروازے سے",
        wrong = { "کھڑکی سے کود کر", "چھت سے", "دیوار توڑ کر" },
        why = "آخر میں چابی گھمانے اور دروازہ بند ہونے کی آواز آئی۔" },
    },
    auto = { { t = "order", from = 1, to = 5 } } },

  { title = "چابی کا راز",
    intro = "ایک دکان کے باہر کتا بھونک رہا ہے۔ پھر کچھ عجیب آوازیں آتی ہیں۔",
    events = { "dog", "steps", "keyTurn", "doorOpen", "paper", "alarm", "run", "carStart" },
    mc = {
      { text = "چور اندر کیسے داخل ہوا؟",
        ans = "چابی سے دروازہ کھول کر",
        wrong = { "کھڑکی توڑ کر", "کھڑکی کھسکا کر", "چھت کے راستے" },
        why = "شیشہ ٹوٹنے یا کھڑکی کی آواز نہیں آئی، چابی اور دروازہ کھلنے کی آواز آئی۔" },
      { text = "الارم بجنے کے بعد چور نے کیا کیا؟",
        ans = "بھاگ کر گاڑی میں فرار ہو گیا",
        wrong = { "وہیں چھپ گیا", "پولیس کو فون کیا", "دوبارہ تلاشی لینے لگا" },
        why = "الارم کے بعد بھاگتے قدم اور گاڑی سٹارٹ ہونے کی آواز آئی۔" },
    },
    auto = { { t = "first" }, { t = "before", idx = 6 }, { t = "order", from = 3, to = 7 } } },

  { title = "بارش کی رات",
    intro = "تیز بارش ہو رہی ہے اور بجلی چمک رہی ہے۔ ایک گھر میں کوئی داخل ہو رہا ہے۔",
    events = { "rain", "thunder", "steps", "window", "steps", "drawer", "phone", "run", "doorClose" },
    mc = {
      { text = "چور گھر میں کیسے داخل ہوا؟",
        ans = "کھڑکی کھسکا کر",
        wrong = { "شیشہ توڑ کر", "چابی سے دروازہ کھول کر", "دروازہ توڑ کر" },
        why = "شیشہ ٹوٹنے کی آواز نہیں آئی، صرف کھڑکی کھسکنے کی آواز آئی۔" },
      { text = "اندر آ کر چور نے کیا کیا؟",
        ans = "درازوں میں کچھ تلاش کیا",
        wrong = { "پانی پیا", "فون پر بات کی", "سو گیا" },
        why = "قدموں کے بعد دراز کھلنے کی آواز آئی۔" },
      { text = "فون بجنے کے بعد چور نے کیا کیا؟",
        ans = "گھبرا کر بھاگ گیا",
        wrong = { "فون اٹھا لیا", "وہیں بیٹھ گیا", "کھڑکی بند کر دی" },
        why = "فون کے فوراً بعد بھاگتے قدم سنائی دیے۔" },
    },
    auto = { { t = "last" }, { t = "order", from = 4, to = 8 } } },

  { title = "کھڑکی اور دروازہ",
    intro = "ایک دکان میں رات کو آوازیں آتی ہیں۔ غور کریں کہ کون سی چیز کس کے بعد ہوئی۔",
    events = { "window", "steps", "keyTurn", "doorOpen", "steps", "clatter", "alarm", "run", "carStart", "siren" },
    mc = {
      { text = "چابی گھمانے کی آواز کھڑکی کے بعد آئی۔ اس سے کیا ثابت ہوتا ہے؟",
        ans = "چور کھڑکی سے آیا اور اندر سے دروازہ کھولا",
        wrong = { "چور کے پاس شروع سے چابی تھی", "دکان کا مالک آ گیا", "کسی نے دروازہ توڑ دیا" },
        why = "پہلے کھڑکی کھسکی، دروازہ کھولنے کی آواز بعد میں آئی۔" },
      { text = "الارم بجنے کے بعد چور نے کیا کیا؟",
        ans = "بھاگ کر گاڑی میں نکل گیا",
        wrong = { "وہیں بیٹھ گیا", "پولیس کے پاس گیا", "کھڑکی سے واپس چلا گیا" },
        why = "الارم کے بعد بھاگتے قدم اور گاڑی کی آواز آئی۔" },
    },
    auto = { { t = "before", idx = 7 }, { t = "after", idx = 9 }, { t = "order", from = 6, to = 10 } } },

  { title = "خالی گھر",
    intro = "ایک خالی گھر میں گھڑی چل رہی ہے۔ پھر کچھ ہوتا ہے۔",
    events = { "clock", "phone", "phone", "phone", "steps", "window", "tap", "doorClose" },
    mc = {
      { text = "فون بار بار بجنے پر کسی نے اٹھایا؟",
        ans = "نہیں، گھر خالی تھا",
        wrong = { "ہاں، فوراً اٹھایا", "ایک بار اٹھایا", "دوسری گھنٹی پر اٹھایا" },
        why = "فون کے بعد کوئی ردعمل نہیں آیا، بس گھنٹیاں بجتی رہیں۔" },
      { text = "چور اندر کیسے آیا؟",
        ans = "کھڑکی کھول کر",
        wrong = { "دروازہ توڑ کر", "چابی سے", "شیشہ توڑ کر" },
        why = "کھڑکی کھسکنے کی آواز آئی تھی۔" },
    },
    auto = { { t = "count", key = "phone" }, { t = "before", idx = 7 }, { t = "order", from = 4, to = 8 } } },

  { title = "سائرن کی رات",
    intro = "ایک گلی میں کتا بھونکتا ہے، پھر ایک گھر میں کچھ ہوتا ہے۔",
    events = { "dog", "steps", "glass", "alarm", "run", "carStart", "horn", "siren" },
    mc = {
      { text = "چور اندر کیسے آیا؟",
        ans = "شیشہ توڑ کر",
        wrong = { "چابی سے", "کھڑکی کھسکا کر", "چھت سے" },
        why = "قدموں کے بعد شیشہ ٹوٹنے کی آواز آئی۔" },
      { text = "پولیس کے آنے کی نشانی کون سی آواز تھی؟",
        ans = "پولیس کا سائرن",
        wrong = { "کتے کا بھونکنا", "گاڑی کا ہارن", "الارم" },
        why = "آخری آواز سائرن کی تھی۔" },
    },
    auto = { { t = "after", idx = 4 }, { t = "before", idx = 8 }, { t = "order", from = 3, to = 7 } } },

  { title = "گھنٹی کی رات",
    intro = "ایک بڑی عمارت میں گھڑی اور گھنٹی بجتی ہے۔ اس کے بعد بہت کچھ ہوتا ہے۔",
    events = { "clock", "bell", "steps", "keyTurn", "doorOpen", "steps", "paper", "drawer",
               "glass", "clatter", "alarm", "run", "carStart", "siren" },
    mc = {
      { text = "چور نے دروازہ کیسے کھولا؟",
        ans = "چابی سے",
        wrong = { "دروازہ توڑ کر", "کھڑکی سے آ کر", "کسی نے اندر سے کھولا" },
        why = "قدموں کے بعد چابی گھومی اور پھر دروازہ کھلا۔" },
      { text = "الارم کس واقعے کے فوراً بعد بجا؟",
        ans = "کسی چیز کے گرنے کے بعد",
        wrong = { "شیشہ ٹوٹنے کے فوراً بعد", "دراز کھلنے کے بعد", "دروازہ کھلنے کے فوراً بعد" },
        why = "شیشہ ٹوٹا، پھر کچھ گرا، اور اس کے بعد الارم بجا۔" },
    },
    auto = { { t = "before", idx = 10 }, { t = "after", idx = 5 },
             { t = "order", from = 6, to = 10 }, { t = "order", from = 10, to = 14 } } },

  { title = "آخری معمہ",
    intro = "طوفانی رات ہے۔ ایک پرانے بنگلے میں مشکوک آوازیں آ رہی ہیں۔ یہ اس راؤنڈ کا سب سے مشکل کیس ہے۔",
    events = { "rain", "thunder", "steps", "window", "tap", "steps", "keyTurn", "doorOpen",
               "phone", "phone", "run", "doorClose", "carStart", "siren" },
    mc = {
      { text = "چور اندر کیسے آیا؟",
        ans = "کھڑکی کھسکا کر",
        wrong = { "شیشہ توڑ کر", "چابی سے دروازہ کھول کر", "چھت سے" },
        why = "شیشہ ٹوٹنے کی آواز نہیں آئی، صرف کھڑکی کھسکی۔" },
      { text = "فون کی گھنٹی بجتے ہی چور نے کیا کیا؟",
        ans = "گھبرا کر بھاگ نکلا",
        wrong = { "فون اٹھایا", "نل کھول دیا", "وہیں انتظار کیا" },
        why = "فون کے فوراً بعد بھاگتے قدم سنائی دیے۔" },
    },
    auto = { { t = "count", key = "phone" }, { t = "before", idx = 11 }, { t = "after", idx = 4 },
             { t = "order", from = 3, to = 7 }, { t = "order", from = 8, to = 12 } } },
}

-- راؤنڈ 2: روزمرہ زندگی کے معمے (کوئی چور نہیں)
local round2 = {
  { title = "صبح کا آغاز",
    intro = "ایک گھر میں صبح ہو رہی ہے۔ سنیں کہ گھر والا کیا کیا کرتا ہے۔",
    events = { "alarm", "steps", "tap", "drawer", "doorClose", "keyTurn", "carStart" },
    mc = {
      { text = "گھر سے نکلتے وقت دروازے کا کیا ہوا؟",
        ans = "بند کر کے تالا لگایا گیا",
        wrong = { "کھلا چھوڑ دیا گیا", "صرف بند کیا، تالا نہیں لگایا", "کھڑکی سے نکلا" },
        why = "دروازہ بند ہونے کے بعد چابی گھومی۔" },
      { text = "وہ گھر سے کس سواری پر گیا؟",
        ans = "گاڑی پر",
        wrong = { "پیدل", "سائیکل پر", "ٹرین پر" },
        why = "آخر میں گاڑی سٹارٹ ہونے کی آواز آئی۔" },
    },
    auto = { { t = "first" }, { t = "order", from = 3, to = 7 } } },

  { title = "مہمان کی آمد",
    intro = "ایک گھر کے باہر کوئی آ رہا ہے۔ سنیں کیا ہوتا ہے۔",
    events = { "horn", "dog", "steps", "bell", "steps", "keyTurn", "doorOpen", "steps" },
    mc = {
      { text = "مہمان کیسے پہنچا؟",
        ans = "گاڑی میں",
        wrong = { "پیدل", "سائیکل پر", "ہوائی جہاز سے" },
        why = "سب سے پہلے گاڑی کا ہارن سنائی دیا۔" },
      { text = "دروازہ کھلنے سے پہلے گھر والے نے کیا کیا؟",
        ans = "تالا کھولا",
        wrong = { "کھڑکی توڑی", "فون کیا", "نل بند کیا" },
        why = "دروازہ کھلنے سے پہلے چابی گھومی۔" },
    },
    auto = { { t = "count", key = "steps" }, { t = "before", idx = 6 }, { t = "order", from = 4, to = 8 } } },

  { title = "طوفانی شام",
    intro = "شام کو موسم بدل رہا ہے۔ ایک گھر کی آوازیں سنیں۔",
    events = { "rain", "thunder", "steps", "window", "steps", "doorClose", "phone" },
    mc = {
      { text = "کھڑکی کھسکانے کی سب سے ممکنہ وجہ کیا تھی؟",
        ans = "بارش اور طوفان سے بچنے کے لیے بند کرنا",
        wrong = { "تازہ ہوا کے لیے کھولنا", "کسی کو بلانا", "باہر دیکھنا" },
        why = "پہلے بارش اور گرج کی آواز آئی، پھر کھڑکی کھسکی۔" },
      { text = "دروازہ بند ہونے کے بعد کیا ہوا؟",
        ans = "فون کی گھنٹی بجی",
        wrong = { "بجلی کڑکی", "کتا بھونکا", "الارم بجا" },
        why = "آخری آواز فون کی گھنٹی تھی۔" },
    },
    auto = { { t = "first" }, { t = "before", idx = 4 }, { t = "order", from = 3, to = 7 } } },

  { title = "ہنگامی صورتحال",
    intro = "ایک گھر میں اچانک کچھ ہوتا ہے۔ جلدی سے سنیں۔",
    events = { "phone", "run", "doorOpen", "carStart", "horn", "siren" },
    mc = {
      { text = "فون کی گھنٹی کے بعد کیا ہوا؟",
        ans = "کوئی بھاگ کر گھر سے نکلا",
        wrong = { "کسی نے فون اٹھایا اور بیٹھ گیا", "نل کھولا گیا", "کتا بھونکا" },
        why = "فون کے فوراً بعد بھاگتے قدم اور دروازہ کھلنے کی آواز آئی۔" },
      { text = "آخری آواز کس قسم کی گاڑی کی تھی؟",
        ans = "سائرن والی گاڑی",
        wrong = { "عام گاڑی", "ٹرین", "ٹرک" },
        why = "آخر میں سائرن سنائی دیا۔" },
    },
    auto = { { t = "before", idx = 5 }, { t = "order", from = 2, to = 6 } } },

  { title = "باورچی خانے کا حادثہ",
    intro = "باورچی خانے میں کچھ ہو رہا ہے۔ غور سے سنیں۔",
    events = { "tap", "steps", "cat", "clatter", "glass", "run", "drawer" },
    mc = {
      { text = "حادثہ کس چیز کے گرنے سے شروع ہوا؟",
        ans = "دھاتی برتن",
        wrong = { "شیشے کا گلاس", "فون", "گھڑی" },
        why = "شیشہ ٹوٹنے سے پہلے دھاتی چیز گرنے کی آواز آئی۔" },
      { text = "شیشہ ٹوٹنے کے بعد کیا ہوا؟",
        ans = "کوئی بھاگتا ہوا آیا اور دراز کھولی",
        wrong = { "کوئی گاڑی لے کر نکلا", "فون بجا", "دروازہ بند ہوا" },
        why = "شیشہ ٹوٹنے کے بعد بھاگتے قدم اور دراز کی آواز آئی۔" },
    },
    auto = { { t = "after", idx = 3 }, { t = "last" }, { t = "order", from = 3, to = 7 } } },

  { title = "رات کا چوکیدار",
    intro = "ایک چوکیدار رات کو اپنی ڈیوٹی کر رہا ہے۔",
    events = { "clock", "steps", "keyTurn", "doorOpen", "steps", "dog", "steps", "doorClose", "keyTurn" },
    mc = {
      { text = "چوکیدار نے اندر جانے کے لیے کیا کیا؟",
        ans = "تالا کھول کر دروازہ کھولا",
        wrong = { "کھڑکی سے گھسا", "دروازہ توڑا", "کسی کو بلایا" },
        why = "چابی گھومی اور پھر دروازہ کھلا۔" },
      { text = "چوکیدار نے جاتے ہوئے کیا کیا؟",
        ans = "دروازہ بند کر کے تالا لگایا",
        wrong = { "دروازہ کھلا چھوڑ دیا", "کھڑکی سے نکلا", "گاڑی میں بیٹھ گیا" },
        why = "آخر میں دروازہ بند ہوا اور چابی گھومی۔" },
    },
    auto = { { t = "count", key = "keyTurn" }, { t = "before", idx = 6 }, { t = "order", from = 3, to = 7 } } },

  { title = "اسکول کی گھنٹی",
    intro = "ایک اسکول میں دن گزر رہا ہے۔ گھنٹیاں اور قدم سنیں۔",
    events = { "clock", "bell", "run", "steps", "doorClose", "bell", "run", "horn" },
    mc = {
      { text = "چھٹی کی گھنٹی کے بعد بچے کیسے نکلے؟",
        ans = "بھاگتے ہوئے",
        wrong = { "آرام سے چلتے ہوئے", "گاڑی میں", "خاموشی سے کھڑے رہے" },
        why = "دوسری گھنٹی کے بعد بھاگتے قدم سنائی دیے۔" },
      { text = "آخر میں کس چیز کی آواز آئی؟",
        ans = "گاڑی کا ہارن",
        wrong = { "ٹرین کی سیٹی", "الارم", "فون کی گھنٹی" },
        why = "آخری آواز گاڑی کے ہارن کی تھی۔" },
    },
    auto = { { t = "count", key = "bell" }, { t = "before", idx = 6 }, { t = "order", from = 3, to = 7 } } },

  { title = "پرانی حویلی",
    intro = "طوفانی رات میں ایک چوکیدار پرانی حویلی کا چکر لگاتا ہے۔ یہ اس راؤنڈ کا سب سے مشکل کیس ہے۔",
    events = { "rain", "thunder", "steps", "doorOpen", "cat", "steps", "drawer", "paper",
               "keyTurn", "window", "tap", "phone", "run", "doorClose" },
    mc = {
      { text = "حویلی میں کون سا جانور موجود تھا؟",
        ans = "بلی",
        wrong = { "کتا", "گھوڑا", "کوئی نہیں" },
        why = "دروازہ کھلنے کے بعد بلی کی آواز آئی۔" },
      { text = "فون کی گھنٹی کے بعد کیا ہوا؟",
        ans = "کوئی بھاگ کر نکلا اور دروازہ بند کر دیا",
        wrong = { "نل کھولا گیا", "کھڑکی کھسکی", "کتا بھونکا" },
        why = "فون کے بعد بھاگتے قدم اور دروازہ بند ہونے کی آواز آئی۔" },
    },
    auto = { { t = "count", key = "steps" }, { t = "before", idx = 12 }, { t = "after", idx = 9 },
             { t = "order", from = 4, to = 8 }, { t = "order", from = 9, to = 13 } } },
}

local rounds = { round1, round2 }

local function evName(k) return dsounds[k].name end

local function mkQ(text, ans, wrongs, why)
  local opts = { ans }
  for _, w in ipairs(wrongs) do opts[#opts + 1] = w end
  shuffle(opts)
  return { text = text, ans = ans, opts = opts, why = why }
end

local function distract(c, ans, n)
  local pool, seen = {}, { [ans] = true }
  for _, k in ipairs(c.events) do
    local nm = evName(k)
    if not seen[nm] then seen[nm] = true; pool[#pool + 1] = nm end
  end
  shuffle(pool)
  local all = {}
  for _, v in pairs(dsounds) do all[#all + 1] = v.name end
  shuffle(all)
  for _, nm in ipairs(all) do
    if #pool >= n then break end
    if not seen[nm] then seen[nm] = true; pool[#pool + 1] = nm end
  end
  local out = {}
  for i = 1, n do out[i] = pool[i] end
  return out
end

local function join(t) return table.concat(t, "، پھر ") end

local function buildQs(c)
  local qs = {}
  local ev = c.events
  for _, q in ipairs(c.mc or {}) do
    qs[#qs + 1] = mkQ(q.text, q.ans, q.wrong, q.why)
  end
  for _, a in ipairs(c.auto or {}) do
    if a.t == "first" then
      local ans = evName(ev[1])
      qs[#qs + 1] = mkQ("سب سے پہلے کون سی آواز آئی؟", ans, distract(c, ans, 3))
    elseif a.t == "last" then
      local ans = evName(ev[#ev])
      qs[#qs + 1] = mkQ("سب سے آخر میں کون سی آواز آئی؟", ans, distract(c, ans, 3))
    elseif a.t == "before" then
      local ans = evName(ev[a.idx - 1])
      qs[#qs + 1] = mkQ(evName(ev[a.idx]) .. " سے فوراً پہلے کون سی آواز آئی تھی؟",
                        ans, distract(c, ans, 3))
    elseif a.t == "after" then
      local ans = evName(ev[a.idx + 1])
      qs[#qs + 1] = mkQ(evName(ev[a.idx]) .. " کے فوراً بعد کون سی آواز آئی؟",
                        ans, distract(c, ans, 3))
    elseif a.t == "count" then
      local cnt = 0
      for _, k in ipairs(ev) do if k == a.key then cnt = cnt + 1 end end
      local nums, seen = {}, {}
      for _, v in ipairs({ cnt, cnt + 1, cnt + 2, cnt - 1, cnt + 3 }) do
        if v >= 1 and not seen[v] and #nums < 4 then seen[v] = true; nums[#nums + 1] = v end
      end
      local wrongs = {}
      for _, v in ipairs(nums) do
        if v ~= cnt then wrongs[#wrongs + 1] = v .. " بار" end
      end
      qs[#qs + 1] = mkQ(evName(a.key) .. " کی آواز کتنی بار آئی؟", cnt .. " بار", wrongs)
    elseif a.t == "order" then
      local names = {}
      for i = a.from, a.to do names[#names + 1] = evName(ev[i]) end
      local correct = join(names)
      local seen, ds, tries = { [correct] = true }, {}, 0
      while #ds < 3 and tries < 50 do
        tries = tries + 1
        local t = {}
        for i, nm in ipairs(names) do t[i] = nm end
        for _ = 1, random(1, 2) do
          local i = random(1, #t - 1)
          t[i], t[i + 1] = t[i + 1], t[i]
        end
        local s = join(t)
        if not seen[s] then seen[s] = true; ds[#ds + 1] = s end
      end
      qs[#qs + 1] = mkQ("آوازوں کی صحیح ترتیب کیا تھی؟ (آواز نمبر " .. a.from ..
                        " سے " .. a.to .. " تک)", correct, ds)
    end
  end
  return qs
end

local dt = {}
local startCase, showQuestion, finishCase, answerQ, replayScene

local function playScene(c, g, done)
  dt.busy = true
  local i = 0
  local function step()
    if g ~= gen then return end
    i = i + 1
    if i > #c.events then
      dt.busy = false
      if done then done() end
      return
    end
    local k = c.events[i]
    local dur = playDS(k, 20000) or dsounds[k].ms
    later(dur + 600, step)
  end
  step()
end

local function learnDS()
  if dt.busy then return end
  gen = gen + 1
  dt.busy = true
  learnChain(gen, dlist, function(k) return dsounds[k].name end,
    function(k) return playDS(k, 20000) end,
    function()
      dt.busy = false
      say("جاسوسی آوازیں سننا مکمل۔")
    end)
end

startCase = function(round, n)
  local cs = rounds[round]
  if not cs or n > #cs then
    say("تمام کیس مکمل ہو چکے ہیں۔ کل سکور " .. dt.total .. "۔")
    return
  end
  gen = gen + 1
  local g = gen
  local c = cs[n]
  dt.round, dt.ci, dt.qs, dt.qi, dt.right, dt.replays, dt.busy =
    round, n, buildQs(c), 1, 0, 3, true
  clearScreen("")
  say("راؤنڈ " .. round .. "، کیس " .. n .. " از " .. #cs .. ": " .. c.title .. "۔ " .. c.intro)
  btn("واپس", function() showDetective() end)
  laterG(g, 8000, function()
    playScene(c, g, function()
      laterG(g, 800, function() showQuestion(g) end)
    end)
  end)
end

showQuestion = function(g)
  if g ~= gen then return end
  local q = dt.qs[dt.qi]
  clearScreen("")
  say("سوال " .. dt.qi .. " از " .. #dt.qs .. ": " .. q.text)
  for _, opt in ipairs(q.opts) do
    btn(opt, function() answerQ(g, opt) end)
  end
  btn("منظر دوبارہ سنیں (باقی " .. dt.replays .. ")", function() replayScene(g) end)
  btn("واپس", function() showDetective() end)
  dt.busy = false
end

replayScene = function(g)
  if dt.busy or g ~= gen then return end
  if dt.replays <= 0 then
    say("اب دوبارہ سننے کا موقع باقی نہیں۔")
    return
  end
  dt.replays = dt.replays - 1
  dt.busy = true
  local c = rounds[dt.round][dt.ci]
  say("منظر دوبارہ سنیں۔")
  laterG(g, 1500, function()
    playScene(c, g, function()
      laterG(g, 800, function() showQuestion(g) end)
    end)
  end)
end

answerQ = function(g, opt)
  if dt.busy or g ~= gen then return end
  dt.busy = true
  local q = dt.qs[dt.qi]
  local why = q.why and ("۔ " .. q.why) or ""
  if opt == q.ans then
    dt.right = dt.right + 1
    say("درست!" .. why)
    fx("ding")
  else
    say("غلط۔ صحیح جواب: " .. q.ans .. why)
    fx("fail")
  end
  laterG(g, 5000, function()
    dt.qi = dt.qi + 1
    if dt.qi > #dt.qs then finishCase(g) else showQuestion(g) end
  end)
end

finishCase = function(g)
  if g ~= gen then return end
  local key = dt.round * 100 + dt.ci
  if not dt.done[key] then
    dt.done[key] = true
    dt.total = dt.total + dt.right
  end
  local cs = rounds[dt.round]
  local extra = ""

  if dt.ci % 2 == 0 then
    -- دو کیس مکمل: پیش رفت محفوظ ہوتی ہے (2، 4، 6، 8 پر لاک)
    local newRound, newStart = dt.round, dt.ci + 1
    if dt.ci >= #cs then
      newRound, newStart = dt.round + 1, 1
      extra = " راؤنڈ " .. dt.round .. " مکمل ہو گیا!"
      if newRound > #rounds then extra = extra .. " آپ نے تمام راؤنڈ مکمل کر لیے!" end
    end
    if newRound > prog.round or (newRound == prog.round and newStart > prog.start) then
      prog.round, prog.start, prog.total = newRound, newStart, dt.total
    end
    if dt.total > prog.best3 then prog.best3 = dt.total end
    saveProg()
    extra = extra .. " آپ کی پیش رفت محفوظ ہو گئی۔"
  else
    extra = " اگلا کیس بھی مکمل کریں تاکہ پیش رفت محفوظ ہو۔"
  end

  clearScreen("")
  local msg = "کیس مکمل۔ آپ نے " .. #dt.qs .. " میں سے " .. dt.right ..
              " جواب درست دیے۔ کل سکور " .. dt.total .. "۔" .. extra
  if dt.right >= math.ceil(#dt.qs * 0.6) then
    msg = msg .. " شاندار جاسوسی!"
    fx("open")
  end
  say(msg)

  local nr, nc
  if dt.ci < #cs then nr, nc = dt.round, dt.ci + 1
  elseif dt.round < #rounds then nr, nc = dt.round + 1, 1 end
  if nr then
    btn("اگلا کیس", function() startCase(nr, nc) end)
  end
  btn("یہی کیس دوبارہ", function() startCase(dt.round, dt.ci) end)
  btn("واپس", function() showDetective() end)
  dt.busy = false
end

local function resetProg()
  if not dt.confirm then
    dt.confirm = true
    say("پوری پیش رفت مٹانے کے لیے یہی بٹن دوبارہ دبائیں۔")
    return
  end
  prog.round, prog.start, prog.total = 1, 1, 0
  saveProg()
  showDetective()
  say("پیش رفت مٹا دی گئی۔ اب راؤنڈ 1 کیس 1 سے شروع ہوگا۔")
end

showDetective = function()
  gen = gen + 1
  dt = { total = prog.total, done = {}, busy = false }
  local msg = "پراسرار جاسوس۔ ایک واقعے کی آوازیں سنیں، پھر سوالوں کے جواب دیں۔ پہلے جاسوسی آوازیں سیکھ لیں۔ "
  if prog.round > #rounds then
    msg = msg .. "آپ نے تمام راؤنڈ مکمل کر لیے ہیں۔ کل سکور " .. prog.total .. "۔"
  else
    msg = msg .. "اب راؤنڈ " .. prog.round .. " کا کیس نمبر " .. prog.start ..
          " ہے۔ ہر بار دو کیس کھیلنے ہوتے ہیں، تب پیش رفت محفوظ ہوتی ہے۔ کل سکور " .. prog.total .. "۔"
  end
  clearScreen(msg)
  btn("جاسوسی آوازیں سیکھیں (نام کے ساتھ)", learnDS)
  if prog.round <= #rounds then
    btn("راؤنڈ " .. prog.round .. " کیس " .. prog.start .. " سے جاری رکھیں", function()
      startCase(prog.round, prog.start)
    end)
  end
  btn("نئے سرے سے شروع کریں", resetProg)
  btn("واپس مینو میں", function() showMenu() end)
end

end

local showHorror, scanHorror, horrorStatus
local horrorInfo = { files = {}, count = 0, dir = nil }

------------------------------------------------------------
-- ہارر کی پس منظر کی موسیقی (Horror audio sounds فولڈر میں HorrorMusicLoop.wav)
-- ہلکی آواز میں بار بار چلتی ہے؛ فائل بعد میں رکھیں تو اگلے سین پر خود شروع ہو جاتی ہے
------------------------------------------------------------
local music = { mp = nil, paused = false }

local function musicFile()
  for _, n in ipairs({ "HorrorMusicLoop", "HorrorMusic", "HorrorBackgroundMusic", "BackgroundMusic" }) do
    local p = horrorInfo.files[norm(n)] or userFiles[norm(n)]
    if p then return p end
  end
  return nil
end

local function startMusic()
  if music.mp then
    if music.paused then
      pcall(function() music.mp.start() end)
      music.paused = false
    end
    return
  end
  local p = musicFile()
  if not p and os.time() - lastScanH >= 3 then
    scanHorror()
    p = musicFile()
  end
  if not p then return end
  pcall(function()
    local mp = MediaPlayer()
    mp.setDataSource(p)
    mp.prepare()
    mp.setLooping(true)
    mp.setVolume(0.25, 0.25)
    mp.start()
    music.mp = mp
    music.paused = false
  end)
end

local function pauseMusic()
  if music.mp and not music.paused then
    pcall(function() music.mp.pause() end)
    music.paused = true
  end
end

local function stopMusic()
  if music.mp then
    pcall(function() music.mp.stop() end)
    pcall(function() music.mp.release() end)
    music.mp = nil
    music.paused = false
  end
end


------------------------------------------------------------
-- گیم 4: ہارر - ویران حویلی سے فرار
-- آوازیں فولڈر: .../Unique audio puzzle game/Horror audio sounds
------------------------------------------------------------
do
  local MAXC = 6                       -- ہمت کے کل پوائنٹس
  local EXACT_H = "/sdcard/解说/Tools/Unique audio puzzle game/Horror audio sounds/"

  local function hdirs()
    local dirs = { EXACT_H }
    for _, base in ipairs({ "/sdcard/", "/storage/emulated/0/" }) do
      local d = base
      local steps = {
        function(nm) return nm:find("解说", 1, true) ~= nil end,
        function(nm) return norm(nm) == "tools" end,
        function(nm) return norm(nm):find("uniqueaudio", 1, true) ~= nil end,
        function(nm) return norm(nm):find("horroraudio", 1, true) ~= nil end,
      }
      for _, p in ipairs(steps) do
        if d then d = childDir(d, p) end
      end
      if d then dirs[#dirs + 1] = d end
    end
    return dirs
  end

  scanHorror = function()
    horrorInfo.files, horrorInfo.count, horrorInfo.dir = {}, 0, nil
    lastScanH = os.time()
    for _, dir in ipairs(hdirs()) do
      local names = listNames(dir)
      if #names > 0 then
        if not horrorInfo.dir then horrorInfo.dir = dir end
        for _, nm in ipairs(names) do
          local ext = nm:lower():match("%.(%w+)$")
          if ext == "wav" or ext == "mp3" or ext == "ogg" or ext == "m4a" then
            local k = norm(nm)
            if not horrorInfo.files[k] then
              horrorInfo.files[k] = dir .. nm
              horrorInfo.count = horrorInfo.count + 1
            end
          end
        end
      end
    end
  end

  local knockHit, beepOnce, flatlineSound, plink, hsounds
  do
  --------------------------------------------------------
  -- ہارر کی اپنی بنائی ہوئی آوازیں (جو آپ کے فولڈر میں نہ ہوں)
  --------------------------------------------------------
  local function eerie(f)
    local n = math.floor(R * 1.6)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local s = sin(2 * pi * f * t) + 0.8 * sin(2 * pi * f * 1.012 * t) +
                0.5 * sin(2 * pi * f * 1.5 * t)
      raw[i] = s * (0.6 + 0.4 * sin(2 * pi * 4 * t)) * math.min(1, t / 0.2, (1.6 - t) / 0.3)
    end
    return finish(raw, 0.6)
  end

  local function heartbeat()
    local n = math.floor(R * 1.6)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local s = 0
      for _, p in ipairs({ 0, 0.8 }) do
        s = s + thud(t - p, 60, 16) + 0.7 * thud(t - p - 0.22, 70, 18)
      end
      raw[i] = s
    end
    return finish(raw, 0.9)
  end

  local function dripSound()
    local n = math.floor(R * 1.2)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local s = 0
      for _, d in ipairs({ 0, 0.6 }) do
        local tt = t - d
        if tt >= 0 then
          local ph = 2 * pi * (500 * tt + 1500 * (1 - exp(-35 * tt)) / 35)
          s = s + sin(ph) * exp(-tt * 18)
        end
      end
      raw[i] = s
    end
    return finish(raw, 0.7)
  end

  local function windSound()
    local n = math.floor(R * 2.5)
    local a, b = lpnoise(0.08), lpnoise(0.02)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local swell = 0.3 + 0.7 * sin(pi * t / 2.5)
      raw[i] = (a() * 2 + b() * 6) * swell * (0.7 + 0.3 * sin(2 * pi * 0.9 * t))
    end
    return finish(raw, 0.7)
  end

  local function creak(dur, f0)
    local n = math.floor(R * dur)
    local raw, phase = {}, 0
    for i = 1, n do
      local t = (i - 1) / R
      local x = t / dur
      phase = phase + 2 * pi * (f0 + 90 * sin(pi * x * 2)) / R
      local v = 0
      for h = 1, 5 do v = v + sin(h * phase) / h end
      local env = math.max(0, math.min(1, t / 0.1, (dur - t) / 0.2))
      raw[i] = v * env * (0.5 + 0.5 * sin(2 * pi * 9 * t))
    end
    return finish(raw, 0.75)
  end

  local function matchStrike()
    local n = math.floor(R * 1.0)
    local prev, raw = 0, {}
    for i = 1, n do
      local t = (i - 1) / R
      local x = random() * 2 - 1
      local hp = x - 0.5 * prev
      prev = x
      local scrape = hp * exp(-t * 14) * 1.5
      local flare = hp * 0.4 * math.max(0, t - 0.12) * exp(-(t - 0.12) * 3.5)
      raw[i] = scrape + flare
    end
    return finish(raw, 0.7)
  end

  local function chainsSound()
    local n = math.floor(R * 1.4)
    local hits = {}
    for i = 1, 9 do hits[i] = { st = random() * 1.0, f = 2500 + random() * 2000 } end
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local s = 0
      for _, h in ipairs(hits) do
        local tt = t - h.st
        if tt >= 0 and tt < 0.3 then s = s + sin(2 * pi * h.f * tt) * exp(-tt * 28) end
      end
      raw[i] = s
    end
    return finish(raw, 0.7)
  end

  function knockHit()
    local n = math.floor(R * 0.3)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      raw[i] = thud(t, 150, 35) * 1.5 + thud(t, 300, 50) * 0.5 +
               (random() * 2 - 1) * exp(-t * 90) * 0.8
    end
    return finish(raw, 0.9)
  end

  function plink(midi)
    local f = 440 * 2 ^ ((midi - 69) / 12)
    local n = math.floor(R * 0.8)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      raw[i] = (sin(2 * pi * f * t) + 0.4 * sin(4 * pi * f * t) + 0.15 * sin(6 * pi * f * t)) *
               exp(-t * 5) * math.min(1, t / 0.003)
    end
    return finish(raw, 0.8)
  end

  --------------------------------------------------------
  -- ہارر آوازوں کی فہرست
  -- files = آپ کے فولڈر کی فائل کے نام؛ ref = مرکزی فولڈر کی کوئی اور آواز
  --------------------------------------------------------
  --------------------------------------------------------
  -- ہسپتال کی اپنی بنائی ہوئی آوازیں (فائل نہ ہو تو یہ بجتی ہیں)
  --------------------------------------------------------
  local function beeps(times, f, dur, total)
    local n = math.floor(R * total)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local g = 0
      for _, st in ipairs(times) do
        local tt = t - st
        if tt >= 0 and tt <= dur then g = math.min(1, tt / 0.005, (dur - tt) / 0.01) end
      end
      raw[i] = sin(2 * pi * f * t) * g
    end
    return finish(raw, 0.6)
  end
  local function monitorBeepSound() return beeps({ 0, 1.0, 2.0 }, 1000, 0.12, 2.6) end
  function flatlineSound() return beeps({ 0 }, 1000, 2.0, 2.2) end
  function beepOnce() return beeps({ 0 }, 1000, 0.12, 0.3) end

  local function chimeSound()
    local n = math.floor(R * 1.6)
    local notes = { { 0, 660 }, { 0.45, 880 }, { 0.9, 1100 } }
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local s = 0
      for _, nt in ipairs(notes) do
        local tt = t - nt[1]
        if tt >= 0 then s = s + sin(2 * pi * nt[2] * tt) * exp(-tt * 4) end
      end
      raw[i] = s
    end
    return finish(raw, 0.7)
  end

  local function flickerBuzz()
    local n = math.floor(R * 1.6)
    local gates, t0, on = {}, 0, true
    while t0 < 1.6 do
      local len = 0.05 + random() * 0.18
      gates[#gates + 1] = { t0, t0 + len, on }
      t0 = t0 + len
      on = not on
    end
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local g = 0
      for _, seg in ipairs(gates) do
        if t >= seg[1] and t < seg[2] then
          if seg[3] then g = 1 else g = 0.05 end
        end
      end
      raw[i] = (sin(2 * pi * 100 * t) + 0.6 * sin(2 * pi * 200 * t) +
                0.4 * sin(2 * pi * 300 * t) + (random() * 2 - 1) * 0.2) * g
    end
    return finish(raw, 0.6)
  end

  local function powerOnSound()
    local n = math.floor(R * 2.4)
    local raw, ph = {}, 0
    for i = 1, n do
      local t = (i - 1) / R
      local f = 40 + 80 * math.min(1, t / 1.2)
      ph = ph + 2 * pi * f / R
      local s = (sin(ph) + 0.5 * sin(2 * ph) + 0.3 * sin(3 * ph)) *
                math.min(1, t / 0.6) * math.min(1, (2.4 - t) / 0.4)
      raw[i] = s + thud(t, 90, 12) * 1.5 + clk(t - 1.3, 1500, 120) * 0.6
    end
    return finish(raw, 0.85)
  end

  local function gurneyRoll()
    local n = math.floor(R * 2.5)
    local nz = lpnoise(0.05)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local k = math.floor(t / 0.6)
      local tt = t - k * 0.6
      local sq = 0
      if tt < 0.12 then sq = sin(2 * pi * (900 + 200 * tt / 0.12) * t) * (1 - tt / 0.12) * 0.5 end
      raw[i] = nz() * 5 * math.min(1, t / 0.3, (2.5 - t) / 0.4) + sq
    end
    return finish(raw, 0.7)
  end

  local function hissSound()
    local n = math.floor(R * 2.0)
    local prev, raw = 0, {}
    for i = 1, n do
      local t = (i - 1) / R
      local x = random() * 2 - 1
      local hp = x - 0.7 * prev
      prev = x
      raw[i] = hp * math.min(1, t / 0.1, (2.0 - t) / 0.4)
    end
    return finish(raw, 0.6)
  end

  local function humSound()
    local n = math.floor(R * 2.0)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      raw[i] = (sin(2 * pi * 50 * t) + 0.6 * sin(2 * pi * 100 * t) + 0.3 * sin(2 * pi * 150 * t)) *
               (0.8 + 0.2 * sin(2 * pi * 7 * t)) * math.min(1, t / 0.3, (2.0 - t) / 0.3)
    end
    return finish(raw, 0.7)
  end

  hsounds = {
    lookingForMe  = { name = "آواز: کیا تم مجھے ڈھونڈ رہے ہو", files = { "AreLookingfForMe", "AreLookingForMe" }, build = function() return eerie(147) end },
    creepyLaugh   = { name = "ڈراؤنی ہنسی", files = "CreepyLaugh", build = function() return eerie(196) end },
    creepyThunder = { name = "ڈراؤنے بادلوں کی گرج", files = "CreepyThunderClouds", build = thunder },
    ghostSteps    = { name = "بھوت کے قدم", files = "GhostFootSteps", build = function() return stepsSound(5, 0.5, 70, 0.1, 1) end },
    ghostHaha     = { name = "بھوت کا ہاہاہا", files = "ghostHuhahaha", build = function() return eerie(165) end },
    horrorAnimal  = { name = "خوفناک جانور کی آواز", files = "HorrorAnimalSound", build = function() return eerie(80) end },
    inYourMind    = { name = "آواز: میں تمہارے دماغ میں ہوں", files = "IAmInYourMind", build = function() return eerie(123) end },
    seeYou        = { name = "آواز: میں تمہیں دیکھ رہا ہوں", files = "ICanSeeYou", build = function() return eerie(220) end },
    behindYou     = { name = "آواز: یہ تمہارے پیچھے ہے", files = "ItsBehindYou", build = function() return eerie(175) end },
    knock         = { name = "دروازے پر دستک", files = "KnockingDoor", build = knockHit },
    scaryVoice    = { name = "ڈراؤنی آواز (پائل)", files = "Pyle'sScaryVoice", build = function() return eerie(100) end },
    creepyHello   = { name = "ڈراؤنا ہیلو", files = "ScaryCreepyHelloSound", build = function() return eerie(260) end },
    swing         = { name = "جھولے کی چرچراہٹ", files = "SwingingSwing", build = function() return creak(1.2, 260) end },
    noWayOut      = { name = "آواز: نکلنے کا کوئی راستہ نہیں", files = "ThereIsNoWayOut", build = function() return eerie(131) end },
    notSafe       = { name = "آواز: تم محفوظ نہیں ہو", files = "YouAreNotSafe", build = function() return eerie(185) end },
    -- گیم کی اپنی آوازیں
    heartbeat = { name = "دل کی دھڑکن", files = { "heartbeat", "hartbeat" }, build = heartbeat },
    drip      = { name = "پانی ٹپکنا", files = { "drip", "waterdrip" }, build = dripSound },
    wind      = { name = "تیز ہوا", files = { "WindSound", "wind" }, build = windSound },
    creak     = { name = "فرش کی چرچراہٹ", files = { "creak", "floorcreak" }, build = function() return creak(0.9, 150) end },
    match     = { name = "ماچس جلنا", files = { "match", "matchstrike" }, build = matchStrike },
    chains    = { name = "زنجیروں کی جھنکار", files = { "chains", "chain" }, build = chainsSound },
    -- نئی آوازیں: پس منظر، مسکراہٹ، گاڑی اور بریک
    bgCreepy     = { name = "ڈراؤنی پس منظر کی آواز (ایک)", files = "BackgroundCreepySound", build = function() return eerie(90) end },
    bgHorror     = { name = "ڈراؤنی پس منظر کی آواز (دو)", files = "BackgroundHorrorSound", build = function() return eerie(105) end },
    horrorSound  = { name = "ہارر آواز", files = "horrorSound", build = function() return eerie(115) end },
    creepySmile  = { name = "روح کی ڈراؤنی مسکراہٹ", files = "CreepySmileOfSpirit", build = function() return eerie(240) end },
    vehicleBrake = { name = "گاڑی چلتی ہے اور اچانک بریک لگتی ہے", files = "VehicleIsMovingAndSuddenlyBrakes", build = carStart },
    -- ہسپتال کی کہانی کی آوازیں (Horror audio sounds فولڈر میں ان ناموں سے رکھیں)
    monitorBeep    = { name = "دل کی مشین کی بیپ", files = "HeartMonitorBeep", build = monitorBeepSound },
    flatline       = { name = "دل کی مشین کی سیدھی لکیر والی لمبی بیپ", files = "HeartMonitorFlatline", build = flatlineSound },
    wheelchair     = { name = "ویل چیئر کی چرچراہٹ", files = "WheelchairSqueak", build = function() return creak(1.0, 420) end },
    gurney         = { name = "اسٹریچر کے پہیوں کی گڑگڑاہٹ", files = "GurneyRolling", build = gurneyRoll },
    elevatorDing   = { name = "لفٹ کی ڈنگ", files = "ElevatorDing", build = function() return bellSound(1500, 700, 3) end },
    elevatorDoor   = { name = "لفٹ کا دروازہ", files = "ElevatorDoor", build = function() return slideSound(0.9, 0.4, 200) end },
    announcement   = { name = "ہسپتال کی اناؤنسمنٹ", files = "HospitalAnnouncement", build = chimeSound },
    flicker        = { name = "ٹوٹتی بجلی کی بھنبھناہٹ", files = "FlickeringLight", build = flickerBuzz },
    powerOn        = { name = "بجلی بحال ہونا", files = "PowerOn", build = powerOnSound },
    generatorHum   = { name = "جنریٹر کی گونج", files = "GeneratorHum", build = humSound },
    gasHiss        = { name = "آکسیجن گیس کی سیٹی", files = "OxygenHiss", build = hissSound },
    patientWhisper = { name = "مریض کی سرگوشی", files = "PatientWhisper", build = function() return eerie(150) end },
    instruments    = { name = "اوزاروں کے گرنے کی آواز", files = "SurgeryTools", build = clatter },
    phone          = { name = "فون کی گھنٹی", ref = "phone" },
    -- مرکزی فولڈر کی آوازیں
    keyTurn   = { name = "چابی گھمانا", ref = "keyTurn" },
    doorOpen  = { name = "دروازہ کھلنا", ref = "doorOpen" },
    doorClose = { name = "دروازہ بند ہونا", ref = "doorClose" },
    drawer    = { name = "دراز کھلنا", ref = "drawer" },
    paper     = { name = "کاغذوں کی سرسراہٹ", ref = "paper" },
    clock     = { name = "گھڑی کی ٹک ٹک", ref = "clock" },
    bell      = { name = "پیتل کی گھنٹی", ref = "bell" },
    rain      = { name = "بارش", ref = "rain" },
    glass     = { name = "شیشہ ٹوٹنا", ref = "glass" },
    run       = { name = "بھاگتے قدم", ref = "run" },
  }

  end

  local hlist = { "lookingForMe", "creepyLaugh", "creepyThunder", "ghostSteps", "ghostHaha",
    "horrorAnimal", "inYourMind", "seeYou", "behindYou", "knock", "scaryVoice", "creepyHello",
    "swing", "noWayOut", "notSafe", "heartbeat", "drip", "wind", "creak", "match", "chains",
    "bgCreepy", "bgHorror", "horrorSound", "creepySmile", "vehicleBrake" }

  -- یہ پس منظر کی آوازیں کسی بھی سین میں کبھی کبھار خود بخود بجتی ہیں
  -- یہ عام ڈراؤنی آوازیں ہر کہانی میں کبھی کبھار پس منظر میں خود بخود بجتی ہیں
  local AMBIENT = { "bgCreepy", "bgHorror", "horrorSound", "creepySmile", "horrorAnimal" }
  local hlistH2 = { "monitorBeep", "flatline", "wheelchair", "gurney", "elevatorDing", "elevatorDoor",
    "announcement", "flicker", "powerOn", "generatorHum", "gasHiss", "patientWhisper", "instruments" }

  -- آواز پوری بجتی ہے (صرف 30 سیکنڈ سے لمبی ہو تو حفاظت کے لیے کاٹی جاتی ہے)
  local function hplay(key, maxMs)
    maxMs = maxMs or 30000
    local e = hsounds[key]
    if e.ref then
      return playDS(e.ref, maxMs) or dsounds[e.ref].ms
    end
    if e.files then
      local files = type(e.files) == "table" and e.files or { e.files }
      for pass = 1, 2 do
        for _, f in ipairs(files) do
          local p = horrorInfo.files[norm(f)] or userFiles[norm(f)]
          if p then
            local d = playPath(p, maxMs)
            if d then return d end
          end
        end
        if pass == 1 then
          -- فائل نہ ملی: فولڈر دوبارہ دیکھیں (نئی رکھی ہوئی فائلیں خود پہچانی جائیں)
          if os.time() - lastScanH < 3 then break end
          scanHorror()
        end
      end
    end
    return playPath(getSound("h_" .. key, e.build), maxMs) or 1500
  end

  local function playPlink(midi)
    playNamed(nil, "h_pl" .. midi, function() return plink(midi) end)
  end

  local function hseq(g, keys, done)
    local i = 0
    local function step()
      if g ~= gen then return end
      i = i + 1
      if i > #keys then
        if done then done() end
        return
      end
      local d = hplay(keys[i]) or 1500
      later(d + 500, step)
    end
    step()
  end

  --------------------------------------------------------
  -- کھیل کی حالت اور مدد گار فنکشن
  --------------------------------------------------------
  local ITEMS = {
    torch = "ٹارچ", salt = "نمک", matches = "ماچس", candle = "موم بتی",
    nail = "لوہے کی کیل", bell = "پیتل کی گھنٹی", amulet = "پرانا تعویذ",
    rustKey = "زنگ آلود چابی", gateKey = "مرکزی دروازے کی چابی",
    battery = "بیٹری", fuse = "فیوز", staffKey = "عملے کی چابی",
    accessCard = "ایکسیس کارڈ", flare = "ایمرجنسی فلیئر", scalpel = "لوہے کا نشتر",
  }
  local ITEM_ORDER = { "torch", "salt", "matches", "candle", "nail", "bell",
                       "amulet", "rustKey", "gateKey", "battery", "fuse", "staffKey",
                       "accessCard", "flare", "scalpel" }

  local hs = {}
  local H = {}
  local goScene, hmsg, hurt, hover, hwin, startHorror, startHospital, tryStart

  local function hasI(k) return hs.items[k] == true end
  local function giveI(k) hs.items[k] = true end
  local function takeI(k) hs.items[k] = nil end
  local function flag(k) return hs.flags[k] == true end
  local function setF(k) hs.flags[k] = true end
  local function addScore(n) hs.score = hs.score + n end

  local function invText()
    local t = {}
    for _, k in ipairs(ITEM_ORDER) do
      if hs.items[k] then t[#t + 1] = ITEMS[k] end
    end
    return "ہمت: " .. hs.courage .. " از " .. MAXC .. "۔ سامان: " .. table.concat(t, "، ") .. "۔"
  end

  -- پیغام سنائیں، آواز بجائیں، پھر آگے بڑھنے کا بٹن
  hmsg = function(text, sfx, nextFn)
    gen = gen + 1
    local g = gen
    clearScreen("")
    say(text)
    if sfx and #sfx > 0 then
      laterG(g, 1500, function() hseq(g, sfx) end)
    end
    btn("آگے بڑھیں", function() gen = gen + 1; nextFn() end)
    btn("اپنا سامان اور ہمت دیکھیں", function() say(invText()) end)
  end

  hover = function(reason, sfx)
    gen = gen + 1
    local g = gen
    local id = hs.story or 1
    stopMusic()
    clearScreen("")
    say("کھیل ختم! " .. reason .. " آپ دوبارہ کوشش کر سکتے ہیں۔")
    laterG(g, 1500, function()
      if sfx then hseq(g, sfx, function() fx("fail") end) else fx("fail") end
    end)
    btn("دوبارہ کھیلیں", function() tryStart(id) end)
    btn("ہارر مینو میں واپس", function() showHorror() end)
  end

  hurt = function(n, text, sfx, nextFn)
    hs.courage = hs.courage - n
    if hs.courage <= 0 then
      hover(text .. " آپ کی ہمت بالکل ٹوٹ گئی۔", sfx)
      return
    end
    hmsg(text .. " ہمت " .. n .. " کم ہوئی۔ باقی ہمت " .. hs.courage .. "۔", sfx, nextFn)
  end

  -- o (اختیاری): text جیت کا متن، base بنیادی پوائنٹس، bonus بچے ہوئے سامان کا بونس، bestKey
  hwin = function(o)
    o = o or {}
    gen = gen + 1
    local g = gen
    stopMusic()
    local bonus
    if o.bonus then
      bonus = o.bonus()
    else
      bonus = 0
      for _, k in ipairs({ "salt", "nail", "bell" }) do
        if hasI(k) then bonus = bonus + 10 end
      end
      if hasI("candle") and hasI("matches") then bonus = bonus + 10 end
    end
    local base = o.base or 200
    local bestKey = o.bestKey or "best4"
    local total = base + hs.courage * 30 + bonus + hs.score
    local newBest = total > prog[bestKey]
    if newBest then prog[bestKey] = total; saveProg() end
    clearScreen("")
    say((o.text or "مبارک ہو! آپ نے تالا کھولا اور حویلی کے مرکزی دروازے سے باہر نکل آئے۔ صبح کی روشنی ہو رہی ہے۔ ") ..
        "آپ کے پوائنٹس " .. total .. " ہیں۔ فتح کے " .. base .. "، بچی ہوئی ہمت کے " ..
        hs.courage * 30 .. "، بچے ہوئے سامان کے " .. bonus .. " اور پہیلیوں کے " .. hs.score .. "۔" ..
        (newBest and " یہ آپ کا نیا بہترین سکور ہے!" or ""))
    laterG(g, 1200, function()
      hseq(g, { "keyTurn", "doorOpen" }, function() fx("ding") end)
    end)
    local id = hs.story or 1
    btn("دوبارہ کھیلیں", function() tryStart(id) end)
    btn("ہارر مینو میں واپس", function() showHorror() end)
  end

  -- سین دکھانا
  goScene = function(id)
    gen = gen + 1
    local g = gen
    hs.scene = id
    startMusic()
    local sc = H[id]
    local text = type(sc.text) == "function" and sc.text() or sc.text
    local sfx = type(sc.sfx) == "function" and sc.sfx() or sc.sfx
    if type(sfx) == "table" and #sfx > 0 and not sc.soundFirst and random() < 0.5 then
      local copy = {}
      for i, k in ipairs(sfx) do copy[i] = k end
      copy[#copy + 1] = AMBIENT[random(#AMBIENT)]
      sfx = copy
    end
    hs.lastSfx = sfx
    clearScreen("")

    local function build()
      for _, o in ipairs(sc.opts) do
        if not o.show or o.show() then
          btn(o.t, function() gen = gen + 1; o.run() end)
        end
      end
      btn("آوازیں دوبارہ سنیں", function()
        gen = gen + 1
        if hs.lastSfx and #hs.lastSfx > 0 then hseq(gen, hs.lastSfx) end
      end)
      btn("اپنا سامان اور ہمت دیکھیں", function() say(invText()) end)
      btn("کھیل چھوڑ کر واپس", function()
        stopMusic()
        showHorror()
      end)
    end

    -- جن سینز میں پہلے آواز بجنی چاہیے (مثلاً گاڑی کا بریک)، وہاں پہلے آواز پوری بجتی ہے، پھر متن
    if sc.soundFirst and sfx and #sfx > 0 then
      say(sc.pre or "کہانی شروع ہوتی ہے۔ غور سے سنیں۔")
      btn("آواز چھوڑ کر کہانی پڑھیں", function()
        gen = gen + 1
        clearScreen("")
        say(text)
        build()
      end)
      laterG(g, 1800, function()
        hseq(g, sfx, function()
          laterG(g, 600, function()
            clearScreen("")
            say(text)
            build()
          end)
        end)
      end)
      return
    end

    say(text)
    if sfx and #sfx > 0 then
      laterG(g, 1500 + math.min(7000, #text * 18), function() hseq(g, sfx) end)
    end
    build()
  end

  --------------------------------------------------------
  -- پہیلیاں
  --------------------------------------------------------
  --------------------------------------------------------
  -- پہیلیوں کے بٹنوں کی آوازیں: ہر بٹن کا الگ ساز (پیانو کی جگہ)، نام کے ساتھ
  --------------------------------------------------------
  local function instDrum()
    local n = math.floor(R * 0.55)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local ph = 2 * pi * (70 * t + 110 * (1 - exp(-18 * t)) / 18)
      raw[i] = sin(ph) * exp(-t * 7) + (random() * 2 - 1) * 0.3 * exp(-t * 60)
    end
    return finish(raw, 0.9)
  end

  local function instFlute(f)
    local n = math.floor(R * 0.8)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      local vib = 1 + 0.01 * sin(2 * pi * 5.5 * t)
      raw[i] = (sin(2 * pi * f * vib * t) + 0.25 * sin(4 * pi * f * vib * t)) *
               math.min(1, t / 0.08, (0.8 - t) / 0.15)
    end
    return finish(raw, 0.7)
  end

  local function instWood()
    local n = math.floor(R * 0.35)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      raw[i] = sin(2 * pi * 1400 * t) * exp(-t * 35) + (random() * 2 - 1) * 0.5 * exp(-t * 120)
    end
    return finish(raw, 0.8)
  end

  local function instBuzz()
    local n = math.floor(R * 0.6)
    local raw = {}
    for i = 1, n do
      local t = (i - 1) / R
      raw[i] = (sin(2 * pi * 200 * t) + 0.5 * sin(6 * pi * 200 * t) + 0.3 * sin(10 * pi * 200 * t)) *
               math.min(1, t / 0.02, (0.6 - t) / 0.05)
    end
    return finish(raw, 0.7)
  end

  -- حویلی کا موسیقی کا ڈبہ (چار ساز)
  local TONESET_MUSIC = {
    { name = "ڈھول", key = "drum", build = instDrum },
    { name = "گھنٹی", key = "bell", build = function() return bellSound(880, 900, 3) end },
    { name = "بانسری", key = "flute", build = function() return instFlute(660) end },
    { name = "لکڑی کی ٹک", key = "wood", build = instWood },
  }
  -- ہسپتال کے جنریٹر پینل کی تین بتیاں
  local TONESET_PANEL = {
    { name = "سرخ بتی", key = "buzz", build = instBuzz },
    { name = "ہری بتی", key = "bell2", build = function() return bellSound(1320, 700, 3) end },
    { name = "نیلی بتی", key = "flute2", build = function() return instFlute(880) end },
  }

  local function playTone(set, i)
    return playNamed(nil, "pz_" .. set[i].key, set[i].build)
  end

  -- آوازوں کی ترتیب بجانا؛ announce ہو تو ہر آواز سے پہلے اس کا نام بولا جاتا ہے
  local function toneSeq(g, set, ids, announce, done)
    local i = 0
    local function step()
      if g ~= gen then return end
      i = i + 1
      if i > #ids then
        if done then done() end
        return
      end
      local function go()
        if g ~= gen then return end
        local d = playTone(set, ids[i]) or 600
        later(d + 500, step)
      end
      if announce then
        say(set[ids[i]].name)
        later(900, go)
      else
        go()
      end
    end
    step()
  end

  -- تعارف: ہر بٹن کا نام بول کر اس کی آواز سنانا
  local function toneIntro(g, set, done)
    local ids = {}
    for i = 1, #set do ids[i] = i end
    learnChain(g, ids, function(i) return set[i].name end,
      function(i) return playTone(set, i) end, done)
  end

  -- گرامو فون کی دھن: ہر ساز کا نام بول کر آواز بجتی ہے
  local function playMelody(g, notes, done)
    toneSeq(g, TONESET_MUSIC, notes, true, done)
  end

  -- موسیقی کے ڈبے کی دھن دہرانا (دھن کتب خانے کے گرامو فون پر سنی تھی)
  local function melodyPuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local pos, busy = 0, true
    clearScreen("")
    say("موسیقی کے ڈبے پر چار ساز کے بٹن ہیں: ڈھول، گھنٹی، بانسری اور لکڑی کی ٹک۔ پہلے ہر بٹن کی آواز سنائی جاتی ہے۔ پھر کتب خانے کے گرامو فون پر سنی ہوئی پانچ سازوں کی دھن اسی ترتیب سے دہرائیں۔")
    for k = 1, #TONESET_MUSIC do
      btn(TONESET_MUSIC[k].name, function()
        if busy then return end
        playTone(TONESET_MUSIC, k)
        pos = pos + 1
        if k ~= hs.melody[pos] then
          busy = true
          hurt(1, "غلط ساز! ڈبے سے ایک ڈراؤنی ہنسی گونجی اور دھن دوبارہ شروع ہو گئی۔",
               { "creepyLaugh" }, function() melodyPuzzle(onOk, onBack) end)
          return
        end
        if pos == #hs.melody then
          busy = true
          laterG(g, 1000, function() onOk() end)
        end
      end)
    end
    btn("سازوں کی آوازیں دوبارہ سنیں (نام کے ساتھ)", function()
      if busy then return end
      busy = true
      pos = 0
      toneIntro(g, TONESET_MUSIC, function() busy = false end)
    end)
    btn("واپس (کتب خانے میں دھن دوبارہ سن آئیں)", onBack)
    if hs.introSeen.music then
      busy = false
    else
      hs.introSeen.music = true
      laterG(g, 3500, function()
        toneIntro(g, TONESET_MUSIC, function() busy = false end)
      end)
    end
  end

  -- روحوں کی سرگوشیوں کی ترتیب یاد رکھنا
  local VOICES = { "seeYou", "inYourMind", "notSafe", "noWayOut", "lookingForMe" }

  local function voicePuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local seq = {}
    for i = 1, 5 do seq[i] = random(#VOICES) end
    local pos, busy, replays = 0, true, 2

    local function playSeqV(done)
      busy = true
      local i = 0
      local function step()
        if g ~= gen then return end
        i = i + 1
        if i > #seq then
          busy = false
          if done then done() end
          return
        end
        local d = hplay(VOICES[seq[i]]) or 1500
        later(d + 700, step)
      end
      step()
    end

    clearScreen("")
    say("پانچ مختلف سرگوشیاں ہیں۔ پہلے ہر سرگوشی کا نام بول کر اس کی آواز سنائی جائے گی، پھر وہ ایک ترتیب سے بجیں گی۔ آپ اسی ترتیب سے ان کے نام والے بٹن دبائیں۔")
    for k, key in ipairs(VOICES) do
      btn(hsounds[key].name, function()
        if busy then return end
        fx("click")
        pos = pos + 1
        if k ~= seq[pos] then
          busy = true
          hurt(1, "غلط ترتیب! روحیں غصے میں چیخ اٹھیں۔",
               { "ghostHaha" }, function() voicePuzzle(onOk, onBack) end)
          return
        end
        if pos == #seq then
          busy = true
          laterG(g, 1500, function() onOk() end)
        end
      end)
    end
    btn("ترتیب دوبارہ سنیں", function()
      if busy then return end
      if replays <= 0 then say("اب دوبارہ سننے کا موقع باقی نہیں۔") return end
      replays = replays - 1
      pos = 0
      say("دوبارہ سنیں۔ باقی موقع " .. replays)
      laterG(g, 1200, function() playSeqV() end)
    end)
    btn("واپس", onBack)
    local ids = {}
    for i = 1, #VOICES do ids[i] = i end
    local function startSeq()
      laterG(g, 800, function() playSeqV() end)
    end
    if hs.introSeen.voices then
      laterG(g, 3500, startSeq)
    else
      hs.introSeen.voices = true
      laterG(g, 3000, function()
        learnChain(g, ids, function(i) return hsounds[VOICES[i]].name end,
          function(i) return hplay(VOICES[i]) end, startSeq)
      end)
    end
  end

  -- دروازے کی دستک کا انداز پہچاننا (دو گروہ: مثلاً دو دستک، وقفہ، تین دستک)
  local function knockPuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local a, b = random(1, 4), random(1, 4)
    local function label(x, y) return x .. " اور " .. y .. " دستک" end
    local correct = label(a, b)
    local opts, seen = { correct }, { [correct] = true }
    while #opts < 4 do
      local s = label(random(1, 4), random(1, 4))
      if not seen[s] then seen[s] = true; opts[#opts + 1] = s end
    end
    shuffle(opts)
    local busy = true

    local function knockOnce()
      playNamed(nil, "h_knockHit", knockHit)
    end

    local function playPattern()
      busy = true
      local t = 0
      for i = 1, a do
        laterG(g, t, knockOnce)
        t = t + 500
      end
      t = t + 1200
      for j = 1, b do
        laterG(g, t, knockOnce)
        t = t + 500
      end
      laterG(g, t + 300, function() busy = false end)
    end

    clearScreen("")
    say("دروازے کے پیچھے سے دو گروہوں میں دستک ہوتی ہے۔ گروہوں کے درمیان وقفہ ہے۔ غور سے سنیں اور جواب میں وہی انداز دہرائیں۔")
    for _, o in ipairs(opts) do
      btn(o, function()
        if busy then return end
        busy = true
        if o == correct then
          laterG(g, 300, function() onOk() end)
        else
          hurt(1, "غلط انداز! دروازے کے پیچھے سے ہنسی گونجی۔",
               { "creepyLaugh" }, function() knockPuzzle(onOk, onBack) end)
        end
      end)
    end
    btn("دستک دوبارہ سنیں", function()
      if busy then return end
      playPattern()
    end)
    btn("واپس", onBack)
    laterG(g, 3500, playPattern)
  end

  --------------------------------------------------------
  -- کہانی کے سین
  --------------------------------------------------------
  H.drive = {
    soundFirst = true,
    pre = "رات کے بارہ بجے ہیں۔ آپ تیز بارش اور بجلی کی گرج میں اکیلے گاڑی چلا رہے ہیں۔ غور سے سنیں۔",
    text = "گاڑی ایک جھٹکے سے رکی اور بند ہو گئی۔ سامنے سڑک کے کنارے ایک ویران حویلی ہے اور اس کی کھڑکی میں ایک ہلکی روشنی ٹمٹما رہی ہے۔ بارش بہت تیز ہے اور گاڑی آگے نہیں چلے گی۔",
    sfx = { "vehicleBrake", "creepyThunder" },
    opts = {
      { t = "گاڑی سے اتر کر حویلی کی طرف دوڑیں", run = function() goScene("intro") end },
    },
  }

  H.intro = {
    soundFirst = true,
    pre = "آپ بھاگ کر حویلی کے دروازے تک پہنچتے ہیں۔ غور سے سنیں۔",
    text = "آپ بارش میں بھاگ کر حویلی کے دروازے تک پہنچتے ہیں۔ دروازہ خود بخود کھلتا ہے۔ آپ اندر جاتے ہیں تو وہ زور سے بند ہو جاتا ہے اور تالا لگ جاتا ہے۔ ایک سرد آواز گونجتی ہے۔ آپ کے پاس صرف ایک ٹارچ ہے۔ صبح ہونے سے پہلے آپ کو اس حویلی سے نکلنا ہے۔",
    sfx = { "doorOpen", "doorClose", "keyTurn", "noWayOut" },
    opts = {
      { t = "حویلی کے اندر دیکھیں", run = function() goScene("hall") end },
      { t = "دروازہ زور سے کھینچیں",
        run = function()
          hmsg("دروازہ نہیں کھلتا۔ ایک ٹھنڈی سرگوشی کانوں میں آتی ہے۔", { "notSafe" },
               function() goScene("intro") end)
        end },
    },
  }

  H.hall = {
    text = function()
      local t = "آپ حویلی کے بڑے دالان میں ہیں۔ چھت سے فانوس جھول رہا ہے۔ دائیں طرف باورچی خانہ ہے، بائیں طرف کتب خانہ، سامنے اوپر جانے والی سیڑھیاں، نیچے تہہ خانے کا بھاری دروازہ، اور آخر میں صحن کا بڑا دروازہ۔"
      if not flag("gotBell") then t = t .. " ایک میز پر پیتل کی گھنٹی رکھی ہے۔" end
      if hasI("gateKey") then t = t .. " آپ کے پاس مرکزی دروازے کی چابی ہے۔ جلدی کریں!" end
      return t
    end,
    sfx = { "clock" },
    opts = {
      { t = "میز سے پیتل کی گھنٹی اٹھائیں",
        show = function() return not flag("gotBell") end,
        run = function()
          giveI("bell"); setF("gotBell"); addScore(5)
          hmsg("گھنٹی اٹھاتے ہی کہیں دور سے ہنسی کی آواز آئی۔ پرانی کہانیوں میں پیتل کی گھنٹی بری طاقتوں کو دور رکھتی ہے۔ آپ نے اسے سنبھال لیا۔",
               { "creepyLaugh" }, function() goScene("hall") end)
        end },
      { t = "باورچی خانے میں جائیں", run = function() goScene("kitchen") end },
      { t = "کتب خانے میں جائیں", run = function() goScene("library") end },
      { t = "سیڑھیاں چڑھیں", run = function() goScene("stairs") end },
      { t = "تہہ خانے کا دروازہ آزمائیں",
        run = function()
          if hasI("rustKey") then
            goScene("basement")
          else
            hmsg("دروازے پر بھاری تالا لگا ہے۔ اسے کھولنے کے لیے کوئی چابی چاہیے۔", { "keyTurn" },
                 function() goScene("hall") end)
          end
        end },
      { t = "صحن کے دروازے کی طرف جائیں",
        run = function()
          if hasI("gateKey") then
            goScene("courtyard")
          else
            hmsg("صحن کے دروازے پر زنجیر اور بڑا تالا ہے۔ آپ کے پاس اس کی چابی نہیں۔", { "keyTurn" },
                 function() goScene("hall") end)
          end
        end },
    },
  }

  H.kitchen = {
    text = function()
      local t = "باورچی خانے میں نل سے پانی ٹپک رہا ہے۔ ایک پرانی الماری کی دراز آدھی کھلی ہے۔ ایک بند پینٹری کا دروازہ ہے"
      if not flag("pantry") then t = t .. " جس کے اندر سے ہلکی غراہٹ آ رہی ہے۔" else t = t .. "۔" end
      return t
    end,
    sfx = function()
      if flag("pantry") then return { "drip" } end
      return { "drip", "horrorAnimal" }
    end,
    opts = {
      { t = "دراز کھولیں",
        show = function() return not flag("drawer") end,
        run = function()
          giveI("salt"); giveI("matches"); setF("drawer"); addScore(10)
          hmsg("دراز میں نمک کی ایک تھیلی اور ماچس کی ڈبیا ملی۔", { "drawer" },
               function() goScene("kitchen") end)
        end },
      { t = "نمک بکھیر کر پینٹری کھولیں",
        show = function() return not flag("pantry") and hasI("salt") end,
        run = function()
          takeI("salt"); giveI("nail"); setF("pantry"); addScore(20)
          hmsg("آپ نے دروازے کے سامنے نمک بکھیرا۔ غراہٹ دب گئی۔ اندر سے لوہے کی ایک لمبی کیل ملی۔ نمک ختم ہو گیا۔",
               { "horrorAnimal" }, function() goScene("kitchen") end)
        end },
      { t = "ایسے ہی پینٹری کھول دیں",
        show = function() return not flag("pantry") end,
        run = function()
          giveI("nail"); setF("pantry"); addScore(5)
          hurt(2, "پینٹری کھلتے ہی ایک خوفناک جانور نے جھپٹا مارا۔ بھاگتے ہوئے آپ کو لوہے کی ایک کیل ملی۔",
               { "horrorAnimal" }, function() goScene("kitchen") end)
        end },
      { t = "دالان میں واپس جائیں", run = function() goScene("hall") end },
    },
  }

  H.library = {
    text = function()
      local t = "کتب خانے میں گرد سے اٹی کتابیں ہیں۔ ایک کونے میں پرانا گرامو فون رکھا ہے اور میز پر ایک ڈائری کھلی پڑی ہے۔"
      if not flag("candleTaken") then t = t .. " الماری کے اوپر ایک موم بتی نظر آ رہی ہے۔" end
      return t
    end,
    sfx = { "paper", "clock" },
    opts = {
      { t = "ڈائری پڑھیں",
        show = function() return not flag("diary") end,
        run = function()
          setF("diary"); setF("melodyHeard"); addScore(10)
          hmsg("ڈائری میں لکھا ہے: اس حویلی کی چھوٹی بچی کی روح موسیقی کے ایک ڈبے میں قید ہے۔ اوپر کے کمرے کا دروازہ اسی دھن پر کھلتا ہے جو گرامو فون پر بجتی ہے۔ ڈبے میں ایک پرانا تعویذ بھی ہے، جو تہہ خانے کی شیطانی روح کو روک سکتا ہے۔ آخری ورق پر لکھا ہے: جب سایہ پیچھے سے قریب آئے تو کبھی مڑ کر مت دیکھنا۔ گرامو فون اب خود بجنے لگا ہے۔",
               { "seeYou" }, function() goScene("library") end)
        end },
      { t = "گرامو فون کی دھن سنیں",
        show = function() return flag("melodyHeard") end,
        run = function()
          gen = gen + 1
          local g = gen
          clearScreen("")
          say("گرامو فون کی دھن بج رہی ہے۔ یہ پانچ سازوں کی دھن ہے۔ ساز یہ ہیں: ڈھول، گھنٹی، بانسری اور لکڑی کی ٹک۔ ہر آواز سے پہلے اس کا نام بولا جائے گا۔ غور سے سنیں اور ترتیب یاد رکھیں۔")
          laterG(g, 2500, function()
            playMelody(g, hs.melody, function() say("دھن ختم ہوئی۔ چاہیں تو دوبارہ سنیں اور ترتیب یاد کر لیں۔") end)
          end)
          btn("دھن دوبارہ سنیں", function()
            gen = gen + 1
            local g2 = gen
            playMelody(g2, hs.melody, function() say("دھن ختم ہوئی۔") end)
          end)
          btn("واپس", function() goScene("library") end)
        end },
      { t = "الماری سے موم بتی لیں",
        show = function() return not flag("candleTaken") end,
        run = function()
          giveI("candle"); setF("candleTaken"); addScore(5)
          hmsg("آپ نے موم بتی لے لی۔ اسے جلانے کے لیے ماچس چاہیے ہوگی۔", { "drawer" },
               function() goScene("library") end)
        end },
      { t = "دالان میں واپس جائیں", run = function() goScene("hall") end },
    },
  }

  H.stairs = {
    text = function()
      if flag("shadowGone") then
        return "سیڑھیاں اب خاموش ہیں۔ سایہ جا چکا ہے۔ آپ اوپر جا سکتے ہیں۔"
      end
      return "آپ سیڑھیاں چڑھنا شروع کرتے ہیں۔ اچانک پیچھے سے آہستہ آہستہ قدموں کی آواز آتی ہے۔ وہ قریب آتی جا رہی ہے۔ پھر ایک سرگوشی آتی ہے۔ جلدی فیصلہ کریں!"
    end,
    sfx = function()
      if flag("shadowGone") then return {} end
      return { "ghostSteps", "behindYou" }
    end,
    opts = {
      { t = "اوپر جائیں",
        show = function() return flag("shadowGone") end,
        run = function() goScene("upHall") end },
      { t = "پیچھے مڑ کر دیکھیں",
        show = function() return not flag("shadowGone") end,
        run = function()
          hover("آپ نے مڑ کر دیکھا تو سامنے ایک بھیانک سایہ کھڑا تھا۔ خوف سے آپ کی آنکھوں کے آگے اندھیرا چھا گیا۔",
                { "ghostHaha" })
        end },
      { t = "نمک کا دائرہ بنا کر اس میں کھڑے ہوں",
        show = function() return not flag("shadowGone") and hasI("salt") end,
        run = function()
          takeI("salt"); setF("shadowGone"); addScore(30)
          hmsg("آپ نے فرش پر نمک کا دائرہ بنایا۔ سایہ دائرے کے باہر رک کر چیخا اور غائب ہو گیا۔ نمک ختم ہو گیا۔",
               { "ghostHaha" }, function() goScene("stairs") end)
        end },
      { t = "لوہے کی کیل ہاتھ میں پکڑ کر سامنے کریں",
        show = function() return not flag("shadowGone") and hasI("nail") end,
        run = function()
          setF("shadowGone"); addScore(30)
          hmsg("لوہے کو دیکھتے ہی سایہ دھوئیں کی طرح بکھر گیا۔ کیل آپ کے پاس ہی ہے۔",
               { "creepyLaugh" }, function() goScene("stairs") end)
        end },
      { t = "پیتل کی گھنٹی زور سے بجائیں",
        show = function() return not flag("shadowGone") and hasI("bell") end,
        run = function()
          takeI("bell"); setF("shadowGone"); addScore(30)
          hmsg("گھنٹی کی آواز گونجی اور سایہ درد سے چیخ کر غائب ہو گیا۔ گھنٹی کی دھات ٹوٹ گئی اور اب بیکار ہے۔",
               { "bell" }, function() goScene("stairs") end)
        end },
      { t = "بھاگ کر نیچے دالان میں جائیں",
        show = function() return not flag("shadowGone") end,
        run = function()
          hurt(1, "آپ بھاگ کر نیچے آ گئے۔ سایہ کچھ دیر دیکھتا رہا اور پھر غائب ہو گیا، لیکن اس نے سیڑھیوں پر ڈیرہ ڈال لیا ہے۔",
               { "run", "creepyLaugh" }, function() goScene("hall") end)
        end },
    },
  }

  H.upHall = {
    text = function()
      local t = "اوپر کی منزل پر ایک لمبی راہداری ہے۔ فرش چرچرا رہا ہے۔ آخر میں ایک بند دروازہ ہے جس کے پیچھے سے موسیقی کے ڈبے کی مدھم دھن آتی ہے۔ دائیں طرف ایک کھڑکی ہے۔"
      return t
    end,
    sfx = { "creak" },
    opts = {
      { t = "موسیقی والے کمرے کے دروازے کی طرف جائیں",
        run = function()
          if flag("boxOpen") or flag("knockDone") then
            goScene("musicRoom")
          elseif not flag("melodyHeard") then
            hmsg("دروازے پر ایک عجیب تالا لگا ہے جو شاید کسی دھن پر کھلتا ہے۔ آپ کو وہ دھن کہیں سے سننی ہوگی۔",
                 { "creak" }, function() goScene("upHall") end)
          else
            knockPuzzle(function()
              setF("knockDone"); addScore(20)
              hmsg("آپ نے وہی دستک دہرائی۔ دروازہ آہستہ سے کھل گیا۔", { "doorOpen" },
                   function() goScene("musicRoom") end)
            end, function() goScene("upHall") end)
          end
        end },
      { t = "کھڑکی سے صحن دیکھیں",
        show = function() return not flag("windowSeen") end,
        run = function()
          setF("windowSeen"); addScore(5)
          hmsg("نیچے صحن میں ایک جھولا خود بخود ہل رہا ہے۔ اس کے پیچھے حویلی کا مرکزی دروازہ ہے، اور وہاں تک پہنچنے کے لیے آپ کو صحن کے دروازے کی چابی چاہیے ہوگی۔",
               { "swing", "wind" }, function() goScene("upHall") end)
        end },
      { t = "نیچے دالان میں جائیں", run = function() goScene("hall") end },
    },
  }

  H.musicRoom = {
    text = function()
      if flag("boxOpen") then
        return "کمرے میں موسیقی کا ڈبہ کھلا پڑا ہے۔ اب وہ خاموش ہے۔"
      end
      return "کمرے میں ایک بڑا پرانا موسیقی کا ڈبہ رکھا ہے۔ اس پر چار بٹن لگے ہیں۔ دھن اب رک چکی ہے اور کمرے میں ایک بچی کے ہنسنے کی ہلکی آواز آتی ہے۔"
    end,
    sfx = function()
      if flag("boxOpen") then return {} end
      return { "creepyHello" }
    end,
    opts = {
      { t = "ڈبے کی دھن دہرائیں",
        show = function() return not flag("boxOpen") end,
        run = function()
          melodyPuzzle(function()
            setF("boxOpen"); giveI("amulet"); giveI("rustKey"); addScore(40)
            hmsg("ڈبہ کھل گیا! اندر ایک پرانا تعویذ اور ایک زنگ آلود چابی ہے۔ ڈبے سے ایک ٹھنڈی ہنسی گونجی۔ شاید یہ چابی تہہ خانے کی ہے۔",
                 { "creepyHello", "creepySmile" }, function() goScene("musicRoom") end)
          end, function() goScene("musicRoom") end)
        end },
      { t = "راہداری میں واپس جائیں", run = function() goScene("upHall") end },
    },
  }

  H.basement = {
    text = function()
      if flag("voicesDone") then
        return "تہہ خانے میں سرد اندھیرا ہے۔ قربان گاہ جیسی میز کے پیچھے سے بھاری سانسوں کی آواز آ رہی ہے۔"
      end
      return "آپ زنگ آلود چابی سے تالا کھولتے ہیں۔ تہہ خانے کی سیڑھیاں اندھیرے میں ڈوبی ہیں۔ پانی ٹپک رہا ہے، زنجیریں کھنک رہی ہیں اور دور سے بھاری ہنسی آ رہی ہے۔ سامنے ایک قربان گاہ جیسی میز ہے اور اس کے گرد روحوں کی سرگوشیاں ہیں۔"
    end,
    sfx = { "drip", "chains", "creepyLaugh" },
    opts = {
      { t = "روحوں کی سرگوشیاں سنیں",
        show = function() return not flag("voicesDone") end,
        run = function()
          voicePuzzle(function()
            setF("voicesDone"); addScore(40)
            hmsg("روحوں کا جادو ٹوٹ گیا۔ اچانک قربان گاہ کے پیچھے سے ایک بھیانک سایہ اٹھتا ہے۔",
                 { "ghostHaha", "horrorAnimal" }, function() goScene("boss") end)
          end, function() goScene("basement") end)
        end },
      { t = "قربان گاہ کی طرف بڑھیں",
        show = function() return flag("voicesDone") end,
        run = function() goScene("boss") end },
      { t = "اوپر دالان میں واپس جائیں", run = function() goScene("hall") end },
    },
  }

  H.boss = {
    text = "اندھیرے میں ایک بھیانک سایہ سامنے کھڑا ہے۔ جانوروں جیسی غراہٹ اور خوفناک ہنسی گونج رہی ہے۔ وہ کہتا ہے: تم محفوظ نہیں ہو۔ آپ کو فوراً فیصلہ کرنا ہے۔",
    sfx = { "horrorAnimal", "scaryVoice", "notSafe" },
    opts = {
      { t = "ماچس جلا کر موم بتی روشن کریں اور تعویذ آگے کریں",
        show = function() return hasI("amulet") and hasI("candle") and hasI("matches") end,
        run = function()
          addScore(30)
          hmsg("آپ نے ماچس جلا کر موم بتی روشن کی اور تعویذ آگے کیا۔ روشنی اور تعویذ کی طاقت سے سایہ چیختا ہوا پگھل گیا۔",
               { "match", "ghostHaha" }, function() goScene("bossWon") end)
        end },
      { t = "تعویذ آگے کریں",
        show = function() return hasI("amulet") end,
        run = function()
          addScore(15)
          hurt(1, "آپ نے تعویذ آگے کیا۔ سایہ چیخا اور لڑکھڑاتا ہوا پیچھے ہٹتا چلا گیا، لیکن اس کے پنجے سے آپ زخمی ہو گئے۔",
               { "ghostHaha" }, function() goScene("bossWon") end)
        end },
      { t = "نمک کا دائرہ بنائیں",
        show = function() return hasI("salt") end,
        run = function()
          takeI("salt")
          hurt(2, "نمک کا دائرہ سایے کو کچھ دیر روکتا ہے لیکن وہ دائرہ توڑ دیتا ہے۔",
               { "horrorAnimal" }, function() goScene("boss") end)
        end },
      { t = "لوہے کی کیل پھینکیں",
        show = function() return hasI("nail") end,
        run = function()
          takeI("nail")
          hurt(2, "کیل لگنے سے سایہ پل بھر کو پیچھے ہٹا مگر پھر دوبارہ حملہ آور ہو گیا۔",
               { "horrorAnimal" }, function() goScene("boss") end)
        end },
      { t = "پیتل کی گھنٹی بجائیں",
        show = function() return hasI("bell") end,
        run = function()
          takeI("bell")
          hurt(1, "گھنٹی کی آواز سے سایہ لمحہ بھر کو رکا مگر پھر آگے بڑھ آیا۔ گھنٹی ٹوٹ گئی۔",
               { "bell" }, function() goScene("boss") end)
        end },
      { t = "پیچھے مڑ کر بھاگیں",
        run = function()
          hurt(2, "آپ نے بھاگنے کی کوشش کی لیکن سایے نے آپ کا راستہ روک لیا اور آپ کو واپس پھینک دیا۔",
               { "run", "creepyLaugh" }, function() goScene("boss") end)
        end },
    },
  }

  H.bossWon = {
    text = "شیطانی روح غائب ہو چکی ہے۔ قربان گاہ جیسی میز پر ایک بھاری چابی رکھی ہے۔ یہی مرکزی دروازے کی چابی لگتی ہے۔",
    sfx = { "chains" },
    opts = {
      { t = "چابی اٹھا کر اوپر جائیں",
        run = function()
          giveI("gateKey"); addScore(30)
          hmsg("آپ نے چابی اٹھا لی۔ اب جلدی سے صحن کے دروازے تک پہنچنا ہے۔", { "keyTurn" },
               function() goScene("hall") end)
        end },
    },
  }

  H.courtyard = {
    text = "آپ صحن میں پہنچ گئے ہیں۔ تیز ہوا چل رہی ہے اور جھولا خود بخود چرچرا رہا ہے۔ سامنے مرکزی دروازہ نظر آ رہا ہے۔ پیچھے سے آہستہ آہستہ قدموں کی آواز آ رہی ہے۔",
    sfx = { "wind", "swing", "ghostSteps" },
    opts = {
      { t = "دوڑ کر دروازے تک جائیں", run = function() goScene("gate") end },
      { t = "جھولے کو روکنے جائیں",
        run = function()
          hurt(2, "جھولے کے پاس پہنچتے ہی ایک بچی کا سایہ نظر آیا جس نے آپ کا ہاتھ زور سے پکڑ لیا۔",
               { "seeYou", "creepyLaugh" }, function() goScene("courtyard") end)
        end },
      { t = "پیچھے مڑ کر دیکھیں",
        run = function()
          hover("آپ نے پیچھے دیکھا۔ صحن کی روح عین آپ کے پیچھے کھڑی تھی۔ اس نے آپ کو دبوچ لیا۔",
                { "ghostHaha" })
        end },
      { t = "واپس دالان میں جائیں", run = function() goScene("hall") end },
    },
  }

  H.gate = {
    text = "آپ مرکزی دروازے کے سامنے ہیں۔ اس پر بڑا تالا لگا ہے۔ پیچھے سے قدموں کی آواز بالکل قریب آ گئی ہے۔ پھر ایک بھیانک سرگوشی آتی ہے۔",
    sfx = { "ghostSteps", "behindYou" },
    opts = {
      { t = "پیچھے مڑ کر دیکھیں",
        run = function()
          hover("آپ نے مڑ کر دیکھا تو وہی سایہ آپ کے عین سامنے تھا۔ آپ دروازے کے قریب پہنچ کر بھی بچ نہ سکے۔",
                { "ghostHaha" })
        end },
      { t = "چابی تالے میں ڈال کر گھمائیں",
        run = function() hwin() end },
      { t = "گھنٹی بجا کر سایے کو روکیں، پھر چابی گھمائیں",
        show = function() return hasI("bell") end,
        run = function()
          addScore(15)
          hwin()
        end },
      { t = "چیخ کر پوچھیں: کون ہے؟",
        run = function()
          hurt(2, "آپ کی چیخ سن کر سایہ اور قریب آ گیا اور آپ کی گردن پر ٹھنڈا ہاتھ پڑا۔",
               { "scaryVoice" }, function() goScene("gate") end)
        end },
    },
  }

  --------------------------------------------------------
  -- کہانی 2: ویران ہسپتال
  --------------------------------------------------------
  local HAV = H          -- کہانی 1 (حویلی) کے سین
  local HOS = {}         -- کہانی 2 (ہسپتال) کے سین

  -- ہسپتال کی جیت کا متن اور بونس
  local function HOSP_WIN()
    return {
      text = "مبارک ہو! کارڈ سوائپ ہوتے ہی سبز بتی جلی، برقی تالا کھلا اور آپ نور ہسپتال کے بھاری دروازے سے باہر نکل آئے۔ باہر صبح کی روشنی پھیل رہی ہے۔ ",
      base = 300,
      bestKey = "best5",
      bonus = function()
        local b = 0
        if hasI("flare") then b = b + 15 end
        if hasI("scalpel") then b = b + 10 end
        if hasI("battery") then b = b + 10 end
        return b
      end,
    }
  end


  -- تین ہندسوں کا کوڈ: الماری کے اندر سے تین گروہوں میں دستک ہوتی ہے
  local function codePuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local code = hs.code
    local pos, busy = 0, true
    local function knockOnce() playNamed(nil, "h_knockHit", knockHit) end
    local function playCode()
      busy = true
      local t = 0
      for i = 1, #code do
        for _ = 1, code[i] do
          laterG(g, t, knockOnce)
          t = t + 500
        end
        t = t + 1200
      end
      laterG(g, t, function() busy = false end)
    end
    clearScreen("")
    say("الماری کے اندر سے تین گروہوں میں دستک ہوتی ہے۔ ہر گروہ میں جتنی دستکیں ہیں وہی ایک ہندسہ ہے۔ غور سے سنیں اور تینوں ہندسے ترتیب سے دبائیں۔")
    for d = 1, 4 do
      btn("ہندسہ " .. d, function()
        if busy then return end
        pos = pos + 1
        fx("click")
        if d ~= code[pos] then
          busy = true
          hurt(1, "غلط کوڈ! الماری کے اندر سے ایک بھیانک چیخ گونجی۔",
               { "creepyLaugh" }, function() codePuzzle(onOk, onBack) end)
          return
        end
        if pos == #code then
          busy = true
          laterG(g, 800, function() onOk() end)
        end
      end)
    end
    btn("دستک دوبارہ سنیں", function()
      if busy then return end
      pos = 0
      playCode()
    end)
    btn("واپس", onBack)
    laterG(g, 3500, playCode)
  end

  -- تین کمروں کی دل کی مشینیں: پرسکون دھڑکن والا کمرہ ڈھونڈنا
  local function monitorPuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local kinds = { "fast", "flat" }
    shuffle(kinds)
    local room, ki = {}, 1
    for r = 1, 3 do
      if r == hs.calm then
        room[r] = "calm"
      else
        room[r] = kinds[ki]
        ki = ki + 1
      end
    end
    local busy = false
    local function beepOnce1() playNamed(nil, "h_beepOnce", beepOnce) end
    local function playRoom(r)
      if busy then return end
      busy = true
      local kind = room[r]
      if kind == "flat" then
        local d = playNamed(nil, "h_flat", flatlineSound) or 2000
        laterG(g, d + 300, function() busy = false end)
      else
        local count, gap = 4, 1100
        if kind == "fast" then count, gap = 8, 330 end
        for i = 1, count do
          laterG(g, (i - 1) * gap, beepOnce1)
        end
        laterG(g, count * gap + 300, function() busy = false end)
      end
    end
    clearScreen("")
    say("تین کمروں کی مشینیں الگ الگ انداز میں بجتی ہیں۔ پرسکون دل آہستہ اور برابر وقفے سے بیپ دیتا ہے۔ گھبرایا ہوا مریض بہت تیز بیپ دیتا ہے۔ بند دل ایک لمبی مسلسل آواز دیتا ہے۔ ہر کمرے کی مشین سنیں، پھر اس کمرے میں فیوز ڈھونڈیں جس کا دل پرسکون ہو۔")
    for r = 1, 3 do
      btn("کمرہ " .. r .. " کی مشین سنیں", function() playRoom(r) end)
    end
    for r = 1, 3 do
      btn("کمرہ " .. r .. " میں فیوز ڈھونڈیں", function()
        if busy then return end
        busy = true
        if room[r] == "calm" then
          laterG(g, 300, function() onOk() end)
        elseif room[r] == "fast" then
          hurt(1, "اس کمرے میں ایک گھبرائے ہوئے مریض کا بھوت جھپٹا اور چیخا۔",
               { "patientWhisper", "run" }, function() monitorPuzzle(onOk, onBack) end)
        else
          hurt(2, "سیدھی لکیر والی مشین کے پاس ایک سرد ہاتھ نے آپ کی کلائی پکڑ لی۔",
               { "flatline", "creepyLaugh" }, function() monitorPuzzle(onOk, onBack) end)
        end
      end)
    end
    btn("واپس", onBack)
  end

  -- جنریٹر کے پینل کی تین بتیوں کی ترتیب یاد رکھنا
  local function panelPuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local seq = hs.panel
    local pos, busy, replays = 0, true, 2
    clearScreen("")
    say("پینل کی تین بتیاں ہیں: سرخ، ہری اور نیلی، اور ہر بتی کی آواز الگ ہے۔ پہلے ہر بتی کی آواز سنائی جاتی ہے، پھر چھ بتیوں کی ترتیب نام کے ساتھ بجتی ہے۔ آپ وہی ترتیب دہرائیں۔")
    for k = 1, #TONESET_PANEL do
      btn(TONESET_PANEL[k].name, function()
        if busy then return end
        playTone(TONESET_PANEL, k)
        pos = pos + 1
        if k ~= seq[pos] then
          busy = true
          hurt(1, "غلط بتی! پینل سے چنگاریاں نکلیں اور کہیں دور ہنسی کی آواز آئی۔",
               { "flicker", "creepyLaugh" }, function() panelPuzzle(onOk, onBack) end)
          return
        end
        if pos == #seq then
          busy = true
          laterG(g, 1000, function() onOk() end)
        end
      end)
    end
    btn("بتیوں کی آوازیں سنیں (تعارف)", function()
      if busy then return end
      busy = true
      pos = 0
      toneIntro(g, TONESET_PANEL, function() busy = false end)
    end)
    btn("ترتیب دوبارہ سنیں (نام کے ساتھ)", function()
      if busy then return end
      if replays <= 0 then
        say("اب دوبارہ سننے کا موقع باقی نہیں۔")
        return
      end
      replays = replays - 1
      pos = 0
      busy = true
      say("دوبارہ سنیں۔ باقی موقع " .. replays)
      laterG(g, 1000, function()
        toneSeq(g, TONESET_PANEL, seq, true, function() busy = false end)
      end)
    end)
    btn("واپس", onBack)
    local function startSeq()
      laterG(g, 800, function()
        toneSeq(g, TONESET_PANEL, seq, true, function() busy = false end)
      end)
    end
    if hs.introSeen.panel then
      laterG(g, 2500, startSeq)
    else
      hs.introSeen.panel = true
      laterG(g, 3000, function() toneIntro(g, TONESET_PANEL, startSeq) end)
    end
  end

  -- لفٹ: ڈنگ گن کر تیسری منزل (آئی سی یو) پر رکنا
  local function liftPuzzle(onOk, onBack)
    pauseMusic()
    gen = gen + 1
    local g = gen
    local lv, busy = 0, false
    local function move(dir)
      if busy then return end
      if dir < 0 and lv == 0 then
        say("لفٹ سب سے نچلی منزل پر ہے۔")
        return
      end
      local step = random(1, 2)
      if dir < 0 and step > lv then step = lv end
      if dir > 0 and lv + step > 6 then
        say("لفٹ سب سے اوپر کی منزل پر ہے۔")
        return
      end
      lv = lv + dir * step
      busy = true
      local keys = {}
      for i = 1, step do keys[i] = "elevatorDing" end
      hseq(g, keys, function() busy = false end)
    end
    clearScreen("")
    say("لفٹ کے بٹن ٹوٹے ہوئے ہیں، صرف اوپر اور نیچے چلتی ہے۔ وہ ایک بار میں ایک یا دو منزلیں چلتی ہے اور ہر منزل پر ایک ڈنگ دیتی ہے۔ ڈنگ گنیں۔ آپ لابی یعنی صفر منزل سے شروع کر رہے ہیں اور آئی سی یو تیسری منزل پر ہے۔")
    btn("اوپر چلائیں", function() move(1) end)
    btn("نیچے چلائیں", function() move(-1) end)
    btn("یہاں اتریں", function()
      if busy then return end
      if lv == 3 then
        busy = true
        laterG(g, 300, function() onOk() end)
      else
        busy = true
        hurt(1, "غلط منزل! لفٹ کا دروازہ کھلتے ہی ٹھنڈی ہوا اور کسی کے ہنسنے کی آواز آئی۔ آپ گھبرا کر لفٹ میں واپس چلے گئے اور وہ لابی پر آ کھڑی ہوئی۔",
             { "elevatorDoor", "creepyLaugh" }, function() liftPuzzle(onOk, onBack) end)
      end
    end)
    btn("واپس لابی میں", onBack)
  end

  --------------------------------------------------------
  -- ہسپتال کے سین
  --------------------------------------------------------
  HOS.intro = {
    soundFirst = true,
    pre = "آپ رات کے وقت نور ہسپتال کے اندر قدم رکھتے ہیں۔ غور سے سنیں۔",
    text = "آپ ایک صحافی ہیں اور برسوں سے بند پڑے نور ہسپتال کی خبر بنانے آئے ہیں۔ دس سال پہلے یہاں آگ لگی تھی اور رات کی ڈیوٹی کا پورا عملہ لاپتہ ہو گیا تھا۔ آپ اندر پہنچتے ہی ہیں کہ بجلی چلی جاتی ہے، بھاری دروازہ خود بخود بند ہو کر برقی تالے سے جام ہو جاتا ہے، اور بند پڑے اسپیکر سے اناؤنسمنٹ کی گھنٹی گونجتی ہے۔ دروازہ صرف بجلی بحال ہونے اور ایکسیس کارڈ سے کھلے گا۔ آپ کے پاس صرف ایک ٹارچ ہے۔ صبح ہونے سے پہلے آپ کو یہاں سے نکلنا ہے۔",
    sfx = { "rain", "doorClose", "flicker", "announcement" },
    opts = {
      { t = "لابی میں آگے بڑھیں", run = function() goScene("lobby") end },
      { t = "دروازہ زور سے دھکیلیں",
        run = function()
          hmsg("دروازہ ٹس سے مس نہیں ہوتا۔ برقی تالے کی بتی بجھی ہوئی ہے۔", { "doorClose" },
               function() goScene("intro") end)
        end },
    },
  }

  HOS.lobby = {
    text = function()
      local t = "آپ ہسپتال کی لابی میں ہیں۔ ایک طرف ریسیپشن کی میز ہے، دوسری طرف ایمرجنسی وارڈ اور دوائی خانہ۔ سیڑھیاں اوپر وارڈ کی طرف جاتی ہیں، ایک زینہ تہہ خانے میں اترتا ہے، اور سامنے بند لفٹ اور مرکزی دروازہ ہیں۔"
      if flag("power") then
        t = t .. " بجلی بحال ہو چکی ہے، بتیاں ٹمٹما رہی ہیں اور لفٹ کی روشنی جل اٹھی ہے۔"
      end
      if hasI("accessCard") then t = t .. " آپ کے پاس ایکسیس کارڈ ہے، جلدی کریں!" end
      return t
    end,
    sfx = function()
      if flag("power") then return { "flicker", "announcement" } end
      return { "wind", "clock" }
    end,
    opts = {
      { t = "ریسیپشن کی میز دیکھیں", run = function() goScene("reception") end },
      { t = "ایمرجنسی وارڈ میں جائیں", run = function() goScene("er") end },
      { t = "دوائی خانے میں جائیں", run = function() goScene("pharmacy") end },
      { t = "سیڑھیاں چڑھ کر اوپر وارڈ میں جائیں",
        run = function()
          if hasI("staffKey") then
            goScene("ward")
          else
            hmsg("اوپر وارڈ کے دروازے پر پرانا قفل لگا ہے۔ اس کے لیے عملے کی چابی چاہیے۔", { "keyTurn" },
                 function() goScene("lobby") end)
          end
        end },
      { t = "تہہ خانے کی سیڑھیاں اتریں", run = function() goScene("basement") end },
      { t = "لفٹ کا بٹن دبائیں",
        run = function()
          if not flag("power") then
            hmsg("لفٹ کا بٹن دبانے پر کچھ نہیں ہوتا۔ بجلی نہیں ہے۔", { "clock" },
                 function() goScene("lobby") end)
          elseif flag("icuDone") then
            hmsg("آپ آئی سی یو سے ہو آئے ہیں۔ اب لفٹ کی ضرورت نہیں۔", { "elevatorDing" },
                 function() goScene("lobby") end)
          else
            liftPuzzle(function()
              addScore(30)
              hmsg("لفٹ تیسری منزل پر رکی۔ دروازہ کھلا تو سامنے آئی سی یو کا اندھیرا برآمدہ تھا۔",
                   { "elevatorDoor", "wind" }, function() goScene("icu") end)
            end, function() goScene("lobby") end)
          end
        end },
      { t = "مرکزی دروازے کی طرف جائیں",
        run = function()
          if not flag("power") then
            hmsg("برقی تالا بند ہے۔ بجلی کے بغیر یہ نہیں کھلے گا۔", { "keyTurn" },
                 function() goScene("lobby") end)
          elseif not hasI("accessCard") then
            hmsg("کارڈ ریڈر کی لال بتی جل رہی ہے۔ آپ کو ایکسیس کارڈ چاہیے۔", { "keyTurn" },
                 function() goScene("lobby") end)
          else
            goScene("exitHall")
          end
        end },
    },
  }

  HOS.reception = {
    text = "ریسیپشن کی میز پر گرد جمی ہے۔ ایک پرانی ڈائری کھلی پڑی ہے اور ایک دراز آدھی کھلی ہے۔",
    sfx = { "paper", "phone" },
    opts = {
      { t = "نرس کی ڈائری پڑھیں",
        show = function() return not flag("diary") end,
        run = function()
          setF("diary"); addScore(10)
          hmsg("ڈائری میں لکھا ہے: ایک، ویل چیئر کی چرچراہٹ سنو تو بالکل ساکت کھڑے ہو جاؤ، وہ صرف حرکت پر حملہ کرتی ہے۔ دو، رات کو کوئی نام لے کر پکارے تو کبھی جواب مت دینا۔ تین، سائے روشنی سے ڈرتے ہیں۔ ایمرجنسی فلیئر دوائی خانے کی لوہے کی الماری میں بند ہے، جس کا کوڈ الماری خود بتاتی ہے۔ چار، آئی سی یو تیسری منزل پر ہے اور لفٹ ہر منزل پر ایک ڈنگ دیتی ہے۔",
               { "paper" }, function() goScene("reception") end)
        end },
      { t = "دراز کھولیں",
        show = function() return not flag("drawerOpen") end,
        run = function()
          setF("drawerOpen"); giveI("battery"); addScore(5)
          hmsg("دراز میں ایک بیٹری ملی۔ اندھیرے میں ٹارچ تیز کرنے کے کام آئے گی۔", { "drawer" },
               function() goScene("reception") end)
        end },
      { t = "لابی میں واپس جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.er = {
    text = function()
      local t = "ایمرجنسی وارڈ میں الٹے ہوئے اسٹریچر ہیں اور دور سے دل کی مشین کی بیپ آ رہی ہے۔"
      if not flag("scalpel") then t = t .. " ایک ٹرے میں لوہے کا نشتر رکھا ہے۔" end
      if not flag("erKey") then t = t .. " پردے کے پیچھے ایک چابی لٹک رہی ہے۔" end
      return t
    end,
    sfx = { "monitorBeep", "gasHiss" },
    opts = {
      { t = "لوہے کا نشتر اٹھائیں",
        show = function() return not flag("scalpel") end,
        run = function()
          setF("scalpel"); giveI("scalpel"); addScore(10)
          hmsg("آپ نے لوہے کا نشتر اٹھا لیا۔ لوہا بری روحوں کو دور رکھتا ہے۔", { "instruments" },
               function() goScene("er") end)
        end },
      { t = "پردے کے پیچھے سے چابی لیں",
        show = function() return not flag("erKey") end,
        run = function() goScene("erPatrol") end },
      { t = "لابی میں واپس جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.erPatrol = {
    text = "جیسے ہی آپ چابی کی طرف ہاتھ بڑھاتے ہیں، پیچھے سے اسٹریچر کے پہیوں کی گڑگڑاہٹ اور ویل چیئر کی چرچراہٹ آتی ہے۔ کوئی غیر مرئی چیز آپ کی طرف بڑھ رہی ہے۔ جلدی فیصلہ کریں!",
    sfx = { "gurney", "wheelchair" },
    opts = {
      { t = "بالکل ساکت کھڑے ہو جائیں",
        run = function()
          setF("erKey"); giveI("staffKey"); addScore(30)
          hmsg("آپ نے سانس روک لی۔ اسٹریچر آپ کے قریب سے گزر کر آگے دیوار سے ٹکرا گیا اور خاموش ہو گیا۔ آپ نے چابی اتار لی۔",
               { "gurney" }, function() goScene("er") end)
        end },
      { t = "دوڑ کر باہر بھاگیں",
        run = function()
          hurt(2, "آپ کی حرکت کی آواز سن کر وہ جھپٹی اور آپ کو دیوار سے دے مارا۔",
               { "run", "wheelchair", "creepyLaugh" }, function() goScene("er") end)
        end },
      { t = "لوہے کا نشتر آگے کر کے للکاریں",
        show = function() return hasI("scalpel") end,
        run = function()
          setF("erKey"); giveI("staffKey")
          hurt(1, "لوہا دیکھ کر وہ رک گئی مگر جاتے جاتے آپ کو زخمی کر گئی۔ آپ نے چابی اتار لی۔",
               { "wheelchair" }, function() goScene("er") end)
        end },
      { t = "ایمرجنسی فلیئر جلائیں",
        show = function() return hasI("flare") end,
        run = function()
          takeI("flare"); setF("erKey"); giveI("staffKey"); addScore(10)
          hmsg("فلیئر کی لال روشنی سے سایہ چیخ کر بھاگ گیا۔ فلیئر جل کر ختم ہو گیا۔ آپ نے چابی اتار لی۔",
               { "match", "wheelchair" }, function() goScene("er") end)
        end },
    },
  }

  HOS.pharmacy = {
    text = function()
      if flag("pharmOpen") then
        return "دوائی خانے کی الماری کھلی پڑی ہے اور شیلف خالی ہو چکے ہیں۔"
      end
      return "دوائی خانے میں دوائیں فرش پر بکھری ہیں۔ ایک بھاری لوہے کی الماری پر تین ہندسوں کا تالا لگا ہے، اور اس کے اندر سے تین گروہوں میں دستک کی آواز آ رہی ہے۔"
    end,
    sfx = function()
      if flag("pharmOpen") then return { "drip" } end
      return { "instruments" }
    end,
    opts = {
      { t = "الماری کی دستک سنیں اور کوڈ لگائیں",
        show = function() return not flag("pharmOpen") end,
        run = function()
          codePuzzle(function()
            setF("pharmOpen"); giveI("flare"); addScore(40)
            hmsg("تالا کھل گیا! اندر ایمرجنسی فلیئر رکھا ہے۔ یہ روشنی سے سایوں کو بھگا سکتا ہے۔",
                 { "keyTurn", "drawer" }, function() goScene("pharmacy") end)
          end, function() goScene("pharmacy") end)
        end },
      { t = "لابی میں واپس جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.ward = {
    text = function()
      if flag("fuse") then
        return "دوسری منزل کی راہداری میں اب کچھ خاموشی ہے۔ آپ کو فیوز مل چکا ہے۔ اب نیچے تہہ خانے میں جنریٹر کے پاس جانا ہے۔"
      end
      return "آپ دوسری منزل کی راہداری میں ہیں۔ یہاں تین کمرے ہیں: ایک، دو اور تین۔ ہر کمرے سے دل کی مشین کی بیپ آ رہی ہے۔ دیوار پر ایک پرانا نوٹ چپکا ہے: فیوز اسی مریض کے بستر کے پاس رکھا ہے جس کا دل پرسکون دھڑک رہا ہو۔"
    end,
    sfx = function()
      if flag("fuse") then return { "wind" } end
      return { "monitorBeep", "flicker" }
    end,
    opts = {
      { t = "کمروں کی مشینیں سنیں اور فیوز ڈھونڈیں",
        show = function() return not flag("fuse") end,
        run = function()
          monitorPuzzle(function()
            setF("fuse"); giveI("fuse"); addScore(40)
            hmsg("پرسکون دھڑکن والے مریض کے بستر کے پاس ایک چھوٹے ڈبے میں فیوز رکھا تھا۔ آپ نے اسے اٹھا لیا۔",
                 { "drawer", "heartbeat" }, function() goScene("ward") end)
          end, function() goScene("ward") end)
        end },
      { t = "نیچے لابی میں جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.basement = {
    text = function()
      local t = "آپ تہہ خانے کی سیڑھیاں اترتے ہیں۔ یہاں گہرا اندھیرا ہے۔ پانی ٹپک رہا ہے اور دور سے جنریٹر کی گونج سنائی دیتی ہے۔ مردہ خانے کی لوہے کی دراز والی دیوار کے ساتھ ایک راستہ جنریٹر روم کی طرف جاتا ہے۔"
      if flag("lightOn") then t = t .. " ٹارچ میں نئی بیٹری لگی ہے اور روشنی تیز ہے۔" end
      return t
    end,
    sfx = { "drip", "generatorHum" },
    opts = {
      { t = "ٹارچ میں بیٹری لگا کر روشنی تیز کریں",
        show = function() return hasI("battery") and not flag("lightOn") end,
        run = function()
          takeI("battery"); setF("lightOn"); addScore(10)
          hmsg("ٹارچ تیز روشن ہو گئی۔ اب راستہ صاف نظر آ رہا ہے۔", { "keyTurn" },
               function() goScene("basement") end)
        end },
      { t = "جنریٹر روم کی طرف بڑھیں",
        run = function()
          if flag("basePass") then
            goScene("genRoom")
          elseif flag("lightOn") then
            goScene("basePatrol")
          else
            hurt(2, "اندھیرے میں آپ کسی چیز سے ٹکرا گئے اور ٹارچ کی کمزور روشنی میں مردہ خانے کی درازوں سے بھیانک آوازیں آنے لگیں۔",
                 { "chains", "patientWhisper" }, function() goScene("basePatrol") end)
          end
        end },
      { t = "اوپر لابی میں جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.basePatrol = {
    text = "مردہ خانے کی دراز والی دیوار کے پاس پہنچتے ہی کئی آوازیں آپ کا نام لے کر پکارتی ہیں۔ دراز کے اندر سے کوئی پوچھتا ہے: کیا تم مجھے ڈھونڈ رہے ہو؟ آوازیں بہت اپنائیت سے بلا رہی ہیں۔",
    sfx = { "lookingForMe", "patientWhisper", "chains" },
    opts = {
      { t = "جواب دیں: ہاں، میں یہاں ہوں",
        run = function()
          hover("آپ نے جواب دیا تو ایک دراز آہستہ سے کھلی اور اس میں سے ایک برف جیسا ہاتھ نکل کر آپ کو اندر کھینچ لے گیا۔",
                { "creepyLaugh", "ghostHaha" })
        end },
      { t = "خاموشی سے نظریں نیچی رکھ کر آگے بڑھیں",
        run = function()
          setF("basePass"); addScore(30)
          hmsg("آپ نے ایک لفظ نہ کہا اور سیدھے چلتے رہے۔ آوازیں ایک ایک کر کے خاموش ہو گئیں۔",
               { "drip" }, function() goScene("genRoom") end)
        end },
      { t = "کان بند کر کے دوڑیں",
        run = function()
          setF("basePass")
          hurt(1, "آپ دوڑتے ہوئے ایک دراز سے ٹکرائے اور وہ زور سے کھل گئی۔ آپ بمشکل بچ نکلے۔",
               { "run", "chains" }, function() goScene("genRoom") end)
        end },
      { t = "ایمرجنسی فلیئر جلائیں",
        show = function() return hasI("flare") end,
        run = function()
          takeI("flare"); setF("basePass"); addScore(15)
          hmsg("فلیئر کی روشنی میں آوازیں چیخ کر دب گئیں اور درازیں بند ہو گئیں۔ فلیئر ختم ہو گیا۔",
               { "match" }, function() goScene("genRoom") end)
        end },
    },
  }

  HOS.genRoom = {
    text = function()
      if flag("power") then
        return "جنریٹر روم میں مشین گونج رہی ہے اور پینل کی بتیاں جل رہی ہیں۔ بجلی بحال ہو چکی ہے۔"
      end
      return "جنریٹر روم میں ایک بڑا خاموش جنریٹر اور اس کا پینل ہے۔ پینل پر تین بتیاں ہیں: سرخ، ہری اور نیلی۔ فیوز والا خانہ خالی ہے۔"
    end,
    sfx = function()
      if flag("power") then return { "generatorHum" } end
      return { "drip" }
    end,
    opts = {
      { t = "فیوز لگا کر پینل کی بتیاں چلائیں",
        show = function() return hasI("fuse") and not flag("power") end,
        run = function()
          panelPuzzle(function()
            takeI("fuse"); setF("power"); addScore(50)
            hmsg("پینل کی بتیاں ترتیب سے جلیں اور جنریٹر دھڑکتا ہوا چل پڑا۔ پورے ہسپتال کی بتیاں ٹمٹما کر جل اٹھیں۔ اب لفٹ چلے گی اور مرکزی دروازے کا برقی تالا بھی زندہ ہو گیا ہے، مگر اسے کھولنے کے لیے ایکسیس کارڈ چاہیے۔ اوپر کہیں سے ایک ہنسی گونجتی ہے۔",
                 { "powerOn", "generatorHum", "creepyLaugh" }, function() goScene("genRoom") end)
          end, function() goScene("genRoom") end)
        end },
      { t = "فیوز بکس دیکھیں",
        show = function() return not hasI("fuse") and not flag("power") end,
        run = function()
          hmsg("فیوز بکس خالی ہے۔ آپ کو کہیں سے فیوز ڈھونڈ کر لانا ہوگا۔", { "generatorHum" },
               function() goScene("genRoom") end)
        end },
      { t = "اوپر لابی میں جائیں", run = function() goScene("lobby") end },
    },
  }

  HOS.icu = {
    text = "آئی سی یو کا اندھیرا برآمدہ۔ ایک مشین سے مسلسل سیدھی لکیر والی لمبی بیپ آ رہی ہے۔ سامنے ایک نرس کا دھندلا ہیولہ ویل چیئر پر آپ کی طرف بڑھ رہا ہے۔ ویل چیئر چرچرا رہی ہے۔ اس کی گود میں ایک ایکسیس کارڈ رکھا ہے۔",
    sfx = { "flatline", "wheelchair", "patientWhisper" },
    opts = {
      { t = "ساکت کھڑے ہو کر فلیئر جلائیں",
        show = function() return hasI("flare") end,
        run = function()
          takeI("flare"); addScore(40)
          hmsg("آپ ایک انچ نہ ہلے اور فلیئر کی روشنی نرس پر ڈالی۔ وہ چیخ کر دھواں بن گئی اور کارڈ فرش پر گر گیا۔",
               { "match", "ghostHaha" }, function() goScene("icuWon") end)
        end },
      { t = "ساکت کھڑے ہو کر لوہے کا نشتر آگے کریں",
        show = function() return hasI("scalpel") end,
        run = function()
          addScore(15)
          hurt(1, "لوہا دیکھ کر نرس رک گئی مگر اس کا ہاتھ آپ کے بازو کو چھو گیا اور وہ سردی سے سن ہو گیا۔",
               { "wheelchair", "ghostHaha" }, function() goScene("icuWon") end)
        end },
      { t = "فلیئر جلا کر بھاگیں",
        show = function() return hasI("flare") end,
        run = function()
          takeI("flare")
          hurt(2, "فلیئر سے سایہ پیچھے ہٹا، مگر آپ نے حرکت کی تو ویل چیئر نے آپ کو دیوار سے دے مارا۔ پھر بھی کارڈ آپ کے ہاتھ آ گیا۔",
               { "match", "wheelchair" }, function() goScene("icuWon") end)
        end },
      { t = "ساکت کھڑے رہ کر نرس کی گود سے کارڈ نکالنے کی ہمت کریں",
        run = function()
          hurt(3, "آپ نے کانپتے ہاتھوں سے کارڈ اٹھایا۔ نرس کی خالی آنکھیں آپ کو گھورتی رہیں اور اس کی برفیلی سانس آپ کی گردن پر پڑی۔",
               { "flatline", "creepySmile" }, function() goScene("icuWon") end)
        end },
    },
  }

  HOS.icuWon = {
    text = "نرس کا ہیولہ غائب ہو چکا ہے۔ فرش پر ایکسیس کارڈ پڑا ہے۔ اب جلدی سے لفٹ سے نیچے لابی پہنچنا ہے۔",
    sfx = { "wind" },
    opts = {
      { t = "کارڈ اٹھائیں اور لفٹ سے نیچے جائیں",
        run = function()
          giveI("accessCard"); setF("icuDone"); addScore(30)
          hmsg("آپ نے کارڈ اٹھایا اور لفٹ میں بیٹھ کر لابی پہنچ گئے۔", { "elevatorDoor", "elevatorDing" },
               function() goScene("lobby") end)
        end },
    },
  }

  HOS.exitHall = {
    text = "آپ مرکزی دروازے کے سامنے ہیں۔ کارڈ ریڈر کی لال بتی جل رہی ہے۔ پیچھے سے اسٹریچر کی گڑگڑاہٹ اور ویل چیئر کی چرچراہٹ بالکل قریب آ چکی ہے۔ پھر ایک بھیانک سرگوشی آتی ہے۔",
    sfx = { "gurney", "wheelchair", "behindYou" },
    opts = {
      { t = "پیچھے مڑ کر دیکھیں",
        run = function()
          hover("آپ نے مڑ کر دیکھا تو نرس کا خوفناک چہرہ آپ کے عین سامنے تھا۔ دروازہ آپ سے صرف ایک قدم دور رہ گیا تھا۔",
                { "creepySmile", "ghostHaha" })
        end },
      { t = "ساکت کھڑے ہو کر چرچراہٹ رکنے کا انتظار کریں، پھر کارڈ سوائپ کریں",
        run = function() hwin(HOSP_WIN()) end },
      { t = "فلیئر جلا کر کارڈ سوائپ کریں",
        show = function() return hasI("flare") end,
        run = function()
          addScore(15)
          hwin(HOSP_WIN())
        end },
      { t = "فوراً کارڈ سوائپ کرنے کی کوشش کریں",
        run = function()
          hurt(2, "آپ کے ہاتھ کی حرکت کی آواز سن کر ویل چیئر تیزی سے آپ کی طرف لپکی اور آپ کو زور سے دھکا دیا۔",
               { "wheelchair", "gurney" }, function() goScene("exitHall") end)
        end },
    },
  }

  startHospital = function()
    scanSounds()
    scanHorror()
    H = HOS
    hs = { story = 2, courage = MAXC, items = { torch = true }, flags = {}, score = 0, introSeen = {} }
    hs.code = { random(1, 4), random(1, 4), random(1, 4) }
    hs.calm = random(1, 3)
    hs.panel = {}
    for i = 1, 6 do hs.panel[i] = random(#TONESET_PANEL) end
    startMusic()
    goScene("intro")
  end

  tryStart = function(id)
    if id == 1 then startHorror() else startHospital() end
  end

  --------------------------------------------------------
  -- ہارر مینو اور شروع / سیکھنا / جانچ
  --------------------------------------------------------
  startHorror = function()
    scanSounds()
    scanHorror()
    H = HAV
    hs = { story = 1, courage = MAXC, items = { torch = true }, flags = {}, score = 0, introSeen = {} }
    startMusic()
    -- ہر کھیل میں نئی دھن (پانچ سُر)
    hs.melody = {}
    repeat
      for i = 1, 5 do hs.melody[i] = random(#TONESET_MUSIC) end
      local same = true
      for i = 2, 5 do if hs.melody[i] ~= hs.melody[1] then same = false end end
    until not same
    goScene("drive")
  end

  local function learnH()
    gen = gen + 1
    learnChain(gen, hlist, function(k) return hsounds[k].name end,
      function(k) return hplay(k) end,
      function() say("ہارر آوازیں سننا مکمل۔") end)
  end

  local function learnH2()
    gen = gen + 1
    learnChain(gen, hlistH2, function(k) return hsounds[k].name end,
      function(k) return hplay(k) end,
      function() say("ہسپتال کی آوازیں سننا مکمل۔") end)
  end

  local expectedHosp = { "HeartMonitorBeep", "HeartMonitorFlatline", "WheelchairSqueak", "GurneyRolling",
    "ElevatorDing", "ElevatorDoor", "HospitalAnnouncement", "FlickeringLight", "PowerOn",
    "GeneratorHum", "OxygenHiss", "PatientWhisper", "SurgeryTools" }

  local expectedH = { "AreLookingfForMe", "CreepyLaugh", "CreepyThunderClouds", "GhostFootSteps",
    "ghostHuhahaha", "HorrorAnimalSound", "IAmInYourMind", "ICanSeeYou", "ItsBehindYou",
    "KnockingDoor", "Pyle'sScaryVoice", "ScaryCreepyHelloSound", "SwingingSwing",
    "ThereIsNoWayOut", "YouAreNotSafe", "BackgroundCreepySound", "BackgroundHorrorSound",
    "CreepySmileOfSpirit", "drip", "heartbeat", "horrorSound",
    "VehicleIsMovingAndSuddenlyBrakes", "WindSound" }

  local function horrorCheckText()
    scanHorror()
    local ok, miss = 0, {}
    for _, n in ipairs(expectedH) do
      if horrorInfo.files[norm(n)] then ok = ok + 1 else miss[#miss + 1] = n end
    end
    local msg
    if horrorInfo.dir then
      msg = "ہارر فولڈر مل گیا: " .. horrorInfo.dir .. "۔ "
    else
      msg = "ہارر آوازوں کا فولڈر نہیں ملا۔ گیم ان کی جگہ اپنی بنائی ہوئی ڈراؤنی آوازیں بجائے گی۔ "
    end
    msg = msg .. "آپ کی " .. ok .. " آوازیں مل گئیں (کل " .. #expectedH .. " میں سے)۔ "
    if #miss > 0 then msg = msg .. "نہ ملنے والی: " .. table.concat(miss, "، ") .. "۔" end
    -- وہ فائلیں جو گیم نے پہچانی ہی نہیں
    local known = { horrormusicloop = true, horrormusic = true, horrorbackgroundmusic = true,
                    backgroundmusic = true }
    for _, e in pairs(hsounds) do
      if e.files then
        local fl = type(e.files) == "table" and e.files or { e.files }
        for _, f in ipairs(fl) do known[norm(f)] = true end
      end
    end
    local extra = {}
    for k, path in pairs(horrorInfo.files) do
      if not known[k] then extra[#extra + 1] = path:match("([^/]+)$") or path end
    end
    if #extra > 0 then
      msg = msg .. " ایسی فائلیں جنہیں گیم نے استعمال نہیں کیا: " .. table.concat(extra, "، ") .. "۔ ان کے بارے میں مجھے بتا دیں۔"
    end
    -- ہسپتال کی آوازیں اور موسیقی
    local hok, hmiss = 0, {}
    for _, n in ipairs(expectedHosp) do
      if horrorInfo.files[norm(n)] then hok = hok + 1 else hmiss[#hmiss + 1] = n end
    end
    msg = msg .. " ہسپتال کی " .. hok .. " آوازیں مل گئیں (کل " .. #expectedHosp .. " میں سے)۔"
    if #hmiss > 0 then msg = msg .. " نہ ملنے والی: " .. table.concat(hmiss, "، ") .. "۔" end
    if musicFile() then
      msg = msg .. " پس منظر کی موسیقی مل گئی۔"
    else
      msg = msg .. " پس منظر کی موسیقی نہیں ملی (HorrorMusicLoop)۔"
    end
    return msg
  end

  horrorStatus = function()
    if horrorInfo.dir then
      return "ہارر فولڈر مل گیا، " .. horrorInfo.count .. " آوازیں ہیں۔"
    end
    return "ہارر آوازوں کا فولڈر نہیں ملا، گیم اپنی آوازیں استعمال کرے گی۔"
  end

  showHorror = function()
    gen = gen + 1
    stopMusic()
    scanHorror()
    clearScreen("ہارر کہانیاں۔ ان میں ڈراؤنی آوازیں ہیں۔ ہر کہانی میں آپ کسی ڈراؤنی جگہ میں پھنس جاتے ہیں اور صبح سے پہلے نکلنا ہوتا ہے۔ راستے میں پہیلیاں، حفاظتی چیزیں اور خطرے ملیں گے۔ ہمت چھ ہے اور غلط فیصلے سے کم ہوتی ہے۔ ہمت ختم ہو جائے یا کوئی مہلک غلطی ہو جائے تو کھیل ختم ہو جاتا ہے اور آپ فوراً دوبارہ کھیل سکتے ہیں۔ جیتنے پر پوائنٹس ملتے ہیں۔ بہترین سکور: حویلی " ..
      prog.best4 .. "، ہسپتال " .. prog.best5 .. "۔ " .. horrorStatus())
    btn("کہانی 1: ویران حویلی سے فرار", function() tryStart(1) end)
    btn("کہانی 2: ویران ہسپتال", function() tryStart(2) end)
    btn("حویلی کی ڈراؤنی آوازیں سنیں (نام کے ساتھ)", learnH)
    btn("ہسپتال کی آوازیں سنیں (نام کے ساتھ)", learnH2)
    btn("ہارر آوازوں کی جانچ", function() say(horrorCheckText()) end)
    btn("واپس مینو میں", function() showMenu() end)
  end
end

------------------------------------------------------------
-- آوازوں کے فولڈر کی جانچ
------------------------------------------------------------
local expected = { "alarm", "bell", "CarStart", "Clock", "Dog", "doorClose", "Door open",
  "Drawer", "glass", "Horn", "keyTurn", "phone", "Rain", "run", "siren", "steps",
  "Dhol", "papers" }

local function checkSounds()
  scanSounds()
  local ok, miss = 0, {}
  for _, n in ipairs(expected) do
    if userFiles[norm(n)] then ok = ok + 1 else miss[#miss + 1] = n end
  end
  local msg
  if soundDirFound then
    msg = "فولڈر مل گیا: " .. soundDirFound .. "۔ "
  else
    msg = "آپ کا فولڈر نہیں ملا۔ گیم اپنی بنائی ہوئی آوازیں بجا رہی ہے۔ "
  end
  msg = msg .. "آپ کی " .. ok .. " آوازیں مل گئیں۔ "
  if #miss > 0 then msg = msg .. "نہ ملنے والی: " .. table.concat(miss, "، ") .. "۔" end
  -- وہ فائلیں جو گیم نے پہچانی ہی نہیں
  local known = {}
  for _, n in ipairs(expected) do known[norm(n)] = true end
  for _, s in ipairs(sounds) do known[norm(s.user or s.file)] = true end
  for _, v in pairs(dsounds) do
    if v.user then
      local ul = type(v.user) == "table" and v.user or { v.user }
      for _, u in ipairs(ul) do known[norm(u)] = true end
    end
  end
  local extra = {}
  for k, path in pairs(userFiles) do
    if not known[k] then extra[#extra + 1] = path:match("([^/]+)$") or path end
  end
  if #extra > 0 then
    msg = msg .. " ایسی فائلیں جنہیں گیم نے استعمال نہیں کیا: " .. table.concat(extra, "، ") .. "۔ ان کے بارے میں مجھے بتا دیں۔"
  end
  say(msg)
end

------------------------------------------------------------
-- مین مینو
------------------------------------------------------------
showMenu = function()
  gen = gen + 1
  scanSounds()
  stopMusic()
  scanHorror()
  local folderMsg = soundDirFound and ("آپ کی " .. userCount .. " آوازیں مل گئی ہیں۔")
                    or "آپ کا ساؤنڈ فولڈر نہیں ملا، گیم اپنی آوازیں استعمال کرے گی۔"
  clearScreen("آڈیو پزل گیمز میں خوش آمدید! ورژن " .. currentVersion() .. "۔ " .. folderMsg ..
              " یادداشت کا بہترین لیول: " .. prog.best1 ..
              "۔ تجوری کا بہترین سکور: " .. prog.best2 ..
              "۔ جاسوسی کا بہترین سکور: " .. prog.best3 ..
              "۔ ہارر کا بہترین سکور: حویلی " .. prog.best4 .. "، ہسپتال " .. prog.best5 .. "۔")
  btn("آوازوں کی یادداشت", function() showMemory() end)
  btn("تجوری کھولو", function() showSafe() end)
  btn("پراسرار جاسوس", function() showDetective() end)
  btn("ہارر: ویران حویلی سے فرار", function() showHorror() end)
  btn("آوازوں کے فولڈر کی جانچ", checkSounds)
  btn("اپڈیٹ چیک کریں", function() checkUpdate(true) end)
  if updateReady then
    btn("گیم بند کریں (نیا ورژن " .. updateReady .. " چلانے کے لیے)", function() activity.finish() end)
  end
  btn("باہر نکلیں", function() activity.finish() end)
end

scanSounds()
scanHorror()
loadProg()
showMenu()

-- گیم کھلنے کے تھوڑی دیر بعد خودکار اپڈیٹ چیک (اگر اس دوران آپ کسی اور سکرین پر چلے گئے ہوں تو نہیں)
do
  local g0 = gen
  later(2500, function()
    if g0 == gen then checkUpdate(false) end
  end)
end

-- گیم کی اپنی آوازیں ایک بار بنا لیں (صرف وہی جو آپ کے فولڈر میں نہیں)
later(300, function()
  for _, s in ipairs(sounds) do
    if not findUser(s.user or s.file) then getSound("s_" .. s.file, s.build) end
  end
  local fxb = { ding = function() return bellSound(1320, 600, 3) end,
                fail = failSound, click = clickSound, open = openSound }
  for n, b in pairs(fxb) do getSound("fx_" .. n, b) end
  later(1500, function()
    for k, s in pairs(dsounds) do
      if not findUser(s.user) then
        getSound(s.key or ("d_" .. k), s.build)
      end
    end
  end)
end)