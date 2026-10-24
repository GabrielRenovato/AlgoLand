"""Dois clientes reais conversam entre cidade, fenda e floresta em servidor local."""
import sys
from teste_lobby_cidade import main

if __name__ == '__main__':
    sys.argv.append('--global')
    main()
