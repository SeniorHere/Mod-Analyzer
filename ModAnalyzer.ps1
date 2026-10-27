# MOD ANALYZER | by Senior | https://discord.gg/95MmttMD6
# Scans ONLY .minecraft\versions, \mods, \modpacks: every jar from inside (class paths, code strings, nested jars, hidden loaders).
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8; $Host.UI.RawUI.WindowTitle = 'Mod Analyzer | Senior' } catch {}
$Discord = 'https://discord.gg/95MmttMD6'; $Dot = [string][char]0x25CF
$Src = @'
using System; using System.Collections.Generic; using System.IO; using System.IO.Compression;
using System.Text; using System.Text.RegularExpressions; using System.Threading; using System.Threading.Tasks;
namespace SMA {
public class Hit { public string Rel = "", Name = "", Level = "", Client = "", Mod = ""; public long Size; public int Score; public bool Renamed; public List<string> Terms = new List<string>(); public List<string> Why = new List<string>(); }
class Matcher {
  public int[] Go; public int[][] Out;
  static int[] Row() { int[] r = new int[128]; for (int i = 0; i < 128; i++) r[i] = -1; return r; }
  public Matcher(List<string> pats) {
    List<int[]> g = new List<int[]>(); List<List<int>> o = new List<List<int>>(); g.Add(Row()); o.Add(null);
    for (int p = 0; p < pats.Count; p++) {
      int s = 0;
      foreach (char ch in pats[p]) { int c = ch & 127; if (g[s][c] < 0) { g.Add(Row()); o.Add(null); g[s][c] = g.Count - 1; } s = g[s][c]; }
      if (o[s] == null) o[s] = new List<int>(); o[s].Add(p);
    }
    int n = g.Count; int[] f = new int[n]; Queue<int> q = new Queue<int>();
    for (int c = 0; c < 128; c++) { int t = g[0][c]; if (t < 0) g[0][c] = 0; else q.Enqueue(t); }
    while (q.Count > 0) {
      int r = q.Dequeue();
      for (int c = 0; c < 128; c++) {
        int t = g[r][c];
        if (t < 0) g[r][c] = g[f[r]][c];
        else { q.Enqueue(t); f[t] = g[f[r]][c]; if (o[f[t]] != null) { if (o[t] == null) o[t] = new List<int>(); o[t].AddRange(o[f[t]]); } }
      }
    }
    Go = new int[n * 128]; Out = new int[n][];
    for (int i = 0; i < n; i++) { Array.Copy(g[i], 0, Go, i * 128, 128); Out[i] = (o[i] == null) ? null : o[i].ToArray(); }
  }
  public void Scan(byte[] b, int len, bool[] hit, bool dots) {
    int s = 0;
    for (int i = 0; i < len; i++) {
      int c = b[i];
      if (c >= 65 && c <= 90) c += 32; else if (dots && c == 46) c = 47; else if (c == 32 || c == 95 || c == 45) continue;
      if (c > 127) { s = 0; continue; }
      s = Go[(s << 7) + c]; int[] o = Out[s];
      if (o != null) for (int k = 0; k < o.Length; k++) hit[o[k]] = true;
    }
  }
}
class St { public bool[] pf, cf, tmp; public int classes, shortN, blobs; public long blobB, classB, budget = 80L << 20; public bool agent, main, pad; public string Id = "", Name = "";
  public St(int n) { pf = new bool[n]; cf = new bool[n]; tmp = new bool[n]; } }
public static class Scanner {
  public static int Done, Total, Bad; public static List<Hit> Results = new List<Hit>(); public static List<string> Failed = new List<string>();
  static readonly object G = new object(); const int MaxB = 1048576; [ThreadStatic] static byte[] tb;
  // clients: Name|file-key|tokens   (tokens are matched without spaces, '-' or '_')
  const string CL = "Meteor Client|meteor|meteordevelopment/meteorclient,minegame159/meteorclient,meteorclient;Wurst Client|wurst|net/wurstclient,wurstclient,wurstimperium;BleachHack|bleach|org/bleachhack,bleachhack;Sigma|sigma|info/sigmaclient,sigmaclient;Impact|impact|impactclient;Vape|vape|vape.gg,vapelite,vapev4,vapeclient;Jigsaw|jigsaw|jigsawclient;LiquidBounce|liquidbounce|net/ccbluex,liquidbounce;FDPClient|fdp|fdpclient,unlegitmc;Raven B+|raven|ravenbplus,ravenb+,ravenb4,ravenbs;Ares|ares|aresclient;Hydra|hydra|hydraclient;Xulu|xulu|xuluclient;Flux|flux|fluxclient;Perish|perish|perishclient;Jex|jex|jexclient;Frost|frost|frostclient;Itami|itami|itamiclient;Polar|polar|polarclient;Curse|curse|curseclient;Dopium|dopium|dopium;Future|future|net/futureclient,futureclient;RusherHack|rusher|org/rusherhack,rusherhack;Aristois|aristois|aristois;SalHack|salhack|salhack;KAMI Blue|kami|org/kamiblue,kamiblue;Lambda|lambda|com/lambda/client,lambdaclient;ForgeHax|forgehax|forgehax;Konas|konas|konasclient;Phobos|phobos|me/earth/phobos;3arthh4ck|earth|earthhack,3arthh4ck;GameSense|gamesense|gamesense;Seppuku|seppuku|rigamortis;Huzuni|huzuni|huzuni;Inertia|inertia|inertiaclient;Mathax|mathax|mathax;ThunderHack|thunder|thunderhack;Novoline|novoline|novoline;Rise|rise|riseclient;Tenacity|tenacity|dev/tenacity,tenacityclient;Remix|remix|remixclient;Moon Client|moon|moonclient;Drip|drip|dripclient;Entropy|entropy|entropyclient;Nodus|nodus|nodusclient;Doomsday|doomsday|doomsdayclient;Argon|argon|argonclient;Prestige|prestige|prestigeclient;Krypton Client|krypton|kryptonclient;Aoba|aoba|net/aoba,aobaclient;Coffee|coffee|coffeeclient;Wolfram|wolfram|wolframclient";
  const string STRONG = "KillAura,AutoCrystal,CrystalAura,TriggerBot,AutoTotem,AimAssist,AimBot,AnchorAura,AutoAnchor,AutoHitCrystal,AutoDoubleHand,AutoDTap,AutoPot,AutoClicker,SilentAim,TpAura,MultiAura,ClickAura,ShieldBreaker,AutoShieldBreak,AntiKnockback,AutoInvTotem,TotemBot,CrystalOptimizer,AutoWTap,HitSelect,JitterClick,ClickMacro,CrystalMacro,AnchorMacro,TotemMacro,ChestESP,PlayerESP,StorageESP,BlockESP,ElytraFly,BoatFly,PacketFly,CreativeFly,FlyHack,ReachHack,ScaffoldWalk,BedAura,HoleESP,HoleFill,FakeLag";
  const string WEAK = "NoFall,NoSlow,AntiBot,FastPlace,FastBreak,AutoSprint,Tracers,HitBoxes,AntiKB,SafeWalk,LongJump,HighJump,BunnyHop,AutoWalk,InvMove,InventoryWalk,AutoTool,Nuker,EntityESP";
  const string STRUCT = "modules/combat,module/combat,hacks/combat;modules/movement,module/movement,hacks/movement;modules/render,module/render,hacks/render;modules/exploit,module/exploit,hacks/exploit;modules/player,module/player,hacks/player";
  const string ADV = "Freecam|net/xolt/freecam,freecam;XRay|/xray/,xraymod,net/xray;Fullbright|fullbright;Baritone|cabaletta/baritone,baritone/api";
  const string FAM = "net/fabricmc/api/modinitializer,net/fabricmc/api/clientmodinitializer;net/minecraftforge/fml/common/mod;cpw/mods/fml/common/mod;net/labymod/api;net/neoforged/fml/common/mod";
  const string BEH = "defineclass|2|custom class loader (defineClass);com/sun/jna/|1|native code through JNA;java/lang/instrument/instrumentation|2|java agent / instrumentation API;java/nio/channels/socketchannel|1|raw network socket";
  const string ANTI = "grimac,nocheatplus,anticheat,cheatbreaker";
  const string ALLOW = "fabric-api,fabricloader,fabric-language-kotlin,sodium,lithium,phosphor,iris,indium,starlight,ferritecore,modmenu,optifine,optifabric,jei,rei,roughlyenoughitems,emi,journeymap,xaerominimap,xaeroworldmap,voxelmap,litematica,malilib,tweakeroo,minihud,itemscroller,replaymod,cloth-config,cloth-config2,architectury,appleskin,lambdynlights,create,essential,canvas,entityculling,immediatelyfast,dynamic-fps,betterf3,yacl,yet_another_config_lib_v3,jade,wthit,mouse-tweaks,inventory-profiles-next,controlling,configured,forge,neoforge,minecraft,mixinextras,noisium,moreculling,badoptimizations,c2me,krypton,viafabric,viafabricplus,viaversion,fancymenu,konkrete";
  const string SKIP = "net/minecraft/,com/mojang/,net/minecraftforge/,net/neoforged/,net/fabricmc/,org/spongepowered/,kotlin/,kotlinx/,org/apache/,com/google/,io/netty/,org/objectweb/,it/unimi/,javax/,org/lwjgl/,org/joml/,org/slf4j/,org/jetbrains/,org/yaml/,org/json/,org/quiltmc/,org/antlr/,org/bouncycastle/";
  static List<string> P = new List<string>(); static List<int> K = new List<int>(), O = new List<int>();
  static string[][] Cl, Be, Ad; static string[] Strong, Skip; static HashSet<string> Allow; static Matcher M;
  static string N(string s) { return s.ToLowerInvariant().Replace(" ", "").Replace("-", "").Replace("_", ""); }
  static void Add(string t, int k, int o) { P.Add(N(t)); K.Add(k); O.Add(o); }
  static void AddAll(string list, int k, int o) { foreach (string t in list.Split(',')) Add(t, k, o); }
  static string[][] Groups(string s) { string[] g = s.Split(';'); string[][] r = new string[g.Length][]; for (int i = 0; i < g.Length; i++) r[i] = g[i].Split('|'); return r; }
  static Scanner() {
    Cl = Groups(CL); for (int i = 0; i < Cl.Length; i++) AddAll(Cl[i][2], 0, i);
    Strong = STRONG.Split(','); for (int i = 0; i < Strong.Length; i++) Add(Strong[i], 1, i);
    string[] w = WEAK.Split(','); for (int i = 0; i < w.Length; i++) Add(w[i], 2, i); AddAll(ANTI, 4, 0);
    string[] st = STRUCT.Split(';'); for (int i = 0; i < st.Length; i++) AddAll(st[i], 3, i);
    string[] fm = FAM.Split(';'); for (int i = 0; i < fm.Length; i++) AddAll(fm[i], 5, i);
    Be = Groups(BEH); for (int i = 0; i < Be.Length; i++) Add(Be[i][0], 6, i);
    Ad = Groups(ADV); for (int i = 0; i < Ad.Length; i++) AddAll(Ad[i][1], 7, i);
    Allow = new HashSet<string>(ALLOW.Split(',')); Skip = SKIP.Split(',');
    M = new Matcher(P);
  }
  public static Task Start(string root, string[] files) {
    Done = 0; Total = files.Length; Bad = 0; Results = new List<Hit>(); Failed = new List<string>();
    Action a = delegate {
      ParallelOptions po = new ParallelOptions(); po.MaxDegreeOfParallelism = Math.Max(1, Math.Min(4, Environment.ProcessorCount - 1));
      Parallel.ForEach(files, po, delegate (string f) {
        try { ScanJar(root, f); } catch (Exception) { lock (G) { Bad++; Failed.Add(f); } }
        Interlocked.Increment(ref Done);
      });
    };
    return Task.Factory.StartNew(a, TaskCreationOptions.LongRunning);
  }
  static int Read(ZipArchiveEntry e, byte[] buf, int max) {
    int total = 0, lim = Math.Min(max, buf.Length);
    try { using (Stream s = e.Open()) { int n; while (total < lim && (n = s.Read(buf, total, lim - total)) > 0) total += n; } } catch (Exception) { } return total;
  }
  static string Rx(string t, string pat) {
    Match m = Regex.Match(t, pat, RegexOptions.IgnoreCase);
    for (int i = 1; m.Success && i < m.Groups.Count; i++) if (m.Groups[i].Success) return m.Groups[i].Value.Trim();
    return "";
  }
  static double Entropy(byte[] b, int n) {
    if (n <= 0) return 0; int[] c = new int[256]; for (int i = 0; i < n; i++) c[b[i]]++;
    double e = 0; for (int i = 0; i < 256; i++) if (c[i] > 0) { double pr = (double)c[i] / n; e -= pr * Math.Log(pr, 2); } return e;
  }
  static void Walk(ZipArchive za, int depth, St s, byte[] buf) {
    foreach (ZipArchiveEntry e in za.Entries) {
      string low = e.FullName.ToLowerInvariant(); byte[] nb = Encoding.UTF8.GetBytes(low); M.Scan(nb, nb.Length, s.pf, false);
      if (low.EndsWith(".class")) {
        s.classes++; s.classB += e.Length; if (low.Substring(low.LastIndexOf('/') + 1).Length <= 8) s.shortN++;
        bool skip = false; foreach (string sp in Skip) if (low.StartsWith(sp, StringComparison.Ordinal)) { skip = true; break; }
        if (!skip && s.budget > 0) { int n = Read(e, buf, MaxB); s.budget -= n; M.Scan(buf, n, s.cf, false); }
      } else if (low.EndsWith(".jar") && depth < 2 && e.Length < (40 << 20)) {
        try { using (Stream st = e.Open()) { MemoryStream ms = new MemoryStream(); st.CopyTo(ms); ms.Position = 0; using (ZipArchive z2 = new ZipArchive(ms)) Walk(z2, depth + 1, s, buf); } } catch (Exception) { }
      } else if (low == "meta-inf/manifest.mf") {
        int n = Read(e, buf, 65536); string mt = Encoding.UTF8.GetString(buf, 0, n).ToLowerInvariant();
        if (mt.IndexOf("premain-class") >= 0 || mt.IndexOf("agent-class") >= 0 || mt.IndexOf("can-retransform-classes: true") >= 0) s.agent = true;
        if (Regex.IsMatch(mt, "(^|\\n)main-class:")) s.main = true;
      } else if (e.Length <= 262144 && Regex.IsMatch(low, "\\.(json|toml|info|yml|txt|cfg|properties)$")) {
        int n = Read(e, buf, 262144); Array.Clear(s.tmp, 0, s.tmp.Length); M.Scan(buf, n, s.tmp, true);
        for (int p = 0; p < s.tmp.Length; p++) if (s.tmp[p]) { if (K[p] == 0) s.pf[p] = true; else s.cf[p] = true; }
      } else if (!low.EndsWith("/") && e.Length >= 8192 && low.Substring(low.LastIndexOf('/') + 1).IndexOf('.') < 0) {
        int n = Read(e, buf, 65536); double en = Entropy(buf, n);
        if (en >= 7.5) { s.blobs++; s.blobB += e.Length; } else if (e.Length >= 524288 && en < 0.5) s.pad = true;
      }
    }
  }
  static void ScanJar(string root, string file) {
    FileInfo fi = new FileInfo(file); if (tb == null) tb = new byte[MaxB]; byte[] buf = tb; St s = new St(P.Count);
    using (FileStream fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
    using (ZipArchive za = new ZipArchive(fs, ZipArchiveMode.Read)) {
      ZipArchiveEntry me = za.GetEntry("fabric.mod.json") ?? za.GetEntry("META-INF/mods.toml") ?? za.GetEntry("META-INF/neoforge.mods.toml") ?? za.GetEntry("mcmod.info") ?? za.GetEntry("quilt.mod.json");
      if (me != null) {
        string t = Encoding.UTF8.GetString(buf, 0, Read(me, buf, 65536));
        s.Id = Rx(t, "\"id\"\\s*:\\s*\"([^\"]+)\"|modId\\s*=\\s*\"([^\"]+)\"|\"modid\"\\s*:\\s*\"([^\"]+)\"");
        s.Name = Rx(t, "\"name\"\\s*:\\s*\"([^\"]*)\"|displayName\\s*=\\s*\"([^\"]*)\"");
      }
      if (s.Id != "" && Allow.Contains(s.Id.ToLowerInvariant())) return;
      Walk(za, 0, s, buf);
    }
    if (s.classes == 0) return;
    int[] cp = new int[Cl.Length], cc = new int[Cl.Length], sp = new int[Strong.Length];
    bool[] stc = new bool[8], fam = new bool[8], beh = new bool[8], adv = new bool[8]; bool anti = false; int wk = 0;
    for (int p = 0; p < P.Count; p++) {
      int k = K[p], o = O[p]; bool a = s.pf[p], b = s.cf[p];
      if (k == 0) { if (a) cp[o]++; if (b) cc[o]++; }
      else if (k == 1) { if (a) sp[o] = 2; else if (b && sp[o] == 0) sp[o] = 1; }
      else if (k == 2) { if (a || b) wk++; }
      else if (k == 3) { if (a) stc[o] = true; }
      else if (k == 4) { if (a || b) anti = true; }
      else if (k == 5) { if (a || b) fam[o] = true; }
      else if (k == 6) { if (b) beh[o] = true; }
      else if (k == 7) { if (a) adv[o] = true; }
    }
    Hit h = new Hit(); h.Name = fi.Name; h.Size = fi.Length; h.Rel = file.StartsWith(root, StringComparison.OrdinalIgnoreCase) ? file.Substring(root.Length).TrimStart('\\', '/') : file;
    h.Mod = s.Name + ((s.Id != "" && s.Id != s.Name) ? " (" + s.Id + ")" : "");
    int sc = 0, best = -1, bs = 0;
    for (int c = 0; c < Cl.Length; c++) { int v = Math.Min(cp[c], 1) * 10 + Math.Min(cc[c], 2) * 4; if (v > bs) { bs = v; best = c; } }
    bool cpath = best >= 0 && cp[best] > 0;
    if (best >= 0) { sc += bs; h.Client = Cl[best][0]; h.Why.Add(cpath ? "Known client package / ID found inside the jar" : "Client name found inside the code"); }
    // hidden / packed loader (works even when no readable strings exist)
    int pk = 0; List<string> pw = new List<string>(); int fc = 0; foreach (bool x in fam) if (x) fc++;
    if (s.agent) { pk += 6; pw.Add("Java agent in manifest (Premain-Class) - normal mods never have this"); }
    if (fc >= 3) { pk += 4; pw.Add("Fake multi-loader stub: Fabric + Forge + legacy Forge/LabyMod entry points in ONE jar"); }
    if (s.blobs >= 2 && s.blobB >= 102400) { pk += 4; pw.Add(s.blobs + " encrypted files with no extension (" + (s.blobB / 1024) + " KB) - hidden payload"); }
    if (s.pad) { pk += 2; pw.Add("Huge empty padding file"); } if (s.classes <= 25 && s.blobB > 0 && s.blobB > s.classB * 5) { pk += 2; pw.Add("Tiny loader classes + big encrypted payload"); }
    if (pk > 0) {
      if (s.main) { pk += 1; pw.Add("Mod jar has a Main-Class"); }
      if (s.Id.Length > 0 && s.Id.Length <= 2) { pk += 1; pw.Add("Meaningless mod id '" + s.Id + "'"); }
      for (int i = 0; i < Be.Length; i++) if (beh[i]) { pk += int.Parse(Be[i][1]); pw.Add("Uses " + Be[i][2]); }
      sc += pk; h.Why.AddRange(pw); if (pk >= 6 && h.Client == "") h.Client = "Packed / hidden loader (unknown cheat)";
    }
    int sP = 0, sC = 0;
    for (int t = 0; t < Strong.Length; t++) {
      if (sp[t] == 2) { sc += 4; sP++; h.Terms.Add(Strong[t]); }
      else if (sp[t] == 1) { sc += 2; sC++; if (h.Terms.Count < 12) h.Terms.Add(Strong[t]); }
    }
    if (sP > 0) h.Why.Add(sP + " class/file name(s) match known cheat modules"); if (sC > 0) h.Why.Add(sC + " cheat-module string(s) found inside the code");
    if (wk >= 4) { sc += Math.Min(wk, 8); h.Why.Add(wk + " different generic cheat-module names (NoFall, NoSlow, AntiBot...) in one jar"); }
    if (stc[0] && (stc[1] || stc[2] || stc[3] || stc[4])) { sc += 4; h.Why.Add("Cheat-client folder layout (modules/combat + movement/render...)"); }
    List<string> ah = new List<string>(); for (int g = 0; g < Ad.Length; g++) if (adv[g]) ah.Add(Ad[g][0]);
    if (ah.Count > 0) {
      sc += 6; h.Why.Add("Advantage mod: " + string.Join(", ", ah.ToArray()) + " - not allowed on most servers");
      if (h.Client == "") h.Client = ah[0] + " (advantage mod)"; h.Terms.AddRange(ah);
    }
    if (sc > 0 && s.classes >= 30 && s.shortN * 2 >= s.classes) { sc++; h.Why.Add("Heavily obfuscated (most class names are 1-2 letters)"); }
    string lv = sc >= 9 ? "HIGH" : sc >= 6 ? "MEDIUM" : sc >= 4 ? "LOW" : ""; if (lv == "") return;
    if (anti && !cpath && lv != "LOW") { lv = "LOW"; h.Why.Add("Anti-cheat / legit marker present - level reduced"); }
    if (best >= 0 && (cpath || sc >= 9) && fi.Name.ToLowerInvariant().IndexOf(Cl[best][1]) < 0) { h.Renamed = true; h.Why.Add("FILE NAME DOES NOT MATCH the client inside (renamed jar)"); }
    h.Level = lv; h.Score = sc; lock (G) { Results.Add(h); }
  }
}
}
'@
function Show-Banner {
    $g = @{ S='01110,10000,01110,00001,11110'; E='11111,10000,11110,10000,11111'; N='10001,11001,10101,10011,10001'
            I='11111,00100,00100,00100,11111'; O='01110,10001,10001,10001,01110'; R='11110,10001,11110,10010,10001' }
    $w = 'SENIOR'; $col = 'Cyan','Cyan','Magenta','Magenta','Cyan','Cyan'; $sep = '      ' + (($Dot + ' ') * 34)
    Write-Host ''
    for ($r = 0; $r -lt 5; $r++) {
        Write-Host '      ' -NoNewline
        for ($i = 0; $i -lt 6; $i++) {
            $row = ($g[[string]$w[$i]] -split ',')[$r]
            $txt = ''; foreach ($ch in $row.ToCharArray()) { if ($ch -eq '1') { $txt += "$Dot " } else { $txt += '  ' } }
            Write-Host ($txt + '  ') -NoNewline -ForegroundColor $col[$i]
        }
        Write-Host ''
    }
    Write-Host "`n$sep" -ForegroundColor DarkGray
    Write-Host '        M O D   A N A L Y Z E R' -ForegroundColor White
    Write-Host "        Discord academy : $Discord" -ForegroundColor DarkCyan
    Write-Host "$sep`n" -ForegroundColor DarkGray
}
function Write-Finding($h, $color) {
    Write-Host ''
    Write-Host '  ' -NoNewline; Write-Host " $($h.Level) " -NoNewline -ForegroundColor Black -BackgroundColor $color
    Write-Host "  $($h.Name)" -NoNewline -ForegroundColor White; Write-Host "   [$(($h.Rel -split '[\\/]')[0])]" -ForegroundColor DarkGray
    if ($h.Mod) { Write-Host '     Mod      : ' -NoNewline -ForegroundColor DarkGray; Write-Host $h.Mod -ForegroundColor Gray }
    if ($h.Client) {
        Write-Host '     Client   : ' -NoNewline -ForegroundColor DarkGray; Write-Host $h.Client -NoNewline -ForegroundColor Red
        if ($h.Renamed) { Write-Host '   <-- RENAMED FILE' -NoNewline -ForegroundColor Red }
        Write-Host ''
    }
    if (@($h.Terms).Count -gt 0) {
        Write-Host '     Strings  : ' -NoNewline -ForegroundColor DarkGray; foreach ($t in $h.Terms) { Write-Host "$t  " -NoNewline -ForegroundColor Red }; Write-Host ''
    }
    foreach ($w in $h.Why) { Write-Host '     Why      : ' -NoNewline -ForegroundColor DarkGray; Write-Host $w -ForegroundColor Gray }
    Write-Host '     Path     : ' -NoNewline -ForegroundColor DarkGray; Write-Host $h.Rel -ForegroundColor DarkGray
    $k = "$($h.Name)|$($h.Size)"
    if ($script:Dups[$k] -gt 0) { Write-Host "     Copies   : +$($script:Dups[$k]) identical copy(ies) in other folders" -ForegroundColor DarkGray }
}
function Main {
    Show-Banner
    try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch {}
    if (-not ('SMA.Scanner' -as [type])) {
        $ok = $false
        foreach ($refs in @(@('System.IO.Compression', 'System.IO.Compression.FileSystem'), @())) {
            try { if ($refs.Count) { Add-Type -TypeDefinition $Src -ReferencedAssemblies $refs -ErrorAction Stop } else { Add-Type -TypeDefinition $Src -ErrorAction Stop }; $ok = $true; break }
            catch { $err = $_.Exception.Message }
        }
        if (-not $ok) { Write-Host "  Could not start the scan engine: $err" -ForegroundColor Red; return }
    }
    $mc = Join-Path $env:APPDATA '.minecraft'
    if (-not (Test-Path -LiteralPath $mc)) {
        $mc = (Read-Host '  .minecraft not found. Paste its full path').Trim('"', ' ')
        if (-not (Test-Path -LiteralPath $mc)) { Write-Host '  Path not found.' -ForegroundColor Red; return }
    }
    $mc = $mc.TrimEnd('\', '/'); $script:Dups = @{}; $unique = @{}; $folderHits = @()
    Write-Host '  Collecting jars (versions / mods / modpacks only)...' -ForegroundColor Cyan
    foreach ($s in 'versions', 'mods', 'modpacks') {
        $p = Join-Path $mc $s
        if (-not (Test-Path -LiteralPath $p)) { Write-Host "    $Dot $($s.PadRight(9)) not found" -ForegroundColor DarkGray; continue }
        $files = @(Get-ChildItem -LiteralPath $p -Filter '*.jar*' -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.jar(\.disabled)?$' -and $_.Length -gt 100 })
        Write-Host "    $Dot $($s.PadRight(9)) $($files.Count) jar(s)" -ForegroundColor Gray
        foreach ($f in $files) {
            $k = "$($f.Name)|$($f.Length)"
            if ($unique.ContainsKey($k)) { $script:Dups[$k]++ } else { $unique[$k] = $f.FullName }
        }
    }
    $rx = '(?i)meteor|wurst|bleachhack|liquidbounce|vape|fdpclient|rusherhack|aristois|impact|sigma|jigsaw|novoline|tenacity|kamiblue|salhack|forgehax|huzuni|aoba|dopium|ravenb|xulu|itami|hydra'
    foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $mc 'versions') -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -match $rx) {
            $folderHits += [pscustomobject]@{ Level = 'LOW'; Name = $d.Name; Rel = "versions\$($d.Name)"; Size = 0; Score = 4; Mod = ''; Client = $Matches[0]; Renamed = $false; Terms = @(); Why = @('Version folder name looks like a cheat client (check by hand)') }
        }
    }
    $paths = [string[]]@($unique.Values)
    Write-Host "`n  Analyzing $($paths.Count) unique jar(s)..." -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($paths.Count -gt 0) {
        $task = [SMA.Scanner]::Start($mc, $paths)
        while (-not $task.IsCompleted) {
            $d = [SMA.Scanner]::Done
            Write-Progress -Activity 'Mod Analyzer' -Status "$d / $($paths.Count) jars" -PercentComplete ([int](100 * $d / $paths.Count))
            Start-Sleep -Milliseconds 150
        }
        Write-Progress -Activity 'Mod Analyzer' -Completed
        try { $task.Wait() } catch { Write-Host "  Scan engine error: $($_.Exception.InnerException.Message)" -ForegroundColor Red }
    }
    $sw.Stop()
    $results = @([SMA.Scanner]::Results) + $folderHits
    $line = '  ' + (($Dot + ' ') * 34)
    Write-Host "`n$line`n   R E S U L T S   (LOW -> MEDIUM -> HIGH)`n$line" -ForegroundColor DarkGray
    $colors = @{ LOW = 'Yellow'; MEDIUM = 'DarkYellow'; HIGH = 'Red' }; $n = @{ LOW = 0; MEDIUM = 0; HIGH = 0 }
    foreach ($lvl in 'LOW', 'MEDIUM', 'HIGH') {
        $items = @($results | Where-Object { $_.Level -eq $lvl } | Sort-Object Score, Name); $n[$lvl] = $items.Count
        foreach ($h in $items) { Write-Finding $h $colors[$lvl] }
    }
    Write-Host "`n$line" -ForegroundColor DarkGray
    if ($results.Count -eq 0) { Write-Host '   No suspicious jar found. Everything looks clean.' -ForegroundColor Green }
    else {
        Write-Host '   SUMMARY  ' -NoNewline -ForegroundColor White
        Write-Host "LOW: $($n.LOW)   " -NoNewline -ForegroundColor Yellow; Write-Host "MEDIUM: $($n.MEDIUM)   " -NoNewline -ForegroundColor DarkYellow; Write-Host "HIGH: $($n.HIGH)" -ForegroundColor Red
        Write-Host '   LOW = weak hint, check by hand | MEDIUM = likely cheat / advantage mod | HIGH = confirmed' -ForegroundColor DarkGray
    }
    Write-Host "   Scanned $($paths.Count) jar(s) in $([Math]::Round($sw.Elapsed.TotalSeconds, 1)) s" -ForegroundColor DarkGray
    if ([SMA.Scanner]::Bad -gt 0) {
        Write-Host "   $([SMA.Scanner]::Bad) jar(s) could not be opened (corrupt / locked) - check by hand:" -ForegroundColor Yellow
        foreach ($u in @([SMA.Scanner]::Failed | Select-Object -First 10)) { Write-Host "     $($u.Replace($mc, '.minecraft'))" -ForegroundColor DarkGray }
    }
    Write-Host "`n   Made by Senior  |  $Discord`n" -ForegroundColor Cyan
}
Main
