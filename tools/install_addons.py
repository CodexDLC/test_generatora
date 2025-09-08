import json, subprocess, sys, os, shutil

ROOT = os.path.dirname(os.path.dirname(__file__))
ADDONS = os.path.join(ROOT, "addons")
LOCK = os.path.join(ROOT, "addons.lock.json")

def run(cmd, cwd=None):
    print("$", " ".join(cmd))
    subprocess.check_call(cmd, cwd=cwd)

def ensure_dir(p):
    os.makedirs(p, exist_ok=True)

def main():
    if not os.path.exists(LOCK):
        print("Нет addons.lock.json — нечего ставить")
        sys.exit(1)
    ensure_dir(ADDONS)
    with open(LOCK, "r", encoding="utf-8") as f:
        deps = json.load(f)

    for d in deps:
        name, repo, rev = d["name"], d["repo"], d["rev"]
        dest = os.path.join(ADDONS, name)
        if os.path.isdir(dest):
            # обновим до нужной ревизии
            run(["git", "fetch", "--all"], cwd=dest)
            run(["git", "checkout", rev], cwd=dest)
            run(["git", "pull", "--ff-only"], cwd=dest)
        else:
            run(["git", "clone", repo, dest])
            run(["git", "checkout", rev], cwd=dest)
        # На всякий случай удалим .git внутри аддона (чтобы не мешал)
        gitdir = os.path.join(dest, ".git")
        if os.path.isdir(gitdir):
            shutil.rmtree(gitdir)
    print("Готово: плагины установлены в addons/")

if __name__ == "__main__":
    main()
