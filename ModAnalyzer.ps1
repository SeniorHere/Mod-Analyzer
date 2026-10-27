# =====================================================================
#   MOD ANALYZER  |  by Senior  |  https://discord.gg/95MmttMD6
#   Scans ONLY: .minecraft\versions , .minecraft\mods , .minecraft\modpacks
#   Reads every .jar from the inside (class paths + code strings + mod metadata)
#   and scores it, so real cheats are separated from normal mods.
# =====================================================================

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.WindowTitle = 'Mod Analyzer  |  Senior' } catch {}
$Discord = 'https://discord.gg/95MmttMD6'
$Dot = [string][char]0x25CF

# ---------------------------------------------------------------------
#  Scanner engine (C#, fast single-pass multi-string matcher)
# ---------------------------------------------------------------------
$Source = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace SeniorMA
{
    public class Hit
    {
        public string Rel = "";
        public string Name = "";
        public long Size;
        public string ModId = "";
        public string ModName = "";
        public string Level = "";
        public int Score;
        public string Client = "";
        public bool Renamed;
        public List<string> Terms = new List<string>();
        public List<string> Why = new List<string>();
    }

    internal class Matcher
    {
        public int[] Go;
        public int[][] Out;

        static int[] NewRow()
        {
            int[] r = new int[128];
            for (int i = 0; i < 128; i++) r[i] = -1;
            return r;
        }

        public Matcher(List<string> pats)
        {
            List<int[]> go = new List<int[]>();
            List<List<int>> outs = new List<List<int>>();
            go.Add(NewRow());
            outs.Add(null);
            for (int p = 0; p < pats.Count; p++)
            {
                int s = 0;
                string w = pats[p];
                for (int i = 0; i < w.Length; i++)
                {
                    int c = w[i] & 127;
                    if (go[s][c] == -1)
                    {
                        go.Add(NewRow());
                        outs.Add(null);
                        go[s][c] = go.Count - 1;
                    }
                    s = go[s][c];
                }
                if (outs[s] == null) outs[s] = new List<int>();
                outs[s].Add(p);
            }
            int n = go.Count;
            int[] fail = new int[n];
            Queue<int> q = new Queue<int>();
            for (int c = 0; c < 128; c++)
            {
                int t = go[0][c];
                if (t == -1) go[0][c] = 0;
                else { fail[t] = 0; q.Enqueue(t); }
            }
            while (q.Count > 0)
            {
                int r = q.Dequeue();
                for (int c = 0; c < 128; c++)
                {
                    int t = go[r][c];
                    if (t == -1)
                    {
                        go[r][c] = go[fail[r]][c];
                    }
                    else
                    {
                        q.Enqueue(t);
                        fail[t] = go[fail[r]][c];
                        if (outs[fail[t]] != null)
                        {
                            if (outs[t] == null) outs[t] = new List<int>();
                            outs[t].AddRange(outs[fail[t]]);
                        }
                    }
                }
            }
            Go = new int[n * 128];
            for (int i = 0; i < n; i++) Array.Copy(go[i], 0, Go, i * 128, 128);
            Out = new int[n][];
            for (int i = 0; i < n; i++) Out[i] = (outs[i] == null) ? null : outs[i].ToArray();
        }

        public void Scan(byte[] b, int len, bool[] found, bool dotToSlash)
        {
            int s = 0;
            for (int i = 0; i < len; i++)
            {
                int c = b[i];
                if (c >= 65 && c <= 90) c += 32;
                else if (dotToSlash && c == 46) c = 47;
                if (c > 127) { s = 0; continue; }
                s = Go[(s << 7) + c];
                int[] o = Out[s];
                if (o != null)
                {
                    for (int k = 0; k < o.Length; k++) found[o[k]] = true;
                }
            }
        }
    }

    public static class Scanner
    {
        public static int Done;
        public static int Total;
        public static int Unreadable;
        public static List<Hit> Results = new List<Hit>();
        public static List<string> Failed = new List<string>();

        static readonly object Gate = new object();
        const int MaxRead = 1048576;
        [ThreadStatic] static byte[] tbuf;

        // { display name, file-name key, token, token, ... }  (tokens lowercase, path-like = strong)
        static readonly string[][] ClientDefs = new string[][]
        {
            new string[]{"Meteor Client","meteor","meteordevelopment/meteorclient","minegame159/meteorclient","meteor-client","meteorclient"},
            new string[]{"Wurst Client","wurst","net/wurstclient","wurstclient","wurst-imperium"},
            new string[]{"BleachHack","bleach","org/bleachhack","bleachhack"},
            new string[]{"Sigma","sigma","info/sigmaclient","sigmaclient"},
            new string[]{"Impact","impact","impactclient"},
            new string[]{"Vape","vape","vape.gg","vapelite","vapev4","vape-v4","vapeclient"},
            new string[]{"Jigsaw","jigsaw","jigsawclient"},
            new string[]{"LiquidBounce","liquidbounce","net/ccbluex","liquidbounce","ccbluex"},
            new string[]{"FDPClient","fdp","fdpclient","unlegitmc"},
            new string[]{"Raven B+","raven","ravenbplus","raven b+","ravenb+","ravenb4","ravenbs"},
            new string[]{"Ares","ares","aresclient","ares-client"},
            new string[]{"Hydra","hydra","hydraclient","hydra-client"},
            new string[]{"Xulu","xulu","xuluclient","xulu-client"},
            new string[]{"Flux","flux","fluxclient","flux-client"},
            new string[]{"Perish","perish","perishclient"},
            new string[]{"Jex","jex","jexclient","jex-client"},
            new string[]{"Frost","frost","frostclient"},
            new string[]{"Itami","itami","itamiclient","itami-client"},
            new string[]{"Polar","polar","polarclient","polar-client"},
            new string[]{"Curse","curse","curseclient"},
            new string[]{"Dopium","dopium","dopium"},
            new string[]{"Future","future","net/futureclient","futureclient"},
            new string[]{"RusherHack","rusher","org/rusherhack","rusherhack"},
            new string[]{"Aristois","aristois","aristois"},
            new string[]{"SalHack","salhack","salhack"},
            new string[]{"KAMI Blue","kami","org/kamiblue","kamiblue"},
            new string[]{"Lambda","lambda","com/lambda/client","lambda-client"},
            new string[]{"ForgeHax","forgehax","forgehax"},
            new string[]{"Konas","konas","konasclient"},
            new string[]{"Phobos","phobos","me/earth/phobos"},
            new string[]{"3arthh4ck","earth","earthhack","3arthh4ck"},
            new string[]{"GameSense","gamesense","gamesense"},
            new string[]{"Seppuku","seppuku","rigamortis"},
            new string[]{"Huzuni","huzuni","huzuni"},
            new string[]{"Inertia","inertia","inertiaclient"},
            new string[]{"Mathax","mathax","mathax"},
            new string[]{"ThunderHack","thunder","thunderhack"},
            new string[]{"Novoline","novoline","novoline"},
            new string[]{"Rise","rise","riseclient","rise-client"},
            new string[]{"Tenacity","tenacity","dev/tenacity","tenacityclient"},
            new string[]{"Remix","remix","remixclient"},
            new string[]{"Moon Client","moon","moonclient"},
            new string[]{"Drip","drip","dripclient"},
            new string[]{"Entropy","entropy","entropyclient"},
            new string[]{"Nodus","nodus","nodusclient"},
            new string[]{"Doomsday","doomsday","doomsdayclient"},
            new string[]{"Argon","argon","argonclient","argon-client"},
            new string[]{"Prestige","prestige","prestigeclient","prestige-client"},
            new string[]{"Krypton Client","krypton","kryptonclient"},
            new string[]{"Aoba","aoba","net/aoba","aoba-client"},
            new string[]{"Coffee","coffee","coffeeclient"},
            new string[]{"Wolfram","wolfram","wolframclient"}
        };

        static readonly string[] Terms = new string[]
        {
            "KillAura","AutoCrystal","CrystalAura","TriggerBot","AutoTotem","AimAssist","AimBot",
            "AnchorAura","AutoAnchor","AutoHitCrystal","AutoDoubleHand","AutoDTap","AutoPot",
            "AutoClicker","SilentAim","TpAura","MultiAura","ClickAura","ShieldBreaker",
            "AutoShieldBreak","AntiKnockback","AutoInvTotem","TotemBot","CrystalOptimizer",
            "AutoWTap","HitSelect","JitterClick","ClickMacro","CrystalMacro","AnchorMacro",
            "TotemMacro","ChestESP","PlayerESP","StorageESP","BlockESP","ElytraFly","BoatFly",
            "PacketFly","CreativeFly","FlyHack","ReachHack","ScaffoldWalk",
            "BedAura","HoleESP","HoleFill"
        };

        static readonly string[] StructCombat = { "modules/combat", "module/combat", "hacks/combat", "modules/impl/combat", "module/impl/combat" };
        static readonly string[][] StructOthers = new string[][]
        {
            new string[]{"modules/movement","module/movement","hacks/movement","modules/impl/movement"},
            new string[]{"modules/render","module/render","hacks/render","modules/impl/render"},
            new string[]{"modules/exploit","module/exploit","hacks/exploit","modules/impl/exploit"},
            new string[]{"modules/player","module/player","hacks/player","modules/impl/player"}
        };

        // legit / anti-cheat markers: lower the level unless a real client is identified
        static readonly string[] AntiMarkers = { "grimac", "nocheatplus", "anticheat", "anti-cheat", "cheatbreaker" };

        // known legit mod ids: skipped unless a cheat client is found inside their class paths
        static readonly HashSet<string> Allow = new HashSet<string>(new string[]
        {
            "fabric-api","fabricloader","fabric-language-kotlin","sodium","lithium","phosphor","iris","indium",
            "starlight","ferritecore","modmenu","optifine","optifabric","jei","rei","roughlyenoughitems","emi",
            "journeymap","xaerominimap","xaeroworldmap","voxelmap","litematica","malilib","tweakeroo","minihud",
            "itemscroller","replaymod","cloth-config","cloth-config2","architectury","appleskin","lambdynlights",
            "create","essential","canvas","entityculling","immediatelyfast","dynamic-fps","betterf3","yacl",
            "yet_another_config_lib_v3","jade","wthit","mouse-tweaks","mousetweaks","inventory-profiles-next",
            "controlling","configured","forge","neoforge","minecraft","java","mixinextras","noisium","moreculling",
            "badoptimizations","c2me","krypton","viafabric","viafabricplus","viaversion","fancymenu","konkrete"
        });

        static List<string> Pats = new List<string>();
        static List<int> Kind = new List<int>();
        static List<int> Owner = new List<int>();
        static Matcher M;

        static readonly string[] SkipPrefix = new string[]
        {
            "net/minecraft/","com/mojang/","net/minecraftforge/","net/neoforged/","net/fabricmc/",
            "org/spongepowered/","kotlin/","kotlinx/","org/apache/","com/google/","io/netty/",
            "org/objectweb/","it/unimi/","javax/","org/lwjgl/","org/joml/","org/slf4j/",
            "org/jetbrains/","org/intellij/","org/yaml/","org/json/","org/quiltmc/","org/antlr/",
            "org/ow2/","org/eclipse/","org/bouncycastle/"
        };

        static void Add(string p, int kind, int owner)
        {
            Pats.Add(p);
            Kind.Add(kind);
            Owner.Add(owner);
        }

        static Scanner()
        {
            for (int i = 0; i < ClientDefs.Length; i++)
                for (int j = 2; j < ClientDefs[i].Length; j++)
                    Add(ClientDefs[i][j].ToLowerInvariant(), 0, i);
            for (int i = 0; i < Terms.Length; i++) Add(Terms[i].ToLowerInvariant(), 1, i);
            for (int i = 0; i < StructCombat.Length; i++) Add(StructCombat[i], 2, 0);
            for (int g = 0; g < StructOthers.Length; g++)
                for (int i = 0; i < StructOthers[g].Length; i++) Add(StructOthers[g][i], 2, g + 1);
            for (int i = 0; i < AntiMarkers.Length; i++) Add(AntiMarkers[i], 3, 0);
            M = new Matcher(Pats);
        }

        public static Task Start(string root, string[] files)
        {
            Done = 0;
            Total = files.Length;
            Unreadable = 0;
            Results = new List<Hit>();
            Failed = new List<string>();
            Action a = delegate { Run(root, files); };
            return Task.Factory.StartNew(a, TaskCreationOptions.LongRunning);
        }

        static void Run(string root, string[] files)
        {
            int dop = Math.Max(1, Math.Min(4, Environment.ProcessorCount - 1));
            ParallelOptions po = new ParallelOptions();
            po.MaxDegreeOfParallelism = dop;
            Parallel.ForEach(files, po, delegate (string f)
            {
                try
                {
                    ScanJar(root, f);
                }
                catch (Exception)
                {
                    lock (Gate)
                    {
                        Unreadable++;
                        Failed.Add(f);
                    }
                }
                Interlocked.Increment(ref Done);
            });
        }

        static bool SkipContent(string low)
        {
            for (int i = 0; i < SkipPrefix.Length; i++)
                if (low.StartsWith(SkipPrefix[i], StringComparison.Ordinal)) return true;
            return false;
        }

        static bool IsMeta(string low)
        {
            if (low == "fabric.mod.json" || low == "quilt.mod.json" || low == "mcmod.info" ||
                low == "meta-inf/mods.toml" || low == "meta-inf/neoforge.mods.toml" ||
                low == "plugin.yml" || low == "paper-plugin.yml") return true;
            if (low.EndsWith(".json") && low.IndexOf("mixin") >= 0 && low.IndexOf('/') < 0) return true;
            return false;
        }

        static int ReadEntry(ZipArchiveEntry e, byte[] buf, int max)
        {
            int total = 0;
            try
            {
                using (Stream s = e.Open())
                {
                    int lim = Math.Min(max, buf.Length);
                    int n;
                    while (total < lim && (n = s.Read(buf, total, lim - total)) > 0) total += n;
                }
            }
            catch (Exception) { }
            return total;
        }

        static string Rx(string text, string pattern)
        {
            Match m = Regex.Match(text, pattern, RegexOptions.IgnoreCase | RegexOptions.Multiline);
            return m.Success ? m.Groups[1].Value.Trim() : "";
        }

        static void ScanJar(string root, string file)
        {
            FileInfo fi = new FileInfo(file);
            string rel = file.StartsWith(root, StringComparison.OrdinalIgnoreCase)
                ? file.Substring(root.Length).TrimStart('\\', '/') : file;
            int P = Pats.Count;
            bool[] pf = new bool[P];
            bool[] cf = new bool[P];
            bool[] tmp = new bool[P];
            string modId = "";
            string modName = "";
            int classes = 0;
            int shortNames = 0;
            long budget = 80L * 1024 * 1024;
            if (tbuf == null) tbuf = new byte[MaxRead];
            byte[] buf = tbuf;

            using (FileStream fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (ZipArchive za = new ZipArchive(fs, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry e in za.Entries)
                {
                    string low = e.FullName.ToLowerInvariant();
                    byte[] nb = Encoding.UTF8.GetBytes(low);
                    M.Scan(nb, nb.Length, pf, false);

                    if (low.EndsWith(".class"))
                    {
                        classes++;
                        string simple = low.Substring(low.LastIndexOf('/') + 1);
                        if (simple.Length - 6 <= 2) shortNames++;
                        if (budget <= 0) continue;
                        if (SkipContent(low)) continue;
                        int n = ReadEntry(e, buf, MaxRead);
                        budget -= n;
                        M.Scan(buf, n, cf, false);
                        continue;
                    }

                    if (IsMeta(low))
                    {
                        int n = ReadEntry(e, buf, 262144);
                        Array.Clear(tmp, 0, tmp.Length);
                        M.Scan(buf, n, tmp, true);
                        for (int p = 0; p < P; p++)
                        {
                            if (!tmp[p]) continue;
                            if (Kind[p] == 0) pf[p] = true; else cf[p] = true;
                        }
                        string text = Encoding.UTF8.GetString(buf, 0, n);
                        if (modId == "")
                        {
                            if (low == "fabric.mod.json" || low == "quilt.mod.json")
                            {
                                modId = Rx(text, "\"id\"\\s*:\\s*\"([^\"]+)\"");
                                if (modName == "") modName = Rx(text, "\"name\"\\s*:\\s*\"([^\"]*)\"");
                            }
                            else if (low.EndsWith("mods.toml"))
                            {
                                modId = Rx(text, "modId\\s*=\\s*\"([^\"]+)\"");
                                if (modName == "") modName = Rx(text, "displayName\\s*=\\s*\"([^\"]*)\"");
                            }
                            else if (low == "mcmod.info")
                            {
                                modId = Rx(text, "\"modid\"\\s*:\\s*\"([^\"]+)\"");
                                if (modName == "") modName = Rx(text, "\"name\"\\s*:\\s*\"([^\"]*)\"");
                            }
                            else if (low.EndsWith("plugin.yml"))
                            {
                                modName = Rx(text, "^name:\\s*(.+)$");
                                modId = modName;
                            }
                        }
                    }
                }
            }

            if (classes == 0) return;

            int CN = ClientDefs.Length;
            int TN = Terms.Length;
            int[] cp = new int[CN];
            int[] cc = new int[CN];
            int[] tp = new int[TN];
            bool combat = false;
            bool[] other = new bool[8];
            bool anti = false;
            for (int p = 0; p < P; p++)
            {
                int k = Kind[p];
                int o = Owner[p];
                if (k == 0)
                {
                    if (pf[p]) cp[o]++;
                    if (cf[p]) cc[o]++;
                }
                else if (k == 1)
                {
                    if (pf[p]) tp[o] = 2;
                    else if (cf[p] && tp[o] == 0) tp[o] = 1;
                }
                else if (k == 2)
                {
                    if (pf[p]) { if (o == 0) combat = true; else other[o] = true; }
                }
                else if (k == 3)
                {
                    if (pf[p] || cf[p]) anti = true;
                }
            }

            int best = -1;
            int bestScore = 0;
            bool clientPath = false;
            for (int c = 0; c < CN; c++)
            {
                int s = Math.Min(cp[c], 1) * 10 + Math.Min(cc[c], 2) * 4;
                if (s > bestScore) { bestScore = s; best = c; }
            }
            if (best >= 0 && cp[best] > 0) clientPath = true;

            string idLow = modId.ToLowerInvariant();
            if (idLow != "" && Allow.Contains(idLow) && !clientPath) return;

            Hit h = new Hit();
            h.Rel = rel;
            h.Name = fi.Name;
            h.Size = fi.Length;
            h.ModId = modId;
            h.ModName = modName;

            int score = 0;
            if (best >= 0)
            {
                score += bestScore;
                h.Client = ClientDefs[best][0];
                if (clientPath) h.Why.Add("Known client package / ID found in the jar's files and metadata");
                else h.Why.Add("Client name found inside the code (not in file paths)");
            }

            int strongPath = 0;
            int strongCont = 0;
            List<string> contTerms = new List<string>();
            for (int t = 0; t < TN; t++)
            {
                if (tp[t] == 2) { score += 3; strongPath++; h.Terms.Add(Terms[t]); }
                else if (tp[t] == 1) { score += 1; strongCont++; contTerms.Add(Terms[t]); }
            }
            for (int t = 0; t < contTerms.Count && h.Terms.Count < 10; t++) h.Terms.Add(contTerms[t]);
            if (strongPath > 0) h.Why.Add(strongPath + " class/file name(s) match known cheat modules");
            if (strongCont > 0) h.Why.Add(strongCont + " cheat-module string(s) found inside the code");

            int others = 0;
            for (int i = 1; i < 8; i++) if (other[i]) others++;
            if (combat && others >= 1)
            {
                score += 4;
                h.Why.Add("Cheat-client folder layout (modules/combat + movement/render/...)");
            }

            bool obf = classes >= 30 && shortNames * 2 >= classes;
            if (score > 0 && obf)
            {
                score += 1;
                h.Why.Add("Heavily obfuscated (most class names are 1-2 letters)");
            }

            string level = "";
            if (score >= 9) level = "HIGH";
            else if (score >= 6) level = "MEDIUM";
            else if (score >= 4) level = "LOW";
            if (level == "") return;

            if (anti && !clientPath && level != "LOW")
            {
                level = "LOW";
                h.Why.Add("Anti-cheat / legit marker present - level reduced (could be a detection mod)");
            }

            if (best >= 0 && (clientPath || score >= 9))
            {
                string fn = fi.Name.ToLowerInvariant();
                if (fn.IndexOf(ClientDefs[best][1]) < 0)
                {
                    h.Renamed = true;
                    h.Why.Add("FILE NAME DOES NOT MATCH the client inside (renamed jar)");
                }
            }

            h.Level = level;
            h.Score = score;
            lock (Gate) { Results.Add(h); }
        }
    }
}
'@

function Initialize-Engine {
    if ('SeniorMA.Scanner' -as [type]) { return $true }
    $attempts = @(
        @('System.IO.Compression', 'System.IO.Compression.FileSystem'),
        @()
    )
    foreach ($refs in $attempts) {
        try {
            if ($refs.Count -gt 0) {
                Add-Type -TypeDefinition $Source -ReferencedAssemblies $refs -ErrorAction Stop
            } else {
                Add-Type -TypeDefinition $Source -ErrorAction Stop
            }
            return $true
        } catch {
            $script:EngineError = $_.Exception.Message
        }
    }
    return $false
}

# ---------------------------------------------------------------------
#  Look & feel
# ---------------------------------------------------------------------
function Show-Banner {
    $glyph = @{
        'S' = @('01110', '10000', '01110', '00001', '11110')
        'E' = @('11111', '10000', '11110', '10000', '11111')
        'N' = @('10001', '11001', '10101', '10011', '10001')
        'I' = @('11111', '00100', '00100', '00100', '11111')
        'O' = @('01110', '10001', '10001', '10001', '01110')
        'R' = @('11110', '10001', '11110', '10010', '10001')
    }
    $word = 'SENIOR'
    $palette = @('Cyan', 'Cyan', 'Magenta', 'Magenta', 'Cyan', 'Cyan')
    Write-Host ''
    for ($r = 0; $r -lt 5; $r++) {
        Write-Host '      ' -NoNewline
        for ($li = 0; $li -lt $word.Length; $li++) {
            $row = $glyph[[string]$word[$li]][$r]
            $line = ''
            foreach ($ch in $row.ToCharArray()) {
                if ($ch -eq '1') { $line += "$Dot " } else { $line += '  ' }
            }
            Write-Host ($line + '  ') -NoNewline -ForegroundColor $palette[$li]
        }
        Write-Host ''
    }
    Write-Host ''
    Write-Host ('      ' + (($Dot + ' ') * 34)) -ForegroundColor DarkGray
    Write-Host '        M O D   A N A L Y Z E R' -ForegroundColor White
    Write-Host ('        Discord academy : ' + $Discord) -ForegroundColor DarkCyan
    Write-Host ('      ' + (($Dot + ' ') * 34)) -ForegroundColor DarkGray
    Write-Host ''
}

function Write-Finding($h, $color) {
    $scope = ($h.Rel -split '[\\/]')[0]
    Write-Host ''
    Write-Host '  ' -NoNewline
    Write-Host (' ' + $h.Level + ' ') -NoNewline -ForegroundColor Black -BackgroundColor $color
    Write-Host ('  ' + $h.Name) -NoNewline -ForegroundColor White
    Write-Host ('   [' + $scope + ']') -ForegroundColor DarkGray
    if ($h.ModName -or $h.ModId) {
        $label = $h.ModName
        if ($h.ModId -and $h.ModId -ne $h.ModName) {
            if ($label) { $label = "$label ($($h.ModId))" } else { $label = $h.ModId }
        }
        Write-Host '     Mod      : ' -NoNewline -ForegroundColor DarkGray
        Write-Host $label -ForegroundColor Gray
    }
    if ($h.Client) {
        Write-Host '     Client   : ' -NoNewline -ForegroundColor DarkGray
        Write-Host $h.Client -NoNewline -ForegroundColor Red
        if ($h.Renamed) { Write-Host '   <-- RENAMED FILE' -NoNewline -ForegroundColor Red }
        Write-Host ''
    }
    if ($h.Terms -and $h.Terms.Count -gt 0) {
        Write-Host '     Strings  : ' -NoNewline -ForegroundColor DarkGray
        foreach ($t in $h.Terms) { Write-Host ($t + '  ') -NoNewline -ForegroundColor Red }
        Write-Host ''
    }
    foreach ($w in $h.Why) {
        Write-Host '     Why      : ' -NoNewline -ForegroundColor DarkGray
        Write-Host $w -ForegroundColor Gray
    }
    Write-Host '     Path     : ' -NoNewline -ForegroundColor DarkGray
    Write-Host $h.Rel -ForegroundColor DarkGray
    $key = "$($h.Name)|$($h.Size)"
    if ($script:Dups.ContainsKey($key) -and $script:Dups[$key] -gt 0) {
        Write-Host ('     Copies   : +' + $script:Dups[$key] + ' identical copy(ies) in other folders') -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------
function Main {
    Show-Banner

    try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch {}

    if (-not (Initialize-Engine)) {
        Write-Host '  Could not start the scan engine.' -ForegroundColor Red
        if ($script:EngineError) { Write-Host ('  ' + $script:EngineError) -ForegroundColor DarkGray }
        return
    }

    $mc = Join-Path $env:APPDATA '.minecraft'
    if (-not (Test-Path -LiteralPath $mc)) {
        Write-Host '  .minecraft was not found automatically.' -ForegroundColor Yellow
        $mc = Read-Host '  Paste the full path of the .minecraft folder'
        $mc = $mc.Trim('"', ' ')
        if (-not (Test-Path -LiteralPath $mc)) {
            Write-Host '  Path not found. Exiting.' -ForegroundColor Red
            return
        }
    }
    $mc = $mc.TrimEnd('\', '/')

    $script:Dups = @{}
    $unique = @{}
    $scopes = @('versions', 'mods', 'modpacks')
    $folderHits = New-Object System.Collections.ArrayList

    Write-Host '  Collecting jar files (versions / mods / modpacks only)...' -ForegroundColor Cyan
    foreach ($s in $scopes) {
        $p = Join-Path $mc $s
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Host ('    ' + $Dot + ' ' + $s.PadRight(9) + ' not found') -ForegroundColor DarkGray
            continue
        }
        $files = @(Get-ChildItem -LiteralPath $p -Filter '*.jar*' -Recurse -File -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match '\.jar(\.disabled)?$' -and $_.Length -gt 100 })
        Write-Host ('    ' + $Dot + ' ' + $s.PadRight(9) + ' ' + $files.Count + ' jar(s)') -ForegroundColor Gray
        foreach ($f in $files) {
            $key = "$($f.Name)|$($f.Length)"
            if ($unique.ContainsKey($key)) {
                if ($script:Dups.ContainsKey($key)) { $script:Dups[$key]++ } else { $script:Dups[$key] = 1 }
            } else {
                $unique[$key] = $f.FullName
            }
        }
    }

    # version folders named like a cheat client
    $vp = Join-Path $mc 'versions'
    if (Test-Path -LiteralPath $vp) {
        $rx = '(?i)meteor|wurst|bleachhack|liquidbounce|vape|fdpclient|rusherhack|aristois|impact|sigma|jigsaw|novoline|tenacity|kamiblue|salhack|forgehax|huzuni|aoba|dopium|ravenb|xulu|itami|hydra'
        foreach ($d in (Get-ChildItem -LiteralPath $vp -Directory -ErrorAction SilentlyContinue)) {
            if ($d.Name -match $rx) {
                [void]$folderHits.Add([pscustomobject]@{
                    Level = 'LOW'; Name = $d.Name; Rel = ('versions\' + $d.Name); Size = 0; Score = 3
                    ModId = ''; ModName = ''; Client = $Matches[0]; Renamed = $false
                    Terms = @(); Why = @('Version folder name looks like a cheat client (check it manually)')
                })
            }
        }
    }

    $paths = [string[]]@($unique.Values)
    Write-Host ''
    if ($paths.Count -eq 0) {
        Write-Host '  No jar files found in those folders.' -ForegroundColor Yellow
    } else {
        Write-Host ('  Analyzing ' + $paths.Count + ' unique jar(s)...') -ForegroundColor Cyan
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if ($paths.Count -gt 0) {
        $task = [SeniorMA.Scanner]::Start($mc, $paths)
        while (-not $task.IsCompleted) {
            $d = [SeniorMA.Scanner]::Done
            $pct = [int](100 * $d / [Math]::Max(1, $paths.Count))
            Write-Progress -Activity 'Mod Analyzer' -Status ("$d / " + $paths.Count + ' jars') -PercentComplete $pct
            Start-Sleep -Milliseconds 150
        }
        Write-Progress -Activity 'Mod Analyzer' -Completed
        try { $task.Wait() } catch {
            Write-Host ('  Scan engine error: ' + $_.Exception.InnerException.Message) -ForegroundColor Red
        }
    }
    $sw.Stop()

    $results = @([SeniorMA.Scanner]::Results) + @($folderHits)
    $unreadable = [SeniorMA.Scanner]::Unreadable

    Write-Host ''
    Write-Host ('  ' + (($Dot + ' ') * 34)) -ForegroundColor DarkGray
    Write-Host '   R E S U L T S   (LOW -> MEDIUM -> HIGH)' -ForegroundColor White
    Write-Host ('  ' + (($Dot + ' ') * 34)) -ForegroundColor DarkGray

    $colors = @{ LOW = 'Yellow'; MEDIUM = 'DarkYellow'; HIGH = 'Red' }
    $counts = @{ LOW = 0; MEDIUM = 0; HIGH = 0 }
    foreach ($lvl in @('LOW', 'MEDIUM', 'HIGH')) {
        $items = @($results | Where-Object { $_.Level -eq $lvl } | Sort-Object Score, Name)
        $counts[$lvl] = $items.Count
        foreach ($h in $items) { Write-Finding $h $colors[$lvl] }
    }

    Write-Host ''
    Write-Host ('  ' + (($Dot + ' ') * 34)) -ForegroundColor DarkGray
    if ($results.Count -eq 0) {
        Write-Host '   No suspicious jar found. Everything looks clean.' -ForegroundColor Green
    } else {
        Write-Host '   SUMMARY  ' -NoNewline -ForegroundColor White
        Write-Host ('LOW: ' + $counts['LOW'] + '   ') -NoNewline -ForegroundColor Yellow
        Write-Host ('MEDIUM: ' + $counts['MEDIUM'] + '   ') -NoNewline -ForegroundColor DarkYellow
        Write-Host ('HIGH: ' + $counts['HIGH']) -ForegroundColor Red
        Write-Host '   LOW = weak hint, check by hand | MEDIUM = likely cheat | HIGH = confirmed client / cheat' -ForegroundColor DarkGray
    }
    Write-Host ('   Scanned ' + $paths.Count + ' jar(s) in ' + [Math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s') -ForegroundColor DarkGray
    if ($unreadable -gt 0) {
        Write-Host ('   ' + $unreadable + ' jar(s) could not be opened (corrupt / locked) - check them manually:') -ForegroundColor Yellow
        foreach ($u in @([SeniorMA.Scanner]::Failed | Select-Object -First 10)) {
            Write-Host ('     ' + $u.Replace($mc, '.minecraft')) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    Write-Host ('   Made by Senior  |  ' + $Discord) -ForegroundColor Cyan
    Write-Host ''
}

Main
