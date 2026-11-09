#!/usr/bin/env python3
"""Kit de démo « Studio Garance » : charge un jeu de données fictif dans les apps de la suite, ou le retire.

    sudo ./demo/charger.sh                  charge tout (Convert, Tab, Viz, Trésorerie, Projets, Wiki, Nexus)
    sudo ./demo/charger.sh etat             ce qui est chargé
    sudo ./demo/charger.sh retirer          retire tout ce que le kit a créé, et seulement cela
    sudo ./demo/charger.sh charger --apps viz,projets    une partie seulement

Python 3 de la bibliothèque standard, rien à installer. Les apps sont jointes en 127.0.0.1 sur leurs ports du VPS,
comme le font Nexus et Viz ; Tab est écrit dans data/atelier_tab/ (fichiers du serveur MCP de Tab).

Chaque objet créé est noté dans data/demo/studio-garance.json : « retirer » ne supprime que ce qui y figure.
Un objet qui existait avant (catégorie de Trésorerie du même nom, budget déjà posé…) est réutilisé ou laissé tel quel,
jamais modifié ni supprimé.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import secrets
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEMO = Path(__file__).resolve().parent
ROOT = DEMO.parent
DONNEES = DEMO / "donnees"

APPS = ["convert", "tab", "viz", "tresorerie", "projets", "wiki", "nexus"]
URLS = {
    "convert": "http://127.0.0.1:8010/api",
    "viz": "http://127.0.0.1:8000/api",
    "tresorerie": "http://127.0.0.1:5050/api",
    "projets": "http://127.0.0.1:3000/api",
    "wiki": "http://127.0.0.1:3200/api",
    "nexus": "http://127.0.0.1:8100/api",
}

# Identifiants fixes du kit dans Atelier Tab (format `atelier_tab` : lettres, chiffres, « _ »).
TAB_WORKSPACE = "ws_demogarance"
TAB_PROJECT = "prj_demogarance"

AUTEUR = "Kit de démo"

bold, dim, red, green, yellow, reset = ("\033[1m", "\033[2m", "\033[31m", "\033[32m", "\033[33m", "\033[0m") \
    if sys.stdout.isatty() else ("",) * 6


def step(msg: str) -> None:
    print(f"\n{bold}▸ {msg}{reset}")


def ok(msg: str) -> None:
    print(f"  {green}✓{reset} {msg}")


def warn(msg: str) -> None:
    print(f"  {yellow}!{reset} {msg}")


def info(msg: str) -> None:
    print(f"  {dim}{msg}{reset}")


class KitError(Exception):
    pass


# ─── HTTP ────────────────────────────────────────────────────────────────────────────────────────


class Api:
    def __init__(self, app: str, base: str, headers: dict[str, str] | None = None) -> None:
        self.app, self.base, self.headers = app, base.rstrip("/"), headers or {}

    def call(self, method: str, path: str, body: Any = None, *, raw: bytes | None = None,
             content_type: str | None = None, ok404: bool = False, timeout: float = 60) -> Any:
        headers = dict(self.headers)
        data = raw
        if body is not None:
            data = json.dumps(body, ensure_ascii=False).encode()
            headers["Content-Type"] = "application/json"
        elif content_type:
            headers["Content-Type"] = content_type
        req = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as res:
                text = res.read().decode() or "null"
                return json.loads(text) if text.strip()[:1] in "[{\"n0123456789-tf" else text
        except urllib.error.HTTPError as exc:
            if ok404 and exc.code == 404:
                return None
            detail = exc.read().decode(errors="replace")[:400]
            raise KitError(f"{self.app} : {method} {path} → {exc.code} {detail}") from exc
        except urllib.error.URLError as exc:
            raise KitError(f"{self.app} injoignable ({self.base}) : {exc.reason}") from exc

    def get(self, path: str, **kw: Any) -> Any:
        return self.call("GET", path, **kw)

    def post(self, path: str, body: Any = None, **kw: Any) -> Any:
        return self.call("POST", path, body if body is not None else ({} if "raw" not in kw else None), **kw)

    def put(self, path: str, body: Any) -> Any:
        return self.call("PUT", path, body)

    def patch(self, path: str, body: Any) -> Any:
        return self.call("PATCH", path, body)

    def delete(self, path: str) -> Any:
        return self.call("DELETE", path, ok404=True)

    def upload(self, path: str, fields: dict[str, str], file_field: str, file: Path, mime: str) -> Any:
        boundary = "----atelier-demo-" + uuid.uuid4().hex
        parts: list[bytes] = []
        for name, value in fields.items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{file.name}"\r\n'
            f"Content-Type: {mime}\r\n\r\n".encode() + file.read_bytes() + b"\r\n"
        )
        parts.append(f"--{boundary}--\r\n".encode())
        return self.call("POST", path, raw=b"".join(parts), content_type=f"multipart/form-data; boundary={boundary}")


# ─── État ───────────────────────────────────────────────────────────────────────────────────────


class State:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data: dict[str, Any] = json.loads(path.read_text()) if path.exists() else {}

    def app(self, name: str) -> dict[str, Any] | None:
        return self.data.get(name)

    def set(self, name: str, value: dict[str, Any]) -> None:
        value["charge_le"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
        self.data[name] = value
        self.save()

    def drop(self, name: str) -> None:
        self.data.pop(name, None)
        self.save()

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if self.data:
            write_json(self.path, self.data)
        elif self.path.exists():
            self.path.unlink()


def write_json(path: Path, data: Any) -> None:
    """Écriture atomique (fichier caché temporaire puis renommage), comme Tab et Convert."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def items(x: Any) -> list:
    """Liste renvoyée telle quelle ou sous la clé « items »."""
    return x["items"] if isinstance(x, dict) and "items" in x else (x or [])


def euros(v: float) -> str:
    whole, dec = f"{abs(v):,.2f}".split(".")
    return ("−" if v < 0 else "") + whole.replace(",", " ") + "," + dec + " €"


# ─── Le jeu de données ──────────────────────────────────────────────────────────────────────────


class Jeu:
    def __init__(self) -> None:
        self.d = json.loads((DONNEES / "studio-garance.json").read_text(encoding="utf-8"))
        self.releves: list[dict] = self.d["releves"]
        self.ops = [dict(o, mois=r["mois"]) for r in self.releves for o in r["operations"]]
        self.csv = DONNEES / f"operations_{self.releves[0]['mois']}_{self.releves[-1]['mois']}.csv"
        self.dernier = self.releves[-1]

    def total(self, mois: str, champ: str, categorie: str | None = None) -> float:
        return round(sum(o[champ] for o in self.ops if o["mois"] == mois and (categorie is None or o["categorie"] == categorie)), 2)

    def categorie(self, date: str, libelle: str, montant: float) -> str | None:
        for o in self.ops:
            if o["date"] == date and o["libelle"] == libelle and abs((o["credit"] - o["debit"]) - montant) < 0.005:
                return o["categorie"]
        return None


# ─── Convert ────────────────────────────────────────────────────────────────────────────────────


def charger_convert(api: Api, jeu: Jeu, state: State) -> None:
    ids = []
    for i, r in enumerate(jeu.releves):
        if i:
            time.sleep(1.1)  # Convert classe son historique à la seconde : octobre doit rester le plus récent
        conv = api.upload("/conversions", {}, "file", DONNEES / r["fichier"], "application/pdf")
        st = conv.get("statement") or {}
        name = f"Relevé {r['libelle']} — {jeu.d['nom']} {jeu.d['marque']}"
        api.put(f"/conversions/{conv['id']}/name", {"name": name})
        ids.append({"id": conv["id"], "mois": r["mois"]})
        check = st.get("balance_check")
        msg = f"{name} : {conv['rows']} opérations, soldes {'justes' if check == 'ok' else check}"
        (ok if check == "ok" else warn)(msg)
    state.set("convert", {"conversions": ids})


def retirer_convert(api: Api, s: dict) -> None:
    for c in s.get("conversions", []):
        api.delete(f"/conversions/{c['id']}")
    ok(f"{len(s.get('conversions', []))} conversion(s) supprimée(s)")


# ─── Tab (fichiers du serveur MCP) ───────────────────────────────────────────────────────────────


def tab_id(prefix: str) -> str:
    return f"{prefix}_" + "".join(secrets.choice("0123456789abcdefghijklmnopqrstuvwxyz") for _ in range(10))


def charger_tab(tab_dir: Path, jeu: Jeu, state: State, convert_api: Api | None) -> None:
    index_path = tab_dir / "atelier.json"
    created_index = not index_path.exists()
    if created_index:
        index: dict[str, Any] = {"format": "atelier_tab", "version": 1, "workspaceOrder": [], "workspaces": {},
                                 "projects": {}, "collaborators": {}, "integrations": {"atelierProjets": {}}}
        info("atelier.json absent : création du dossier d'Atelier Tab (le serveur MCP de Tab devient utilisable)")
    else:
        index = json.loads(index_path.read_text(encoding="utf-8"))
        backup = tab_dir / f"atelier.json.avant-demo-{time.strftime('%Y%m%d-%H%M%S')}"
        backup.write_text(index_path.read_text(encoding="utf-8"), encoding="utf-8")
        info(f"Copie de sécurité : {backup.name}")
    index.setdefault("workspaces", {}).setdefault(TAB_WORKSPACE, {"id": TAB_WORKSPACE, "name": jeu.d["tab"]["espace"], "projectIds": []})
    if TAB_WORKSPACE not in index.setdefault("workspaceOrder", []):
        index["workspaceOrder"].append(TAB_WORKSPACE)
    ws = index["workspaces"][TAB_WORKSPACE]
    if TAB_PROJECT not in ws["projectIds"]:
        ws["projectIds"].append(TAB_PROJECT)
    index.setdefault("projects", {}).setdefault(TAB_PROJECT, {"id": TAB_PROJECT, "workspaceId": TAB_WORKSPACE,
                                                              "name": jeu.d["tab"]["projet"], "tableIds": []})
    write_json(index_path, index)
    (tab_dir / "tables").mkdir(exist_ok=True)

    convs = {c["mois"]: c["id"] for c in (state.app("convert") or {}).get("conversions", [])}
    tables = []
    for i, r in enumerate(jeu.releves):
        name = f"Relevé {r['libelle']}"
        if convert_api and r["mois"] in convs:
            if i:
                time.sleep(1.1)  # même raison : l'envoi met à jour la conversion, octobre en dernier
            res = convert_api.post(f"/conversions/{convs[r['mois']]}/send-to-tab",
                                   {"project_id": TAB_PROJECT, "table_name": name})
            table_id, via = res["table_id"], "envoyée par Convert"
        else:
            table_id, via = ecrire_table_tab(tab_dir, r, name), "écrite directement (Convert non chargé)"
        n = ajouter_categories(tab_dir / "tables" / f"{table_id}.json", jeu)
        tables.append(table_id)
        ok(f"Table « {name} » {via}, colonne Catégorie ajoutée ({n} lignes)")
    # Les tables sont aussi déclarées dans leur projet (Tab les rattache de toute façon).
    index = json.loads(index_path.read_text(encoding="utf-8"))
    proj = index["projects"][TAB_PROJECT]
    proj["tableIds"] = list(dict.fromkeys(proj.get("tableIds", []) + tables))
    write_json(index_path, index)
    state.set("tab", {"dossier": str(tab_dir), "index_cree": created_index, "tables": tables})
    info("Visible par Nexus (serveur MCP de Tab) et par Convert. L'interface web de Tab garde ses tables dans "
         "le navigateur : pour les y voir, importez demo/donnees/" + jeu.csv.name)


def ecrire_table_tab(tab_dir: Path, r: dict, name: str) -> str:
    table_id = tab_id("tbl")
    fields = {
        "fld_date": {"id": "fld_date", "label": "Date", "type": "date", "atelierMapping": "custom"},
        "fld_libelle": {"id": "fld_libelle", "label": "Libellé", "type": "text", "atelierMapping": "entity_title", "width": 320},
        "fld_debit": {"id": "fld_debit", "label": "Débit", "type": "currency", "options": {"currency": "EUR", "decimals": 2}, "atelierMapping": "custom"},
        "fld_credit": {"id": "fld_credit", "label": "Crédit", "type": "currency", "options": {"currency": "EUR", "decimals": 2}, "atelierMapping": "custom"},
        "fld_montant": {"id": "fld_montant", "label": "Montant", "type": "currency", "options": {"currency": "EUR", "decimals": 2}, "atelierMapping": "custom"},
    }
    records, order = {}, []
    for o in r["operations"]:
        rid = tab_id("rec")
        cells: dict[str, Any] = {"fld_date": o["date"], "fld_libelle": o["libelle"], "fld_montant": round(o["credit"] - o["debit"], 2)}
        if o["debit"]:
            cells["fld_debit"] = o["debit"]
        if o["credit"]:
            cells["fld_credit"] = o["credit"]
        records[rid] = {"id": rid, "kind": "data", "cells": cells}
        order.append(rid)
    view = tab_id("view")
    write_json(tab_dir / "tables" / f"{table_id}.json", {
        "id": table_id, "projectId": TAB_PROJECT, "name": name, "fieldOrder": list(fields), "rowOrder": order,
        "fields": fields, "records": records,
        "views": [{"id": view, "name": "Grille", "mode": "hybrid", "filters": [], "sorts": [], "hiddenFieldIds": []}],
        "activeViewId": view,
    })
    return table_id


COULEURS = ["blue", "green", "amber", "red", "violet", "pink", "teal", "gray"]


def ajouter_categories(path: Path, jeu: Jeu) -> int:
    """Ajoute une colonne « Catégorie » (liste) remplie d'après le jeu de données."""
    t = json.loads(path.read_text(encoding="utf-8"))
    by_label = {f["label"]: fid for fid, f in t["fields"].items()}
    cats = sorted({o["categorie"] for o in jeu.ops})
    choices = [{"id": f"opt_{i}", "label": c, "color": COULEURS[i % len(COULEURS)]} for i, c in enumerate(cats)]
    choice_id = {c["label"]: c["id"] for c in choices}
    fid = "fld_categorie"
    t["fields"][fid] = {"id": fid, "label": "Catégorie", "type": "select", "options": {"choices": choices},
                        "atelierMapping": "custom", "width": 160}
    if fid not in t["fieldOrder"]:
        t["fieldOrder"].append(fid)
    n = 0
    for rec in t["records"].values():
        c = rec.get("cells", {})
        date, lib = c.get(by_label.get("Date", "")), c.get(by_label.get("Libellé", ""))
        mt = c.get(by_label.get("Montant", ""))
        if mt is None:
            mt = (c.get(by_label.get("Crédit", "")) or 0) - (c.get(by_label.get("Débit", "")) or 0)
        cat = jeu.categorie(str(date)[:10], lib, float(mt)) if lib else None
        if cat:
            c[fid] = choice_id[cat]
            n += 1
    write_json(path, t)
    return n


def retirer_tab(s: dict) -> None:
    tab_dir = Path(s["dossier"])
    # Les tables du kit, et celles que les workflows de démo ont ajoutées depuis au projet de démo.
    extra = []
    for f in (tab_dir / "tables").glob("*.json"):
        try:
            if json.loads(f.read_text(encoding="utf-8")).get("projectId") == TAB_PROJECT:
                extra.append(f.stem)
        except (OSError, json.JSONDecodeError):
            continue
    s["tables"] = list(dict.fromkeys(s.get("tables", []) + extra))
    for tid in s.get("tables", []):
        f = tab_dir / "tables" / f"{tid}.json"
        if f.exists():
            f.unlink()
        snap = tab_dir / "exports" / f"{tid}.json"
        if snap.exists():
            snap.unlink()
    index_path = tab_dir / "atelier.json"
    if index_path.exists():
        index = json.loads(index_path.read_text(encoding="utf-8"))
        proj = index.get("projects", {}).get(TAB_PROJECT)
        reste = [t for t in (proj or {}).get("tableIds", []) if t not in s.get("tables", [])
                 and (tab_dir / "tables" / f"{t}.json").exists()]
        if reste:
            warn(f"Le projet « Compta 2026 » contient {len(reste)} table(s) ajoutée(s) depuis : il est conservé.")
            proj["tableIds"] = reste
        else:
            index.get("projects", {}).pop(TAB_PROJECT, None)
            ws = index.get("workspaces", {}).get(TAB_WORKSPACE)
            if ws is not None:
                ws["projectIds"] = [p for p in ws.get("projectIds", []) if p != TAB_PROJECT]
                if not ws["projectIds"]:
                    index["workspaces"].pop(TAB_WORKSPACE)
                    index["workspaceOrder"] = [w for w in index.get("workspaceOrder", []) if w != TAB_WORKSPACE]
        if s.get("index_cree") and not index.get("workspaces") and not any((tab_dir / "tables").glob("*.json")):
            index_path.unlink()
            info("atelier.json, créé par le kit et désormais vide, supprimé")
        else:
            write_json(index_path, index)
    ok(f"{len(s.get('tables', []))} table(s) Tab supprimée(s)")


# ─── Viz ────────────────────────────────────────────────────────────────────────────────────────


def charger_viz(api: Api, jeu: Jeu, state: State) -> None:
    v = jeu.d["viz"]
    columns = [
        {"key": "date", "label": "Date", "type": "date"},
        {"key": "libelle", "label": "Libellé", "type": "string"},
        {"key": "debit", "label": "Débit", "type": "number"},
        {"key": "credit", "label": "Crédit", "type": "number"},
        {"key": "montant", "label": "Montant", "type": "number"},
        {"key": "categorie", "label": "Catégorie", "type": "string"},
        {"key": "mois", "label": "Mois", "type": "string"},
    ]
    rows = [{"date": o["date"], "libelle": o["libelle"], "debit": o["debit"] or None, "credit": o["credit"] or None,
             "montant": round(o["credit"] - o["debit"], 2), "categorie": o["categorie"], "mois": o["mois"]} for o in jeu.ops]
    res = api.post("/atelier/datasets", {"name": v["jeu"], "key": v["cle"], "table": {
        "format": "atelier-table/1", "name": "operations", "label": "Opérations", "columns": columns, "rows": rows}})
    ds = res["dataset_id"]
    ok(f"Jeu « {v['jeu']} » {'créé' if res['action'] == 'created' else 'mis à jour'} ({res['rows']} lignes)")
    a = v["alerte"]
    alert = api.post("/alerts", {
        "name": a["nom"], "dataset_id": ds, "measure": {"field": "Débit", "agg": "sum"},
        "filters": [{"field": "Catégorie", "op": "eq", "values": [a["categorie"]]},
                    {"field": "Mois", "op": "eq", "values": [jeu.dernier["mois"]]}],
        "comparison": "gt", "threshold": a["seuil"], "notify": True, "system": False,
    })
    valeur = jeu.total(jeu.dernier["mois"], "debit", a["categorie"])
    ok(f"Alerte « {a['nom']} » : {euros(valeur)} pour un seuil de {euros(a['seuil'])}"
       f"{' → déclenchée (viz.alert.triggered)' if alert.get('met') else ''}")
    state.set("viz", {"dataset_id": ds, "alert_id": alert["id"], "valeur": valeur})


def retirer_viz(api: Api, s: dict, nom: str) -> None:
    if s.get("alert_id"):
        api.delete(f"/alerts/{s['alert_id']}")
    # Le jeu du kit, et ceux que le workflow de démo a publiés (« Relevé … — Studio Garance (démo) »).
    ids = {s.get("dataset_id")} | {d["id"] for d in items(api.get("/datasets"))
                                   if nom in d.get("name", "") and d.get("name", "").endswith("(démo)")}
    for ds in filter(None, ids):
        api.delete(f"/datasets/{ds}")
    ok(f"{len(list(filter(None, ids)))} jeu(x) et l'alerte Viz supprimés")


# ─── Trésorerie ─────────────────────────────────────────────────────────────────────────────────


def charger_tresorerie(api: Api, jeu: Jeu, state: State) -> None:
    t = jeu.d["tresorerie"]
    existing = [a for a in items(api.get("/accounts?include_archived=1")) if a["name"] == t["compte"]]
    if existing:
        raise KitError(f"Trésorerie : un compte « {t['compte']} » existe déjà (id {existing[0]['id']}). "
                       "Supprimez-le ou lancez d'abord « retirer ».")
    acc = api.post("/accounts", {"name": t["compte"], "type": "courant", "institution": "Banque Exemple (fictive)",
                                 "opening_balance": f"{jeu.releves[0]['solde_initial']:.2f}"})
    rec: dict[str, Any] = {"account_id": acc["id"], "categories_creees": [], "budgets_crees": []}
    state.set("tresorerie", rec)
    ok(f"Compte « {t['compte']} » (solde d'ouverture {euros(jeu.releves[0]['solde_initial'])})")

    cats = {c["name"].casefold(): c for c in items(api.get("/categories"))}
    for name in sorted({o["categorie"] for o in jeu.ops}):
        if name.casefold() in cats:
            continue
        kind = "revenu" if all(o["credit"] for o in jeu.ops if o["categorie"] == name) else "depense"
        c = api.post("/categories", {"name": name, "kind": kind})
        cats[name.casefold()] = c
        rec["categories_creees"].append(c["id"])
    state.set("tresorerie", rec)
    if rec["categories_creees"]:
        ok(f"{len(rec['categories_creees'])} catégorie(s) ajoutée(s) ; les catégories du même nom déjà présentes sont réutilisées")

    preview = api.upload("/import/preview", {"account_id": str(acc["id"])}, "file", jeu.csv, "text/csv")
    rows = []
    for r in preview["rows"]:
        if r.get("status") not in (None, "ok", "new"):
            continue
        cat = jeu.categorie(r["date"], r["label"], r["amount_cents"] / 100)
        if cat:
            r["category_id"] = cats[cat.casefold()]["id"]
        rows.append({k: r.get(k) for k in ("date", "label", "amount_cents", "category_id", "import_hash")})
    res = api.post("/import/commit", {"account_id": acc["id"], "rows": rows})
    ok(f"Import CSV : {res.get('inserted', len(rows))} opération(s) d'août à octobre, catégorisées")

    month = t["budgets_mois"]
    current = {b["category_id"]: b for b in items(api.get(f"/budgets?month={month}"))}
    skipped = []
    for name, amount in t["budgets"].items():
        cid = cats[name.casefold()]["id"]
        if cid in current:
            skipped.append(name)
            continue
        b = api.post("/budgets", {"category_id": cid, "month": month, "amount_limit": f"{amount:.2f}"})
        rec["budgets_crees"].append(b.get("id"))
    state.set("tresorerie", rec)
    ok(f"Budgets d'octobre 2026 : {len(rec['budgets_crees'])} posé(s)")
    if skipped:
        warn(f"Budget déjà présent, laissé tel quel : {', '.join(skipped)}")


def retirer_tresorerie(api: Api, s: dict) -> None:
    for bid in s.get("budgets_crees", []):
        if bid:
            api.delete(f"/budgets/{bid}")
    if s.get("account_id"):
        api.call("DELETE", f"/accounts/{s['account_id']}?force=1", ok404=True)
    kept = []
    cats = {c["id"]: c for c in items(api.get("/categories"))}
    for cid in s.get("categories_creees", []):
        c = cats.get(cid)
        if c is None:
            continue
        if c.get("transaction_count"):
            kept.append(c["name"])
            continue
        api.delete(f"/categories/{cid}")
    ok("Compte de démo, ses opérations, ses budgets et ses catégories supprimés")
    if kept:
        warn(f"Catégories gardées car utilisées par d'autres opérations : {', '.join(kept)}")


# ─── Projets ────────────────────────────────────────────────────────────────────────────────────


def charger_projets(api: Api, jeu: Jeu, state: State) -> None:
    p = jeu.d["projets"]
    if any(x["name"] == p["projet"] for x in api.get("/projects")):
        raise KitError(f"Projets : le projet « {p['projet']} » existe déjà. Lancez d'abord « retirer ».")
    proj = api.post("/projects", {"name": p["projet"], "description":
                                  "Projet d'exemple du kit de démo de la suite Atelier (données fictives)."})
    state.set("projets", {"project_id": proj["id"]})
    phase = api.post(f"/projects/{proj['id']}/phases", {"title": p["phase"]})
    epic = api.post(f"/phases/{phase['id']}/epics", {"title": p["epic"]})
    story = api.post(f"/epics/{epic['id']}/stories", {"title": p["story"]})
    for tache in p["taches"]:
        w = api.post(f"/stories/{story['id']}/work-items", {"type": "TASK", "title": tache["titre"], "status": "CLOSED",
                                                             "priority": "NORMAL", "dueDate": "2026-11-05"})
        api.post(f"/work-items/{w['id']}/time-entries", {"hours": tache["heures"], "spentOn": "2026-11-05",
                                                         "comment": tache["commentaire"]})
    a = p["alerte_tache"]
    viz = state.app("viz") or {}
    valeur, seuil = viz.get("valeur", jeu.total(jeu.dernier["mois"], "debit", "Matériel")), jeu.d["viz"]["alerte"]["seuil"]
    w = api.post(f"/stories/{story['id']}/work-items", {
        "type": "TASK", "title": a["titre"], "status": "OPEN", "priority": a["priorite"],
        "description": (f"Alerte Atelier Viz déclenchée sur le jeu « {jeu.d['viz']['jeu']} ».\n\n"
                        f"- Valeur mesurée : {euros(valeur)}\n- Seuil : {euros(seuil)}\n\nÀ analyser dans le rapport Viz."),
    })
    api.post(f"/work-items/{w['id']}/log-entries", {"text": (
        "Créée par le kit de démo, comme le ferait le workflow Nexus « Alerte Viz → tâche de suivi Projets » "
        f"à partir de l'alerte Viz « {jeu.d['viz']['alerte']['nom']} ».")})
    api.post(f"/work-items/{w['id']}/time-entries", {"hours": 0.5, "spentOn": "2026-11-09",
                                                     "comment": "Rapprochement des achats Boesner et de l'impression"})
    j = p["jalon"]
    api.post(f"/projects/{proj['id']}/milestones", {"title": j["nom"], "date": j["date"], "phaseId": phase["id"],
                                                    "reachedAt": atteint_le(j["date"]),
                                                    "description": f"Relevé de {jeu.dernier['libelle']} rapproché et catégorisé."})
    state.set("projets", {"project_id": proj["id"], "story_id": story["id"], "tache_alerte_id": w["id"]})
    ok(f"Projet « {p['projet']} » : phase, epic, story n° {story['id']}, 3 tâches, temps passés, jalon atteint")


def atteint_le(date: str) -> str:
    """Fin de journée du jalon, sans dépasser maintenant (Projets refuse une date d'atteinte future)."""
    jalon = datetime.fromisoformat(f"{date}T17:00:00+00:00")
    now = datetime.now(timezone.utc).replace(microsecond=0)
    return min(jalon, now).isoformat().replace("+00:00", ".000Z")


def retirer_projets(api: Api, s: dict) -> None:
    if s.get("project_id"):
        api.delete(f"/projects/{s['project_id']}")
    ok("Projet de démo supprimé (avec ses tâches, temps et jalons)")


# ─── Wiki ───────────────────────────────────────────────────────────────────────────────────────


def pages_wiki(jeu: Jeu, state: State) -> list[tuple[str, str | None, str, str]]:
    """(titre, parent, icône, contenu Markdown)."""
    a = jeu.d["viz"]["alerte"]
    story = (state.app("projets") or {}).get("tache_alerte_id")
    suivi = f"tâche Projets n° {story}" if story else "tâche de suivi dans Projets"
    procedure = """Chaque début de mois, la clôture du mois précédent suit les mêmes étapes dans la suite Atelier.

1. **Convert** : déposer le relevé PDF de la banque. Vérifier que le contrôle des soldes est juste.
2. **Tab** : « Envoyer dans Atelier Tab », projet *Compta 2026*. Remplir la colonne **Catégorie**.
3. **Trésorerie** : exporter le CSV français depuis Convert, puis Importer → aperçu → valider. Comparer aux budgets du mois.
4. **Viz** : actualiser le jeu des opérations. L'alerte *Matériel du mois* surveille le poste le plus variable.
5. **Nexus** : le workflow « Dernière conversion Convert → Tab → Viz » enchaîne les étapes 2 et 4 en un lancement ; chaque écriture attend « Autoriser ».
6. **Projets** : une alerte devient une tâche dans la story *Suivi des budgets* ; marquer le jalon de clôture.
7. **Wiki** : écrire la page du mois sous [[Clôtures mensuelles]].

Voir aussi : [[Fournisseurs]].
"""
    def cloture(r: dict) -> str:
        m = r["mois"]
        deb, cred = jeu.total(m, "debit"), jeu.total(m, "credit")
        mat = jeu.total(m, "debit", a["categorie"])
        lignes = [f"Relevé converti et contrôlé (soldes justes), rangé dans Tab, publié dans Viz. "
                  f"Procédure : [[Procédure de clôture]].", "",
                  "| Indicateur | Montant |", "|---|---:|",
                  f"| Solde initial | {euros(r['solde_initial'])} |", f"| Débits | {euros(deb)} |",
                  f"| Crédits | {euros(cred)} |", f"| Solde final | {euros(r['solde_final'])} |", "",
                  "## Dépenses par catégorie", "", "| Catégorie | Débits |", "|---|---:|"]
        cats: dict[str, float] = {}
        for o in r["operations"]:
            if o["debit"]:
                cats[o["categorie"]] = round(cats.get(o["categorie"], 0) + o["debit"], 2)
        lignes += [f"| {c} | {euros(v)} |" for c, v in sorted(cats.items(), key=lambda x: -x[1])]
        lignes += ["", "## Points d'attention", ""]
        if mat > a["seuil"]:
            lignes.append(f"- [ ] {a['categorie']} à {euros(mat)} pour {euros(a['seuil'])} prévus"
                          + (f" : suivi dans la {suivi}." if r is jeu.dernier else "."))
        else:
            lignes.append(f"- [x] {a['categorie']} à {euros(mat)}, sous le budget de {euros(a['seuil'])}.")
        lignes.append("- Fournisseurs du mois : voir [[Fournisseurs]].")
        return "\n".join(lignes) + "\n"

    fournisseurs = """Fournisseurs réguliers du studio (données fictives).

| Fournisseur | Poste | Remarque |
|---|---|---|
| Boesner (Arles) | Matériel | Papiers, encres, cadres. Deux à trois passages par mois. |
| Imprimerie du Rhône | Matériel | Tirages clients : à refacturer quand c'est possible. |
| LDLC Pro | Matériel | Informatique. |
| Adobe, Ionos | Logiciels | Abonnements mensuels. |
| SCI des Tanneurs | Locaux | Loyer de l'atelier, le 1er du mois. |

Retour à la [[Procédure de clôture]].
"""
    pages = [("Procédure de clôture", None, "🗂️", procedure),
             ("Clôtures mensuelles", None, "📅", "Une page par mois, écrite à la fin de la clôture.\n")]
    pages += [(f"Clôture {r['libelle']}", "Clôtures mensuelles", "🧾", cloture(r)) for r in jeu.releves]
    pages.append(("Fournisseurs", None, "🏷️", fournisseurs))
    return pages


def charger_wiki(api: Api, jeu: Jeu, state: State) -> None:
    w = jeu.d["wiki"]
    if any(s["name"] == w["espace"] for s in api.get("/spaces")):
        raise KitError(f"Wiki : l'espace « {w['espace']} » existe déjà. Lancez d'abord « retirer ».")
    space = api.post("/spaces", {"name": w["espace"], "description": w["description"], "icon": "🎨"})
    rec: dict[str, Any] = {"space_id": space["id"], "pages": []}
    state.set("wiki", rec)
    ids: dict[str, int] = {}
    for title, parent, icon, content in pages_wiki(jeu, state):
        body: dict[str, Any] = {"spaceId": space["id"], "title": title, "content": content, "icon": icon}
        if parent:
            body["parentId"] = ids[parent]
        page = api.post("/pages", body)
        page = page.get("page", page)
        ids[title] = page["id"]
        rec["pages"].append(page["id"])
    state.set("wiki", rec)
    ok(f"Espace « {w['espace']} » : {len(rec['pages'])} pages reliées (procédure, clôtures d'août à octobre, fournisseurs)")


def retirer_wiki(api: Api, s: dict) -> None:
    for pid in reversed(s.get("pages", [])):
        api.delete(f"/pages/{pid}")
    if s.get("space_id"):
        try:
            api.delete(f"/spaces/{s['space_id']}")
        except KitError as exc:
            warn(f"Espace gardé : {exc}")
            return
    ok("Espace et pages du Wiki supprimés")


# ─── Nexus ──────────────────────────────────────────────────────────────────────────────────────


def charger_nexus(api: Api, jeu: Jeu, state: State) -> None:
    library = {t["slug"]: t for t in api.get("/workflows/library")}
    viz, projets = state.app("viz") or {}, state.app("projets") or {}
    a = jeu.d["viz"]["alerte"]
    plans = [
        ("convert-derniere-conversion-tab-viz", {"projet_tab": TAB_PROJECT}),
        ("viz-alerte-tache-projets", {"jeu": viz.get("dataset_id", ""), "alerte": a["nom"],
                                      "valeur": euros(viz.get("valeur", 0)) if viz else "non renseignée",
                                      "seuil": euros(a["seuil"]), "story": str(projets.get("story_id", ""))}),
    ]
    rec: dict[str, Any] = {"workflows": [], "triggers": []}
    for slug, defaults in plans:
        t = library.get(slug)
        if t is None:
            warn(f"Modèle « {slug} » absent de la bibliothèque de cette version de Nexus : ignoré")
            continue
        params = copy.deepcopy(t["params"])
        for p in params:
            if p["name"] in defaults and defaults[p["name"]]:
                p["default"] = defaults[p["name"]]
        wf = api.post("/workflows", {"version": 2, "title": f"{t['title']} · démo Studio Garance",
                                     "description": t["description"][:500], "steps": t["steps"], "params": params})
        rec["workflows"].append(wf["id"])
        state.set("nexus", rec)
        ok(f"Workflow « {wf['title']} »" + ("" if t.get("available") else " (une app du modèle est injoignable)"))
        if slug == "viz-alerte-tache-projets":
            trig = api.post(f"/workflows/{wf['id']}/triggers", {
                "kind": "event", "label": "Alerte Matériel (démo)", "enabled": True, "app": "viz",
                "types": ["viz.alert.triggered"],
                "filters": [{"path": "subject.label", "op": "eq", "value": a["nom"]}],
                "params": {"jeu": "{{event.data.dataset_id}}", "alerte": "{{event.subject.label}}",
                           "valeur": "{{event.data.value}}", "seuil": "{{event.data.threshold}}",
                           "story": str(projets.get("story_id", ""))},
                "max_runs_per_hour": 2, "debounce_seconds": 0,
            })
            rec["triggers"].append(trig["id"])
            state.set("nexus", rec)
            ok("Déclencheur sur viz.alert.triggered (filtré sur l'alerte de démo). « Tester » le lance une fois, "
               "chaque étape attend « Autoriser »")


def retirer_nexus(api: Api, s: dict) -> None:
    for tid in s.get("triggers", []):
        api.delete(f"/triggers/{tid}")
    for wid in s.get("workflows", []):
        api.delete(f"/workflows/{wid}")
    ok(f"{len(s.get('workflows', []))} workflow(s) et leur déclencheur supprimés")


# ─── Commandes ──────────────────────────────────────────────────────────────────────────────────


TITRES = {"convert": "Atelier Convert", "tab": "Atelier Tab (fichiers du serveur MCP)", "viz": "Atelier Viz",
          "tresorerie": "Atelier Trésorerie", "projets": "Atelier Projets", "wiki": "Atelier Wiki",
          "nexus": "Atelier Nexus"}


def apis() -> dict[str, Api]:
    out = {}
    for app, default in URLS.items():
        base = os.environ.get(f"KIT_{app.upper()}_URL", default)
        headers = {"X-Requested-With": "atelier-demo"} if app == "tresorerie" else {}
        if app == "wiki":
            headers["X-Atelier-User"] = AUTEUR
        out[app] = Api(TITRES[app], base, headers)
    return out


def charger(selected: list[str], state: State, tab_dir: Path) -> int:
    jeu, api = Jeu(), apis()
    errors = 0
    for app in APPS:
        if app not in selected:
            continue
        step(TITRES[app])
        if state.app(app):
            info("déjà chargé : rien à faire (« retirer » puis « charger » pour recommencer)")
            continue
        try:
            if app == "convert":
                charger_convert(api["convert"], jeu, state)
            elif app == "tab":
                conv = api["convert"] if state.app("convert") else None
                charger_tab(tab_dir, jeu, state, conv)
            elif app == "viz":
                charger_viz(api["viz"], jeu, state)
            elif app == "tresorerie":
                charger_tresorerie(api["tresorerie"], jeu, state)
            elif app == "projets":
                charger_projets(api["projets"], jeu, state)
            elif app == "wiki":
                charger_wiki(api["wiki"], jeu, state)
            elif app == "nexus":
                charger_nexus(api["nexus"], jeu, state)
        except Exception as exc:  # une app en erreur n'empêche pas les suivantes
            errors += 1
            print(f"  {red}✗{reset} {exc if isinstance(exc, KitError) else repr(exc)}")
            if state.app(app):
                info("une partie a été créée : « retirer » l'enlèvera")
    return errors


def retirer(selected: list[str], state: State) -> int:
    api = apis()
    errors = 0
    for app in reversed(APPS):
        s = state.app(app)
        if app not in selected or not s:
            continue
        step(TITRES[app])
        try:
            if app == "tab":
                retirer_tab(s)
            elif app == "viz":
                retirer_viz(api[app], s, Jeu().d["nom"])
            else:
                globals()[f"retirer_{app}"](api[app], s)
            state.drop(app)
        except KitError as exc:
            errors += 1
            print(f"  {red}✗{reset} {exc}")
    if not state.data:
        print(f"\n{green}Kit de démo retiré.{reset}")
    return errors


def etat(state: State) -> int:
    if not state.data:
        print("Le kit de démo n'est pas chargé.")
        return 0
    for app in APPS:
        s = state.app(app)
        mark = f"{green}chargé{reset} le {s['charge_le']}" if s else f"{dim}non chargé{reset}"
        print(f"  {TITRES[app]:<40} {mark}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Kit de démo Studio Garance pour la suite Atelier.")
    ap.add_argument("commande", nargs="?", default="charger", choices=["charger", "retirer", "etat"])
    ap.add_argument("--apps", default=",".join(APPS), help=f"apps concernées, séparées par des virgules ({','.join(APPS)})")
    ap.add_argument("--data", default=os.environ.get("KIT_DATA_DIR", str(ROOT / "data")),
                    help="dossier data/ du déploiement (défaut : Atelier_Deploy/data)")
    args = ap.parse_args()
    selected = [a.strip() for a in args.apps.split(",") if a.strip()]
    unknown = [a for a in selected if a not in APPS]
    if unknown:
        ap.error(f"app inconnue : {', '.join(unknown)}")
    data = Path(args.data)
    state = State(data / "demo" / "studio-garance.json")
    if args.commande == "etat":
        return etat(state)
    if args.commande == "retirer":
        return 1 if retirer(selected, state) else 0
    print(f"{bold}Kit de démo « Studio Garance »{reset} {dim}(données fictives){reset}")
    errors = charger(selected, state, data / "atelier_tab")
    if errors:
        print(f"\n{yellow}{errors} app(s) en erreur.{reset} Corrigez puis relancez : les apps déjà chargées sont sautées.")
        return 1
    print(f"\n{green}Chargé.{reset} Parcours conseillé : Convert → Tab → Viz → Trésorerie → Nexus → Projets → Wiki.")
    print(f"{dim}Pour tout enlever : sudo ./demo/charger.sh retirer{reset}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
