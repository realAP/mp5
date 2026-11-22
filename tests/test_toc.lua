-- Prueft die Verpackung: die TOC-Datei muss jede Lua-Datei des Addons
-- laden, und die Version muss ueberall dieselbe sein.
--
-- Beides sind Fehler, die man im Spiel erst merkt, wenn etwas fehlt - und
-- bei einem Release zu spaet.

local fails = 0
local function check(name, got, want)
  if got ~= want then fails = fails + 1 end
  print(string.format("%-54s %-14s erwartet %s", name, tostring(got), tostring(want)),
        got == want and "OK" or "FEHLER")
end

local src = os.getenv("MP5_SRC") or "MP5"

local toc = {}
local version
for line in io.lines(src .. "/MP5.toc") do
  line = line:gsub("\r", "")
  local v = line:match("^## Version:%s*(.-)%s*$")
  if v then version = v end
  local file = line:match("^([%w_]+%.lua)%s*$")
  if file then toc[file] = true end
end

check("TOC nennt eine Version", version ~= nil, true)

-- Jede Datei im Addon-Ordner muss in der TOC stehen.
local p = io.popen("ls " .. src .. "/*.lua")
local missing = {}
for path in p:lines() do
  local file = path:match("([%w_]+%.lua)$")
  if file and not toc[file] then missing[#missing + 1] = file end
end
p:close()
check("jede Lua-Datei wird geladen", #missing == 0 and "ja"
      or ("fehlt in der TOC: " .. table.concat(missing, ", ")), "ja")

-- Und umgekehrt: nichts laden, was es nicht gibt.
local gone = {}
for file in pairs(toc) do
  local f = io.open(src .. "/" .. file)
  if f then f:close() else gone[#gone + 1] = file end
end
check("keine Datei fehlt auf der Platte", #gone == 0 and "ja"
      or ("steht in der TOC, fehlt aber: " .. table.concat(gone, ", ")), "ja")

-- Das Changelog muss dieselbe Version oben nennen.
local top
for line in io.lines("CHANGELOG.md") do
  local v = line:match("^##%s+([%d%.]+)")
  if v then top = v break end
end
check("Changelog nennt dieselbe Version", top, version)

print("")
if fails == 0 then
  print("Alle Tests bestanden.")
else
  print(fails .. " Test(s) fehlgeschlagen.")
  os.exit(1)
end
