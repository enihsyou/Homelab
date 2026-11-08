import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


config = Path("config.yaml").read_text(encoding="utf-8")
config = re.sub(
    r"\$\{([A-Z_][A-Z_0-9]*)\}",
    lambda match: json.dumps(os.environ[match.group(1)], ensure_ascii=False),
    config,
)
with tempfile.TemporaryDirectory() as directory:
    rendered = Path(directory) / "config.yaml"
    rendered.write_text(config, encoding="utf-8")
    subprocess.run(
        ["docker", "cp", str(rendered), "cli-proxy-api:/config/config.yaml"],
        check=True,
    )
