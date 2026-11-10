#!/usr/bin/env python3
"""Mide en qué se van los tokens de Claude Code, leyendo los transcripts locales.

    scripts/medir-tokens.py                         todos los proyectos
    scripts/medir-tokens.py Consorcio               proyectos cuyo nombre contiene "Consorcio"
    scripts/medir-tokens.py Consorcio --desde 2026-11-10

Cada token se pesa por su precio relativo a la entrada sin caché: lectura de
caché x0,1, escritura x1,25 (5 min) o x2 (1 h), salida x5. Así los porcentajes
son de costo, no de cantidad. Los números para comparar antes y después del
diseño de DISEÑO.md: contexto mediano por pedido, peso de los subagentes Opus,
caché rehecha y contexto inicial.
"""
import argparse, collections, datetime, glob, json, os, re

PESO = dict(inp=1, cw5=1.25, cw1h=2, cr=0.1, out=5)


def uso(u):
    cc = u.get("cache_creation") or {}
    cw1, cw5 = cc.get("ephemeral_1h_input_tokens", 0), cc.get("ephemeral_5m_input_tokens", 0)
    if not cc:
        cw5 = u.get("cache_creation_input_tokens", 0)
    return dict(inp=u.get("input_tokens", 0), cw5=cw5, cw1h=cw1, cr=u.get("cache_read_input_tokens", 0), out=u.get("output_tokens", 0))


def ts(s):
    try:
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except (ValueError, AttributeError):
        return None


def pct(lista, q):
    return lista[min(len(lista) - 1, int(len(lista) * q))] if lista else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("proyecto", nargs="?", default="", help="parte del nombre de la carpeta del proyecto")
    ap.add_argument("--desde", default="", help="AAAA-MM-DD, incluido")
    ap.add_argument("--hasta", default="9999", help="AAAA-MM-DD, incluido")
    a = ap.parse_args()

    base = os.path.expanduser("~/.claude/projects")
    raices = [d for d in glob.glob(base + "/*") if a.proyecto in os.path.basename(d)]
    vistos = set()
    tot = collections.Counter()           # peso por tipo de token
    lado = collections.Counter()          # peso por (lado, modelo)
    ctx_main, inicio, sesiones = [], [], 0
    rehecha = collections.Counter(); rehecha_n = collections.Counter()
    corridas = collections.defaultdict(lambda: [0.0, 0, 0, 0])  # peso, corridas, pedidos, ctx máx
    esfuerzo = collections.Counter()
    herr = collections.Counter(); herr_n = collections.Counter(); bash = collections.Counter()

    for raiz in raices:
        for r, _, fs in os.walk(raiz):
            for f in fs:
                if not f.endswith(".jsonl"):
                    continue
                p = os.path.join(r, f)
                sub = r != raiz
                tipo, peso_arch, n, mx, primero, t_prev = None, 0.0, 0, 0, None, None
                if sub:  # el tipo de subagente está en agent-<id>.meta.json, al lado
                    try:
                        tipo = json.load(open(p[:-6] + ".meta.json")).get("agentType")
                    except (OSError, ValueError):
                        pass
                usos = {}
                for linea in open(p, errors="ignore"):
                    try:
                        o = json.loads(linea)
                    except ValueError:
                        continue
                    dia = (o.get("timestamp") or "")[:10]
                    if dia and not (a.desde <= dia <= a.hasta):
                        continue
                    m = o.get("message") or {}
                    cont = m.get("content") if isinstance(m.get("content"), list) else []
                    if o.get("type") == "assistant":
                        for b in cont:
                            if b.get("type") == "tool_use":
                                usos[b.get("id")] = (b.get("name"), (b.get("input") or {}).get("command", ""))
                    elif o.get("type") == "user":
                        for b in cont:
                            if b.get("type") == "tool_result" and b.get("tool_use_id") in usos:
                                nombre, comando = usos.pop(b["tool_use_id"])
                                c = b.get("content")
                                largo = len(c) if isinstance(c, str) else sum(len(x.get("text", "")) for x in c or [] if isinstance(x, dict))
                                herr[nombre] += largo / 4; herr_n[nombre] += 1
                                if nombre == "Bash" and comando:
                                    cmd = re.sub(r"^(cd [^&;]+(&&|;)\s*)+", "", comando.strip())
                                    pal = [w for w in cmd.split() if not re.match(r"^[A-Z_][A-Z0-9_]*=", w)]
                                    clave = " ".join(pal[:2]) if pal and pal[0] in ("git", "cargo", "npm", "docker") else (pal[0] if pal else "")
                                    bash[clave] += largo / 4
                    if o.get("type") != "assistant":
                        continue
                    mid = m.get("id") or o.get("requestId")
                    if not mid or mid in vistos or m.get("model") == "<synthetic>":
                        continue
                    vistos.add(mid)
                    d = uso(m.get("usage") or {})
                    x = sum(d[k] * PESO[k] for k in PESO)
                    ctx = d["inp"] + d["cw5"] + d["cw1h"] + d["cr"]
                    for k in PESO:
                        tot[k] += d[k] * PESO[k]
                    modelo = re.sub(r"claude-|-\d+(-\d+)?$", "", m.get("model") or "?")
                    lado[("subagente" if sub else "principal", modelo)] += x
                    peso_arch += x; n += 1; mx = max(mx, ctx)
                    tipo = tipo or o.get("agentType") or o.get("agentName")
                    if sub:
                        continue
                    ctx_main.append(ctx)
                    esfuerzo[str(o.get("effort"))] += x
                    if primero is None:
                        primero = ctx; inicio.append(ctx); sesiones += 1
                    t = ts(o.get("timestamp") or "")
                    if t and t_prev and ctx > 100e3 and d["cr"] < ctx / 2:
                        pausa = t - t_prev
                        k = "<5 min" if pausa < 300 else ("5-60 min" if pausa < 3600 else ">1 h")
                        rehecha[k] += x; rehecha_n[k] += 1
                    t_prev = t or t_prev
                if sub and n and "/workflows/" not in p:
                    c = corridas[(tipo or "general-purpose", modelo)]
                    c[0] += peso_arch; c[1] += 1; c[2] += n; c[3] = max(c[3], mx)

    total = sum(tot.values())
    if not total:
        print("No hay pedidos en ese rango."); return
    main_w = sum(v for (l, _), v in lado.items() if l == "principal")
    f = lambda v: f"{100 * v / total:5.1f} %"
    print(f"Proyectos: {len(raices)} · sesiones: {sesiones} · peso total: {total / 1e6:.1f} M (equivalente a entrada sin caché)")
    print("\n== Quién gasta")
    for (l, mo), v in sorted(lado.items(), key=lambda kv: -kv[1]):
        print(f"   {l:10} {mo:12} {f(v)}")
    print("\n== En qué")
    for k, nombre in [("cr", "leer caché"), ("cw1h", "escribir caché 1 h"), ("cw5", "escribir caché 5 min"), ("out", "salida"), ("inp", "entrada sin caché")]:
        print(f"   {nombre:22} {f(tot[k])}")
    ctx_main.sort(); inicio.sort()
    print("\n== Contexto por pedido del hilo principal (miles de tokens)")
    print(f"   p25 {pct(ctx_main, .25) / 1e3:.0f} · mediana {pct(ctx_main, .5) / 1e3:.0f} · p75 {pct(ctx_main, .75) / 1e3:.0f} · p90 {pct(ctx_main, .9) / 1e3:.0f} · máx {ctx_main[-1] / 1e3:.0f}")
    print(f"   contexto inicial: mediana {pct(inicio, .5) / 1e3:.0f}k, mínimo {inicio[0] / 1e3:.0f}k")
    print("\n== Caché rehecha (contexto >100k, menos de la mitad leído de caché), por pausa previa")
    for k in ("<5 min", "5-60 min", ">1 h"):
        if rehecha_n[k]:
            print(f"   {k:9} {rehecha_n[k]:4} pedidos  {100 * rehecha[k] / main_w:5.1f} % del hilo principal")
    print("\n== Subagentes por tipo")
    for (tp, mo), (v, c, n, mx) in sorted(corridas.items(), key=lambda kv: -kv[1][0])[:10]:
        print(f"   {str(tp)[:24]:24} {mo:10} {c:3} corridas {f(v)}  {n / c:5.0f} pedidos/corrida  ctx máx {mx / 1e3:4.0f}k")
    print("\n== Peso del hilo principal por esfuerzo")
    print("   " + " · ".join(f"{k} {100 * v / main_w:.0f} %" for k, v in esfuerzo.most_common()))
    ht = sum(herr.values()) or 1
    print(f"\n== Salida de herramientas (≈{ht / 1e6:.2f} M tokens, estimado por caracteres)")
    for k, v in herr.most_common(6):
        print(f"   {k:18} {100 * v / ht:5.1f} %  {herr_n[k]:5} llamadas")
    print("   Bash por comando: " + " · ".join(f"{k} {100 * v / ht:.0f} %" for k, v in bash.most_common(6)))


if __name__ == "__main__":
    main()
