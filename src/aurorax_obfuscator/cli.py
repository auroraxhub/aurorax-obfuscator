import argparse
from .obfuscator import obfuscate_file

def main():
    p = argparse.ArgumentParser(prog="aurorax-obfuscator", description="Aurora X Lua obfuscator (MVP)")
    p.add_argument("input", help="Input Lua file")
    p.add_argument("-o", "--output", help="Output obfuscated Lua file", required=True)
    p.add_argument("-k", "--key", help="XOR key (optional). If not provided a random key is used.", default=None)
    args = p.parse_args()
    obfuscate_file(args.input, args.output, key=args.key)

if __name__ == "__main__":
    main()
