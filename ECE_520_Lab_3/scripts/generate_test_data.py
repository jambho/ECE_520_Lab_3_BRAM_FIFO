import random
import sys
import pathlib

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    random.seed(42)
    script_dir = pathlib.Path(__file__).resolve().parent
    out_path = script_dir.parent / "sim" / "input_data.txt"
    with open(out_path, "w") as f:
        for v in [0xFFFF] * 32 + [0x0000] * 32 + [0xAAAA, 0x5555] * 16 + [i ^ 0xAAAA for i in range(32)] + [1 << i for i in range(16)]:  # added
            f.write(f"{v:04x}\n")  # added
        for _ in range(n):
            a = random.randint(0, 0xFFFF)  # changed: 0xFF -> 0xFFFF
            f.write(f"{a:04x}\n")          # changed: one 16-bit word, no b
    print(f"Wrote {n} random words plus 144 pattern words to {out_path}")  # changed

if __name__ == "__main__":
    main()