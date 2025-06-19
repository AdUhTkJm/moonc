import subprocess
import sys
from pathlib import Path

def check_file(file_path):
  print(f"checking {file_path}")
  result = subprocess.run(
    ["moon", "run", "src/test", str(file_path)],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
  )
  if "error:" in result.stdout or result.returncode != 0:
    print(f"\033[0;31merror:\033[0m {file_path} failed to parse")
    return False

  return True

def main():
  test_dirs = [Path("test"), Path("corelib")]
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
