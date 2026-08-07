import sys
import tiktoken

def main():
    if len(sys.argv) != 2:
        print("Usage: encode_prompt.py <prompt_file>", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    try:
        with open(path, 'rb') as f:
            data = f.read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f"ERROR: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)
    enc = tiktoken.get_encoding("gpt2")
    ids = enc.encode(data)
    print(" ".join(str(i) for i in ids))

if __name__ == '__main__':
    main()
