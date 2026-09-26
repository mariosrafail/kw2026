from __future__ import annotations
import hashlib, json, os, random, re, subprocess, sys, threading, urllib.request
from pathlib import Path

DEFAULT_MANIFEST_URL = "https://cab-smith-walls-spending.trycloudflare.com/kw/update_manifest.json"
APP_VERSION = "1.2.1"
STALE_MANIFEST_HOSTS = (
    "portal-fresh-pleasant-peoples.trycloudflare.com",
    "jimmy-kate-default-consolidation.trycloudflare.com",
    "innovations-carried-society-roster.trycloudflare.com",
)
FILES = (
    ("kw.exe", "exe_url", "exe_sha256"),
    ("kw.pck", "pck_url", "pck_sha256"),
)

def app_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent

def resource_dir() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(getattr(sys, "_MEIPASS"))
    return Path(__file__).resolve().parent

def asset_path(name: str) -> Path:
    return resource_dir() / "assets" / name

def config_path() -> Path:
    return app_dir() / "updater_config.json"

def sanitize_virtual_username(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_-]+", "_", str(value).strip()).strip("_")[:24]
    return cleaned if len(cleaned) >= 3 else "KW_ROOKIE"

def generate_virtual_username() -> str:
    left = random.choice(("NEON", "VOID", "PIXEL", "VOLT", "RIFT", "NOVA", "CYBER", "NIGHT"))
    right = random.choice(("CLAW", "CORE", "SHIFT", "GHOST", "WING", "RIDER", "PULSE", "DRIFT"))
    return f"{left}_{right}_{random.randint(100, 999)}"

def load_config() -> dict:
    cfg = {
        "manifest_url": DEFAULT_MANIFEST_URL,
        "game_dir": str(Path.home() / "Games" / "KW"),
        "virtual_username": "",
    }
    try:
        data = json.loads(config_path().read_text(encoding="utf-8-sig"))
        if isinstance(data, dict):
            cfg.update({k: v for k, v in data.items() if isinstance(v, (str, int, float, bool))})
            stored_url = str(cfg.get("manifest_url", ""))
            if (
                "192.168.1.154:8081" in stored_url
                or "192.168.1.154:8082" in stored_url
                or any(host in stored_url for host in STALE_MANIFEST_HOSTS)
            ):
                cfg["manifest_url"] = DEFAULT_MANIFEST_URL
    except Exception:
        pass
    local = app_dir()
    if (local / "kw.exe").exists() or (local / "kw.pck").exists():
        cfg["game_dir"] = str(local)
    username = sanitize_virtual_username(str(cfg.get("virtual_username", "")))
    if username == "KW_ROOKIE" and not str(cfg.get("virtual_username", "")).strip():
        username = generate_virtual_username()
    cfg["virtual_username"] = username
    return cfg

def save_config(cfg: dict) -> None:
    config_path().write_text(json.dumps(cfg, indent=2), encoding="utf-8")

def write_virtual_profile(game_dir: Path, username: str) -> None:
    game_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "profile_kind": "virtual",
        "virtual_username": sanitize_virtual_username(username),
        "real_account": False,
        "profile_version": 1,
    }
    (game_dir / "kw_profile.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

def fetch_updates(manifest_url: str) -> list[dict]:
    base = manifest_url.rsplit("/", 1)[0]
    try:
        data = fetch_json_loose(base + "/updates.json")
        rows = data.get("updates", []) if isinstance(data, dict) else []
        return rows if isinstance(rows, list) else []
    except Exception:
        return []

def fetch_json_loose(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": f"KWUpdater/{APP_VERSION}", "ngrok-skip-browser-warning": "1"})
    with urllib.request.urlopen(req, timeout=12) as response:
        raw = response.read()
    data = json.loads(raw.decode("utf-8-sig"))
    return data if isinstance(data, dict) else {}

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().lower()

def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": f"KWUpdater/{APP_VERSION}"})
    with urllib.request.urlopen(req, timeout=12) as response:
        raw = response.read()
    data = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(data, dict) or not data.get("version"):
        raise RuntimeError("Invalid update manifest")
    return data

def update_plan(game_dir: Path, manifest: dict) -> list[dict]:
    result = []
    for filename, url_key, hash_key in FILES:
        expected = str(manifest.get(hash_key, "")).strip().lower()
        url = str(manifest.get(url_key, "")).strip()
        target = game_dir / filename
        current = sha256(target) if target.exists() else ""
        if not expected or not url:
            raise RuntimeError(f"Manifest is missing {filename} metadata")
        result.append({
            "filename": filename,
            "url": url,
            "expected": expected,
            "current": current,
            "changed": current != expected,
            "missing": not target.exists(),
        })
    return result

def read_local_version(game_dir: Path) -> str:
    try:
        return (game_dir / "game_version.txt").read_text(encoding="utf-8-sig").strip() or "0.0.0"
    except Exception:
        return "0.0.0"

def download_file(url: str, destination: Path, expected_hash: str, progress=None) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": f"KWUpdater/{APP_VERSION}"})
    temp = destination.with_suffix(destination.suffix + ".download")
    h = hashlib.sha256()
    downloaded = 0
    with urllib.request.urlopen(req, timeout=60) as response, temp.open("wb") as out:
        total = int(response.headers.get("Content-Length") or 0)
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
            h.update(chunk)
            downloaded += len(chunk)
            if progress:
                progress(downloaded, total)
    actual = h.hexdigest().lower()
    if actual != expected_hash.lower():
        temp.unlink(missing_ok=True)
        raise RuntimeError(f"Hash check failed for {destination.name}")
    os.replace(temp, destination)

def qa_mode(argv: list[str]) -> int:
    def arg_value(flag: str, default: str = "") -> str:
        try:
            return argv[argv.index(flag) + 1]
        except Exception:
            return default
    out = arg_value("--qa")
    if not out:
        return -1
    manifest_url = arg_value("--manifest", DEFAULT_MANIFEST_URL)
    game_dir = Path(arg_value("--game-dir", str(Path.home() / "Games" / "KW")))
    report = {"ok": False, "manifest_url": manifest_url, "game_dir": str(game_dir)}
    try:
        manifest = fetch_json(manifest_url)
        plan = update_plan(game_dir, manifest)
        update_required = any(x["changed"] for x in plan)
        report.update({
            "ok": True,
            "remote_version": manifest["version"],
            "local_version": read_local_version(game_dir),
            "update_required": update_required,
            "play_allowed": not update_required,
            "plan": [{k: x[k] for k in ("filename", "changed", "missing")} for x in plan],
        })
    except Exception as exc:
        report["error"] = str(exc)
    Path(out).write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0 if report["ok"] else 2

def run_gui() -> int:
    import tkinter as tk
    from tkinter import filedialog, messagebox, simpledialog, ttk

    C = {
        "bg": "#09111f",
        "sidebar": "#10182a",
        "panel": "#18243b",
        "panel2": "#202d49",
        "cream": "#f7f4df",
        "muted": "#98a7bd",
        "mint": "#85c799",
        "cyan": "#20acf3",
        "purple": "#47429d",
        "pink": "#e27393",
        "ink": "#0b0d14",
        "line": "#31415e",
        "warn": "#ffb461",
    }

    cfg = load_config()
    cfg["virtual_username"] = sanitize_virtual_username(cfg.get("virtual_username", ""))
    if cfg["virtual_username"] == "KW_ROOKIE" and not str(cfg.get("virtual_username", "")).strip():
        cfg["virtual_username"] = generate_virtual_username()
    save_config(cfg)

    state = {
        "manifest": None,
        "plan": None,
        "busy": False,
        "checked": False,
        "up_to_date": False,
        "updates": [],
        "view": "home",
    }

    root = tk.Tk()
    root.title("KW Client")
    root.geometry("1180x760")
    root.resizable(False, False)
    root.configure(bg=C["bg"])

    def load_photo(name: str, *, subsample: int = 1):
        try:
            image = tk.PhotoImage(file=str(asset_path(name)))
            return image.subsample(subsample, subsample) if subsample > 1 else image
        except Exception:
            return None

    logo_image = load_photo("kw_logo.png", subsample=3)
    avatar_image = load_photo("avatar.png", subsample=2)
    hero_frames = [load_photo(f"hero_{i}.png") for i in range(8)]
    hero_frames = [x for x in hero_frames if x is not None]

    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except Exception:
        pass
    style.configure(
        "KW.Horizontal.TProgressbar",
        troughcolor="#10182a",
        background=C["cyan"],
        bordercolor=C["line"],
        lightcolor=C["cyan"],
        darkcolor=C["cyan"],
        thickness=14,
    )

    username_var = tk.StringVar(value=str(cfg["virtual_username"]))
    status = tk.StringVar(value="CHECKING LIVE BUILD...")
    versions = tk.StringVar(value="LOCAL --     SERVER --")
    detail = tk.StringVar(value="Connecting to the KW update service.")
    folder_var = tk.StringVar(value=str(cfg["game_dir"]))
    url_var = tk.StringVar(value=str(cfg["manifest_url"]))
    server_var = tk.StringVar(value="NETWORK  //  CHECKING")
    latest_var = tk.StringVar(value="LATEST BUILD")

    shell = tk.Frame(root, bg=C["bg"])
    shell.pack(fill="both", expand=True)

    sidebar = tk.Frame(shell, bg=C["sidebar"], width=190)
    sidebar.pack(side="left", fill="y")
    sidebar.pack_propagate(False)

    brand = tk.Frame(sidebar, bg=C["sidebar"])
    brand.pack(anchor="w", padx=16, pady=(16, 0))
    if logo_image is not None:
        tk.Label(brand, image=logo_image, bg=C["sidebar"], bd=0).pack(side="left")
    tk.Label(brand, text="KW", font=("Segoe UI", 26, "bold"), fg=C["cream"], bg=C["sidebar"]).pack(side="left", padx=(6, 0))
    tk.Label(
        sidebar,
        text="ONLINE CLIENT",
        font=("Consolas", 9, "bold"),
        fg=C["mint"],
        bg=C["sidebar"],
    ).pack(anchor="w", padx=22, pady=(0, 26))

    content = tk.Frame(shell, bg=C["bg"])
    content.pack(side="left", fill="both", expand=True)

    topbar = tk.Frame(content, bg=C["bg"], height=92)
    topbar.pack(fill="x", padx=26, pady=(18, 0))
    topbar.pack_propagate(False)

    title_box = tk.Frame(topbar, bg=C["bg"])
    title_box.pack(side="left", fill="y")
    tk.Label(title_box, text="KW // CLIENT", font=("Segoe UI", 22, "bold"), fg=C["cream"], bg=C["bg"]).pack(anchor="w", pady=(8, 0))
    tk.Label(title_box, textvariable=server_var, font=("Consolas", 9, "bold"), fg=C["cyan"], bg=C["bg"]).pack(anchor="w", pady=(4, 0))

    profile = tk.Frame(topbar, bg=C["panel"], highlightbackground=C["mint"], highlightthickness=2)
    profile.pack(side="right", fill="y", padx=(10, 0))
    avatar = tk.Canvas(profile, width=64, height=64, bg=C["panel"], highlightthickness=0)
    avatar.pack(side="left", padx=(10, 7), pady=9)
    avatar.create_oval(5, 5, 59, 59, fill=C["purple"], outline=C["mint"], width=3)
    if avatar_image is not None:
        avatar.create_image(32, 32, image=avatar_image)
    else:
        avatar.create_text(32, 33, text="KW", fill=C["cream"], font=("Segoe UI", 13, "bold"))

    profile_text = tk.Frame(profile, bg=C["panel"])
    profile_text.pack(side="left", padx=(0, 12), pady=10)
    username_label = tk.Label(profile_text, textvariable=username_var, font=("Segoe UI", 12, "bold"), fg=C["cream"], bg=C["panel"])
    username_label.pack(anchor="w")
    tk.Label(profile_text, text="VIRTUAL PROFILE  //  LOCAL ONLY", font=("Consolas", 8, "bold"), fg=C["mint"], bg=C["panel"]).pack(anchor="w", pady=(2, 4))
    profile_actions = tk.Frame(profile_text, bg=C["panel"])
    profile_actions.pack(anchor="w")

    pages = tk.Frame(content, bg=C["bg"])
    pages.pack(fill="both", expand=True, padx=26, pady=(8, 22))
    home_page = tk.Frame(pages, bg=C["bg"])
    updates_page = tk.Frame(pages, bg=C["bg"])

    def flat_button(parent, text, command, *, bg=None, fg=None, compact=False):
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=bg or C["panel2"],
            fg=fg or C["cream"],
            activebackground=C["cyan"],
            activeforeground=C["ink"],
            relief="flat",
            bd=0,
            padx=12 if compact else 16,
            pady=7 if compact else 11,
            font=("Segoe UI", 9 if compact else 11, "bold"),
            cursor="hand2",
        )

    nav_home = flat_button(sidebar, "HOME", lambda: None, bg=C["purple"])
    nav_home.pack(fill="x", padx=14, pady=4)
    nav_updates = flat_button(sidebar, "UPDATES", lambda: None)
    nav_updates.pack(fill="x", padx=14, pady=4)
    tk.Frame(sidebar, bg=C["line"], height=1).pack(fill="x", padx=16, pady=15)
    tk.Label(sidebar, text="GAME", font=("Consolas", 8, "bold"), fg=C["muted"], bg=C["sidebar"]).pack(anchor="w", padx=20)
    sidebar_version = tk.Label(sidebar, text="VERSION --", font=("Consolas", 9, "bold"), fg=C["cream"], bg=C["sidebar"])
    sidebar_version.pack(anchor="w", padx=20, pady=(6, 2))
    sidebar_server = tk.Label(sidebar, text="SERVER CHECKING", font=("Consolas", 8), fg=C["cyan"], bg=C["sidebar"])
    sidebar_server.pack(anchor="w", padx=20)

    tk.Label(
        sidebar,
        text="PROFILE SYSTEM\nIS VIRTUAL FOR NOW.\nNO ACCOUNT LOGIN.",
        justify="left",
        font=("Consolas", 8),
        fg=C["muted"],
        bg=C["sidebar"],
    ).pack(side="bottom", anchor="w", padx=20, pady=20)

    hero = tk.Canvas(home_page, width=920, height=330, bg=C["panel"], highlightbackground=C["cyan"], highlightthickness=2, bd=0)
    hero.pack(fill="x", pady=(0, 14))
    hero_bg_id = None
    if hero_frames:
        hero_bg_id = hero.create_image(0, 0, image=hero_frames[0], anchor="nw")
    else:
        hero.create_rectangle(0, 0, 920, 330, fill=C["panel"], outline="")
    hero.create_text(28, 28, text="KW // BATTLE CLIENT", anchor="nw", fill=C["pink"], font=("Consolas", 10, "bold"))
    hero.create_text(28, 64, text="BATTLE.\nBUILD.\nBELONG.", anchor="nw", fill=C["cream"], font=("Segoe UI", 31, "bold"))
    hero.create_text(30, 190, text="SLOW-MOTION WARFARE  //  LIVE UPDATE SERVICE", anchor="nw", fill="#b7c6d9", font=("Consolas", 9, "bold"))
    status_id = hero.create_text(30, 230, text=status.get(), anchor="nw", fill=C["mint"], font=("Segoe UI", 14, "bold"))
    versions_id = hero.create_text(30, 258, text=versions.get(), anchor="nw", fill=C["cream"], font=("Consolas", 9, "bold"))
    detail_id = hero.create_text(30, 284, text=detail.get(), anchor="nw", fill="#b5c2d4", width=560, font=("Segoe UI", 9))

    action_btn = flat_button(hero, "CHECK", lambda: None, bg=C["pink"], fg=C["cream"])
    action_btn.config(width=17, pady=14)
    play_btn = flat_button(hero, "PLAY", lambda: None, bg=C["cyan"], fg=C["ink"])
    play_btn.config(width=17, pady=14, state="disabled")
    hero.create_window(800, 245, window=play_btn, width=190, height=54)
    hero.create_window(800, 302, window=action_btn, width=190, height=48)

    def sync_hero_text(*_):
        hero.itemconfig(status_id, text=status.get())
        hero.itemconfig(versions_id, text=versions.get())
        hero.itemconfig(detail_id, text=detail.get())

    status.trace_add("write", sync_hero_text)
    versions.trace_add("write", sync_hero_text)
    detail.trace_add("write", sync_hero_text)

    def animate_hero(index: int = 0):
        if hero_bg_id is not None and hero_frames and root.winfo_exists():
            hero.itemconfig(hero_bg_id, image=hero_frames[index % len(hero_frames)])
            root.after(145, lambda: animate_hero(index + 1))

    root.after(220, animate_hero)

    progress = ttk.Progressbar(home_page, style="KW.Horizontal.TProgressbar", mode="determinate", maximum=100)
    progress.pack(fill="x", pady=(0, 14))

    cards = tk.Frame(home_page, bg=C["bg"])
    cards.pack(fill="both", expand=True)
    cards.columnconfigure(0, weight=3)
    cards.columnconfigure(1, weight=2)

    install_card = tk.Frame(cards, bg=C["panel"], highlightbackground=C["line"], highlightthickness=1)
    install_card.grid(row=0, column=0, sticky="nsew", padx=(0, 7))
    tk.Label(install_card, text="INSTALLATION", font=("Segoe UI", 13, "bold"), fg=C["cream"], bg=C["panel"]).pack(anchor="w", padx=18, pady=(16, 8))

    folder_row = tk.Frame(install_card, bg=C["panel"])
    folder_row.pack(fill="x", padx=18)
    folder_entry = tk.Entry(folder_row, textvariable=folder_var, font=("Consolas", 9), bg=C["sidebar"], fg=C["cream"], insertbackground=C["cream"], relief="flat")
    folder_entry.pack(side="left", fill="x", expand=True, ipady=9)

    info_card = tk.Frame(cards, bg=C["panel"], highlightbackground=C["line"], highlightthickness=1)
    info_card.grid(row=0, column=1, sticky="nsew", padx=(7, 0))
    tk.Label(info_card, text="CLIENT STATUS", font=("Segoe UI", 13, "bold"), fg=C["cream"], bg=C["panel"]).pack(anchor="w", padx=18, pady=(16, 8))
    tk.Label(info_card, textvariable=latest_var, font=("Consolas", 11, "bold"), fg=C["mint"], bg=C["panel"]).pack(anchor="w", padx=18)
    tk.Label(
        info_card,
        text="HASH VERIFIED\nDIRECT UDP GAMEPLAY\nLOCAL VIRTUAL ID",
        justify="left",
        font=("Consolas", 9),
        fg=C["muted"],
        bg=C["panel"],
    ).pack(anchor="w", padx=18, pady=(12, 16))

    updates_header = tk.Frame(updates_page, bg=C["panel"], highlightbackground=C["pink"], highlightthickness=2)
    updates_header.pack(fill="x", pady=(0, 12))
    tk.Label(updates_header, text="UPDATES // PATCH FEED", font=("Segoe UI", 22, "bold"), fg=C["cream"], bg=C["panel"]).pack(anchor="w", padx=22, pady=(18, 2))
    tk.Label(updates_header, text="Latest KW client and gameplay changes", font=("Consolas", 9), fg=C["muted"], bg=C["panel"]).pack(anchor="w", padx=22, pady=(0, 18))

    updates_text = tk.Text(
        updates_page,
        bg=C["sidebar"],
        fg=C["cream"],
        insertbackground=C["cream"],
        relief="flat",
        wrap="word",
        font=("Segoe UI", 10),
        padx=20,
        pady=18,
        state="disabled",
        highlightbackground=C["line"],
        highlightthickness=1,
    )
    updates_text.pack(fill="both", expand=True)
    updates_text.tag_configure("version", foreground=C["mint"], font=("Consolas", 11, "bold"))
    updates_text.tag_configure("title", foreground=C["cream"], font=("Segoe UI", 15, "bold"))
    updates_text.tag_configure("body", foreground=C["muted"], font=("Segoe UI", 10))
    updates_text.tag_configure("bullet", foreground=C["cyan"], font=("Segoe UI", 10))

    def render_updates(rows=None):
        rows = rows or state.get("updates") or [
            {
                "version": "alpha-0.1.49",
                "title": "PERFORMANCE / ONLINE PASS",
                "date": "2026-09-26",
                "items": [
                    "Compact online snapshots and lower network overhead.",
                    "MultiMesh combat FX, weapon visuals and warrior render batching.",
                    "Projectile, grenade, damage and spawn-effect pooling.",
                    "Improved remote actor LOD and reduced shadow/draw-call cost.",
                ],
            }
        ]
        updates_text.config(state="normal")
        updates_text.delete("1.0", "end")
        for row in rows:
            updates_text.insert("end", f"{row.get('version', 'KW UPDATE')}   {row.get('date', '')}\n", "version")
            updates_text.insert("end", str(row.get("title", "UPDATE")) + "\n", "title")
            items = row.get("items", [])
            if isinstance(items, list):
                for item in items:
                    updates_text.insert("end", "  ◆  ", "bullet")
                    updates_text.insert("end", str(item) + "\n", "body")
            updates_text.insert("end", "\n")
        updates_text.config(state="disabled")

    render_updates()

    def show_view(name: str):
        state["view"] = name
        home_page.pack_forget()
        updates_page.pack_forget()
        nav_home.config(bg=C["purple"] if name == "home" else C["panel2"])
        nav_updates.config(bg=C["purple"] if name == "updates" else C["panel2"])
        if name == "updates":
            updates_page.pack(fill="both", expand=True)
        else:
            home_page.pack(fill="both", expand=True)

    nav_home.config(command=lambda: show_view("home"))
    nav_updates.config(command=lambda: show_view("updates"))
    show_view("home")

    def persist_profile(name: str):
        clean = sanitize_virtual_username(name)
        username_var.set(clean)
        cfg["virtual_username"] = clean
        save_config(cfg)
        try:
            write_virtual_profile(Path(folder_var.get().strip()), clean)
        except Exception:
            pass
        return clean

    def edit_profile():
        value = simpledialog.askstring(
            "KW Virtual Profile",
            "Choose a local virtual username (3-24 letters, numbers, _ or -).\nNo real account is created.",
            initialvalue=username_var.get(),
            parent=root,
        )
        if value is not None:
            persist_profile(value)

    def reroll_profile():
        persist_profile(generate_virtual_username())

    flat_button(profile_actions, "EDIT ID", edit_profile, compact=True, bg=C["purple"]).pack(side="left")
    flat_button(profile_actions, "REROLL", reroll_profile, compact=True, bg=C["panel2"]).pack(side="left", padx=(6, 0))

    def choose_folder():
        chosen = filedialog.askdirectory(initialdir=folder_var.get() or str(Path.home()))
        if chosen:
            folder_var.set(chosen)
            cfg["game_dir"] = chosen
            save_config(cfg)
            write_virtual_profile(Path(chosen), username_var.get())
            check_async()

    flat_button(folder_row, "CHANGE", choose_folder, compact=True, bg=C["purple"]).pack(side="left", padx=(8, 0))

    def set_busy(value: bool):
        state["busy"] = value
        action_btn.config(state="disabled" if value else "normal")
        exe_exists = (Path(folder_var.get()) / "kw.exe").exists()
        allow_play = (not value) and bool(state["checked"]) and bool(state["up_to_date"]) and exe_exists
        play_btn.config(state="normal" if allow_play else "disabled")

    def apply_check(manifest: dict, plan: list[dict], updates=None):
        state["manifest"] = manifest
        state["plan"] = plan
        if updates is not None:
            state["updates"] = updates
            if updates:
                render_updates(updates)
        game_dir = Path(folder_var.get())
        local = read_local_version(game_dir)
        remote = str(manifest["version"])
        changed = [x["filename"] for x in plan if x["changed"]]
        state["checked"] = True
        state["up_to_date"] = not changed
        versions.set(f"LOCAL {local}     SERVER {remote}")
        latest_var.set("LATEST  " + remote)
        sidebar_version.config(text="VERSION " + remote)
        server_var.set("NETWORK  //  ONLINE")
        sidebar_server.config(text="SERVER ONLINE", fg=C["mint"])
        if changed:
            status.set("UPDATE READY")
            detail.set("New KW files are available. PLAY stays locked until the verified update is complete.")
            action_btn.config(text="UPDATE", bg=C["pink"], fg=C["cream"])
        else:
            status.set("READY TO PLAY")
            detail.set("Client files match the live server. Your virtual profile is ready.")
            action_btn.config(text="CHECK", bg=C["cyan"], fg=C["ink"])
        progress["value"] = 100 if not changed else 0
        set_busy(False)

    def check_worker():
        try:
            cfg["manifest_url"] = url_var.get().strip()
            cfg["game_dir"] = folder_var.get().strip()
            cfg["virtual_username"] = sanitize_virtual_username(username_var.get())
            save_config(cfg)
            game_dir = Path(cfg["game_dir"])
            game_dir.mkdir(parents=True, exist_ok=True)
            write_virtual_profile(game_dir, cfg["virtual_username"])
            manifest = fetch_json(cfg["manifest_url"])
            plan = update_plan(game_dir, manifest)
            updates = fetch_updates(cfg["manifest_url"])
            root.after(0, lambda: apply_check(manifest, plan, updates))
        except Exception as exc:
            state["checked"] = False
            state["up_to_date"] = False
            root.after(0, lambda: (
                status.set("UPDATE SERVICE OFFLINE"),
                detail.set(str(exc) + "  PLAY remains locked."),
                server_var.set("NETWORK  //  UNAVAILABLE"),
                sidebar_server.config(text="SERVER UNAVAILABLE", fg=C["pink"]),
                set_busy(False),
            ))

    def check_async():
        if state["busy"]:
            return
        set_busy(True)
        status.set("CHECKING LIVE BUILD...")
        progress["value"] = 0
        threading.Thread(target=check_worker, daemon=True).start()

    def update_worker():
        try:
            manifest = state["manifest"] or fetch_json(url_var.get().strip())
            game_dir = Path(folder_var.get().strip())
            game_dir.mkdir(parents=True, exist_ok=True)
            write_virtual_profile(game_dir, username_var.get())
            plan = update_plan(game_dir, manifest)
            changed = [x for x in plan if x["changed"]]
            if not changed:
                root.after(0, lambda: apply_check(manifest, plan, state.get("updates")))
                return
            total_files = len(changed)
            for index, item in enumerate(changed):
                def file_progress(done, total, idx=index, name=item["filename"]):
                    frac = (done / total) if total else 0
                    overall = ((idx + frac) / total_files) * 100
                    root.after(0, lambda v=overall, n=name: (progress.configure(value=v), status.set("DOWNLOADING  " + n.upper())))
                download_file(item["url"], game_dir / item["filename"], item["expected"], file_progress)
            (game_dir / "game_version.txt").write_text(str(manifest["version"]), encoding="utf-8")
            write_virtual_profile(game_dir, username_var.get())
            plan2 = update_plan(game_dir, manifest)
            root.after(0, lambda: apply_check(manifest, plan2, state.get("updates")))
        except PermissionError:
            root.after(0, lambda: (status.set("CLOSE KW FIRST"), detail.set("Windows locked a game file. Close KW, then press UPDATE again."), set_busy(False)))
        except Exception as exc:
            root.after(0, lambda: (status.set("UPDATE FAILED"), detail.set(str(exc)), set_busy(False)))

    def action():
        if state["plan"] and any(x["changed"] for x in state["plan"]):
            set_busy(True)
            status.set("PREPARING VERIFIED UPDATE...")
            threading.Thread(target=update_worker, daemon=True).start()
        else:
            check_async()

    def play():
        game_dir = Path(folder_var.get().strip())
        exe = game_dir / "kw.exe"
        if not state["checked"] or not state["up_to_date"]:
            messagebox.showinfo("KW", "UPDATE is required before PLAY.")
            return
        if not exe.exists():
            state["up_to_date"] = False
            set_busy(False)
            messagebox.showinfo("KW", "Game files are missing. Press UPDATE first.")
            return
        try:
            manifest = fetch_json(url_var.get().strip())
            plan = update_plan(game_dir, manifest)
        except Exception as exc:
            state["checked"] = False
            state["up_to_date"] = False
            set_busy(False)
            messagebox.showerror("KW", "Could not verify the latest version. PLAY remains locked.\n\n" + str(exc))
            return
        if any(x["changed"] for x in plan):
            apply_check(manifest, plan, state.get("updates"))
            messagebox.showinfo("KW", "A newer KW version is available. UPDATE must finish before PLAY.")
            return
        username = persist_profile(username_var.get())
        write_virtual_profile(game_dir, username)
        try:
            subprocess.Popen([str(exe), "--", f"--kw-name={username}"], cwd=str(game_dir))
            root.destroy()
        except Exception as exc:
            messagebox.showerror("KW", str(exc))

    action_btn.config(command=action)
    play_btn.config(command=play)
    root.after(150, check_async)
    root.mainloop()
    return 0
if __name__ == "__main__":
    qa = qa_mode(sys.argv[1:])
    raise SystemExit(qa if qa >= 0 else run_gui())
