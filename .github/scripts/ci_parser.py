import subprocess
import sys
from pathlib import Path

home = Path.home()

def check_file(file_path: Path):
  print(f"checking {file_path}")
  result = subprocess.run(
    [f"{home}/.moon/bin/moon", "run", "src/test", str(file_path.resolve())],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
  )
  if "error:" in result.stdout or result.returncode != 0:
    print(f"\033[0;31merror:\033[0m {file_path} failed to parse")
    print(f"return code: {result.returncode}")
    for line in result.stdout.splitlines():
      if "error:" in line:
        print("first error line:", line)
        break
    print("stderr:\n", result.stderr)
    return False

  return True

def main():
  test_dirs = [Path("test")]
  passed = True
  for directory in test_dirs:
    for file in directory.glob("*.mbt"):
      if not check_file(file):
        passed = False
  
  if not passed:
    sys.exit(1)
  print("Passed.")

if __name__ == "__main__":
  main()
