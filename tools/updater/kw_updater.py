from __future__ import annotations
import hashlib, json, os, subprocess, sys, threading, urllib.request
from pathlib import Path

DEFAULT_MANIFEST_URL = "https://portal-fresh-pleasant-peoples.trycloudflare.com/kw/update_manifest.json"
APP_VERSION = "1.1.0"
FILES = (
    ("kw.exe", "exe_url", "exe_sha256"),
    ("kw.pck", "pck_url", "pck_sha256"),
)

def app_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent

def config_path() -> Path:
    return app_dir() / "updater_config.json"

def load_config() -> dict:
    cfg = {"manifest_url": DEFAULT_MANIFEST_URL, "game_dir": str(Path.home() / "Games" / "KW")}
    try:
        data = json.loads(config_path().read_text(encoding="utf-8-sig"))
        if isinstance(data, dict):
            cfg.update({k: v for k, v in data.items() if isinstance(v, (str, int, float, bool))})
            stored_url = str(cfg.get("manifest_url", ""))
            if "192.168.1.154:8081" in stored_url or "192.168.1.154:8082" in stored_url:
                cfg["manifest_url"] = DEFAULT_MANIFEST_URL
    except Exception:
        pass
    local = app_dir()
    if (local / "kw.exe").exists() or (local / "kw.pck").exists():
        cfg["game_dir"] = str(local)
    return cfg

def save_config(cfg: dict) -> None:
    config_path().write_text(json.dumps(cfg, indent=2), encoding="utf-8")

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
        report.update({
            "ok": True,
            "remote_version": manifest["version"],
            "local_version": read_local_version(game_dir),
            "plan": [{k: x[k] for k in ("filename", "changed", "missing")} for x in plan],
        })
    except Exception as exc:
        report["error"] = str(exc)
    Path(out).write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0 if report["ok"] else 2

def run_gui() -> int:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk

    cfg = load_config()
    state = {"manifest": None, "plan": None, "busy": False}

    root = tk.Tk()
    root.title("KW Updater")
    root.geometry("620x430")
    root.minsize(560, 400)
    root.configure(bg="#0f0d14")

    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except Exception:
        pass
    style.configure("KW.Horizontal.TProgressbar", troughcolor="#202943", background="#85c799", bordercolor="#e9f7bd", lightcolor="#85c799", darkcolor="#85c799")

    panel = tk.Frame(root, bg="#24304b", highlightbackground="#e9f7bd", highlightthickness=3)
    panel.pack(fill="both", expand=True, padx=18, pady=18)

    tk.Label(panel, text="KW // UPDATER", font=("Segoe UI", 24, "bold"), fg="#faf7f1", bg="#24304b").pack(pady=(18, 2))
    tk.Label(panel, text="PORTABLE  â€¢  HASH VERIFIED  â€¢  NO .NET RUNTIME", font=("Segoe UI", 9, "bold"), fg="#85c799", bg="#24304b").pack()

    status = tk.StringVar(value="Checking current version...")
    versions = tk.StringVar(value="")
    folder_var = tk.StringVar(value=str(cfg["game_dir"]))
    url_var = tk.StringVar(value=str(cfg["manifest_url"]))

    tk.Label(panel, textvariable=status, font=("Segoe UI", 11, "bold"), fg="#faf7f1", bg="#24304b", wraplength=540).pack(pady=(16, 4))
    tk.Label(panel, textvariable=versions, font=("Consolas", 9), fg="#e27393", bg="#24304b").pack(pady=(0, 8))

    folder_row = tk.Frame(panel, bg="#24304b")
    folder_row.pack(fill="x", padx=22, pady=4)
    folder_entry = tk.Entry(folder_row, textvariable=folder_var, font=("Consolas", 9), bg="#111827", fg="#faf7f1", insertbackground="#faf7f1", relief="flat")
    folder_entry.pack(side="left", fill="x", expand=True, ipady=8)
    def choose_folder():
        chosen = filedialog.askdirectory(initialdir=folder_var.get() or str(Path.home()))
        if chosen:
            folder_var.set(chosen)
            cfg["game_dir"] = chosen
            save_config(cfg)
            check_async()
    tk.Button(folder_row, text="GAME FOLDER", command=choose_folder, bg="#4e8d9c", fg="#faf7f1", activebackground="#85c799", relief="flat", padx=10, pady=7).pack(side="left", padx=(8,0))

    url_row = tk.Frame(panel, bg="#24304b")
    url_row.pack(fill="x", padx=22, pady=4)
    url_entry = tk.Entry(url_row, textvariable=url_var, font=("Consolas", 9), bg="#111827", fg="#faf7f1", insertbackground="#faf7f1", relief="flat")
    url_entry.pack(side="left", fill="x", expand=True, ipady=8)

    progress = ttk.Progressbar(panel, style="KW.Horizontal.TProgressbar", mode="determinate", maximum=100)
    progress.pack(fill="x", padx=22, pady=(12, 6))

    buttons = tk.Frame(panel, bg="#24304b")
    buttons.pack(fill="x", padx=22, pady=(8, 6))
    action_btn = tk.Button(buttons, text="CHECK", bg="#4e8d9c", fg="#faf7f1", activebackground="#85c799", relief="flat", font=("Segoe UI", 11, "bold"), pady=10)
    action_btn.pack(side="left", fill="x", expand=True)
    play_btn = tk.Button(buttons, text="PLAY", bg="#47429d", fg="#faf7f1", activebackground="#e27393", relief="flat", font=("Segoe UI", 11, "bold"), pady=10, state="disabled")
    play_btn.pack(side="left", fill="x", expand=True, padx=(8,0))

    detail = tk.StringVar(value="The updater downloads only files whose SHA-256 changed.")
    tk.Label(panel, textvariable=detail, font=("Segoe UI", 9), fg="#aab6ca", bg="#24304b", wraplength=540).pack(padx=22, pady=(6, 12))

    def set_busy(value: bool):
        state["busy"] = value
        action_btn.config(state="disabled" if value else "normal")
        play_btn.config(state="disabled" if value or not (Path(folder_var.get()) / "kw.exe").exists() else "normal")

    def apply_check(manifest: dict, plan: list[dict]):
        state["manifest"] = manifest
        state["plan"] = plan
        game_dir = Path(folder_var.get())
        local = read_local_version(game_dir)
        remote = str(manifest["version"])
        changed = [x["filename"] for x in plan if x["changed"]]
        versions.set(f"LOCAL {local}     SERVER {remote}")
        if changed:
            status.set("UPDATE AVAILABLE")
            detail.set("Changed: " + ", ".join(changed) + ". Only these files will be downloaded.")
            action_btn.config(text="UPDATE")
        else:
            status.set("YOU ARE UP TO DATE")
            detail.set("All game hashes match the server. Nothing will be downloaded.")
            action_btn.config(text="CHECK")
        progress["value"] = 100 if not changed else 0
        set_busy(False)

    def check_worker():
        try:
            cfg["manifest_url"] = url_var.get().strip()
            cfg["game_dir"] = folder_var.get().strip()
            save_config(cfg)
            manifest = fetch_json(cfg["manifest_url"])
            game_dir = Path(cfg["game_dir"])
            game_dir.mkdir(parents=True, exist_ok=True)
            plan = update_plan(game_dir, manifest)
            root.after(0, lambda: apply_check(manifest, plan))
        except Exception as exc:
            root.after(0, lambda: (status.set("CHECK FAILED"), detail.set(str(exc)), set_busy(False)))

    def check_async():
        if state["busy"]:
            return
        set_busy(True)
        status.set("CHECKING SERVER...")
        progress["value"] = 0
        threading.Thread(target=check_worker, daemon=True).start()

    def update_worker():
        try:
            manifest = state["manifest"] or fetch_json(url_var.get().strip())
            game_dir = Path(folder_var.get().strip())
            game_dir.mkdir(parents=True, exist_ok=True)
            plan = update_plan(game_dir, manifest)
            changed = [x for x in plan if x["changed"]]
            if not changed:
                root.after(0, lambda: apply_check(manifest, plan))
                return
            total_files = len(changed)
            for index, item in enumerate(changed):
                def file_progress(done, total, idx=index, name=item["filename"]):
                    frac = (done / total) if total else 0
                    overall = ((idx + frac) / total_files) * 100
                    root.after(0, lambda v=overall, n=name: (progress.configure(value=v), status.set("DOWNLOADING " + n.upper())))
                download_file(item["url"], game_dir / item["filename"], item["expected"], file_progress)
            (game_dir / "game_version.txt").write_text(str(manifest["version"]), encoding="utf-8")
            plan2 = update_plan(game_dir, manifest)
            root.after(0, lambda: apply_check(manifest, plan2))
        except PermissionError:
            root.after(0, lambda: (status.set("CLOSE KW FIRST"), detail.set("The game is running and Windows locked a file. Close KW, then press UPDATE again."), set_busy(False)))
        except Exception as exc:
            root.after(0, lambda: (status.set("UPDATE FAILED"), detail.set(str(exc)), set_busy(False)))

    def action():
        if state["plan"] and any(x["changed"] for x in state["plan"]):
            set_busy(True)
            status.set("PREPARING UPDATE...")
            threading.Thread(target=update_worker, daemon=True).start()
        else:
            check_async()

    def play():
        game_dir = Path(folder_var.get().strip())
        exe = game_dir / "kw.exe"
        if not exe.exists():
            messagebox.showinfo("KW", "Game files are missing. Press UPDATE first.")
            return
        try:
            subprocess.Popen([str(exe)], cwd=str(game_dir))
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
